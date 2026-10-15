# 22_tab_s14_s15_political_lean.py
# author: Rebecca Ansell
#
# Table S14 — Political lean distribution of human-authored posts by platform
#             (Left / Center / Right row proportions; politicalBiasBERT).
# Table S15 — OLS regression of PHI score (Normalized Ability) on political
#             lean with Left as the reference group, pooled and per platform.
#
# Pipeline
# --------
# 1. Load labels_tweeteval.csv and filter to human-authored posts.
# 2. Run bucketresearch/politicalBiasBERT to assign Left/Center/Right labels.
#    (Skipped automatically if data/political_bias.csv already exists —
#    rerun with --force to override. Inference needs transformers + torch.)
# 3. Write Table S14 to output/tab_s14.tex.
# 4. Fit OLS: Normalized Ability ~ C(political_label, ref = Left), pooled and
#    per platform, and write Table S15 to output/tab_s15.tex.
#
# Data input:   data/tweeteval_eval/labels_tweeteval.csv
# Data output:  data/political_bias.csv   — labelled human posts (cached)
#               output/tab_s14.tex, output/tab_s15.tex
#
# Run from this folder:  python 22_tab_s14_s15_political_lean.py [--force]

import argparse
import os
import warnings
warnings.filterwarnings('ignore')

import pandas as pd
import statsmodels.formula.api as smf

# ── Paths ─────────────────────────────────────────────────────────────────────
PKG_ROOT   = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
LABELS_CSV = os.path.join(PKG_ROOT, 'data', 'tweeteval_eval', 'labels_tweeteval.csv')
BIAS_CSV   = os.path.join(PKG_ROOT, 'data', 'political_bias.csv')
OUT_DIR    = os.path.join(PKG_ROOT, 'output')

MODEL_ID  = 'bucketresearch/politicalBiasBERT'
BATCH     = 64
PLATFORMS = ['TikTok', 'Truth Social', 'Twitter/X', 'YouTube']
LABELS    = ['Left', 'Center', 'Right']


# ── Text preprocessing ────────────────────────────────────────────────────────
def sanitize(text):
    if not isinstance(text, str):
        return ''
    return ''.join(c for c in text if c >= ' ' or c in '\n\t')[:512]


# ── politicalBiasBERT inference ───────────────────────────────────────────────
def run_inference(texts):
    import torch
    from transformers import pipeline
    device = 0 if torch.cuda.is_available() else -1
    print(f"  Loading {MODEL_ID} on device={device} …")
    clf = pipeline('text-classification', model=MODEL_ID,
                   device=device, top_k=None)
    results = []
    for i in range(0, len(texts), BATCH):
        batch = texts[i: i + BATCH]
        out = clf(batch, truncation=True, max_length=512)
        results.extend(out)
        print(f"  Scored {min(i + BATCH, len(texts))}/{len(texts)}", end='\r')
    print()
    return results


def parse_results(raw):
    return pd.DataFrame(
        [{r['label'].capitalize(): r['score'] for r in res} for res in raw]
    )


# ── Step 1 — classify political lean ──────────────────────────────────────────
def classify_political_lean(force=False):
    if os.path.exists(BIAS_CSV) and not force:
        print(f"Cached labels found at {BIAS_CSV} — skipping inference.")
        print("(Pass --force to re-run politicalBiasBERT.)")
        return pd.read_csv(BIAS_CSV)

    df = pd.read_csv(LABELS_CSV)
    df = df[df['model'].str.lower() == 'human'].copy()
    df['Text'] = df['Text'].apply(sanitize)
    df = df[df['Text'].str.len() > 0].reset_index(drop=True)
    print(f"Human posts to classify: {len(df)}")

    raw  = run_inference(df['Text'].tolist())
    probs = parse_results(raw)
    for lab in LABELS:
        if lab in probs.columns:
            df[f'prob_{lab}'] = probs[lab].values
    df['political_label'] = probs[LABELS].idxmax(axis=1).values

    df.to_csv(BIAS_CSV, index=False)
    print(f"Saved {BIAS_CSV}")
    return df


# ── Table S14 ─────────────────────────────────────────────────────────────────
def write_table_s14(df):
    cols = ['Center', 'Left', 'Right']
    prop = (
        df.groupby('platform')['political_label']
        .value_counts(normalize=True)
        .unstack(fill_value=0)
        .reindex(index=PLATFORMS, columns=cols, fill_value=0)
        .mul(100)
    )
    counts = df.groupby('platform').size().reindex(PLATFORMS, fill_value=0)
    total = df['political_label'].value_counts(normalize=True).reindex(cols, fill_value=0).mul(100)

    lines = [
        '\\begin{table}[h]',
        '\\centering',
        '\\caption{Political lean of human-authored posts by platform, classified by',
        '\\texttt{politicalBiasBERT}. Values are row proportions (\\%).}',
        '\\begin{tabular}{lcccc}',
        '\\toprule',
        '\\textbf{Platform} & \\textbf{Center} & \\textbf{Left} & \\textbf{Right} & \\textbf{Total} \\\\',
        '\\midrule',
    ]
    for platform in PLATFORMS:
        name = 'X/Twitter' if platform == 'Twitter/X' else platform
        lines.append(f'{name} & ' + ' & '.join(f'{prop.loc[platform, c]:.1f}' for c in cols)
                     + f' & {counts[platform]} \\\\')
    lines += [
        '\\midrule',
        '\\textbf{Total} & ' + ' & '.join(f'{total[c]:.1f}' for c in cols) + f' & {len(df)} \\\\',
        '\\bottomrule',
        '\\end{tabular}',
        '\\end{table}',
    ]
    out = os.path.join(OUT_DIR, 'tab_s14.tex')
    with open(out, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f"Saved {out}")
    print(prop.round(1).to_string())


# ── Table S15 ─────────────────────────────────────────────────────────────────
def stars(p):
    return '***' if p < 0.001 else '**' if p < 0.01 else '*' if p < 0.05 else ''


def fmt(x):
    return f'$-${abs(x):.3f}' if x < 0 else f'{x:.3f}'


def fit_lean_model(sub):
    sub = sub.copy()
    sub['political_label'] = pd.Categorical(sub['political_label'], categories=LABELS)
    return smf.ols('Q("Normalized Ability") ~ C(political_label)', data=sub).fit()


def write_table_s15(df):
    sub = df[['Normalized Ability', 'political_label', 'platform']].dropna()
    models = {'Pooled': fit_lean_model(sub)}
    for platform in ['Twitter/X', 'YouTube', 'TikTok', 'Truth Social']:
        models[platform] = fit_lean_model(sub[sub['platform'] == platform])

    terms = [('Left (Intercept)', 'Intercept'),
             ('Center', 'C(political_label)[T.Center]'),
             ('Right', 'C(political_label)[T.Right]')]
    header = ['Pooled', 'X/Twitter', 'YouTube', 'TikTok', 'Truth Social']
    keys   = ['Pooled', 'Twitter/X', 'YouTube', 'TikTok', 'Truth Social']

    lines = [
        '\\begin{table}[h]',
        '\\centering',
        '\\caption{OLS Regression: Humanness Score by Political Lean (ref.\\ = Left)}',
        '\\begin{tabular}[t]{lccccc}',
        '\\toprule',
        '  & ' + ' & '.join(header) + ' \\\\',
        '\\midrule',
    ]
    for label, term in terms:
        lines.append(label)
        lines.append('  & ' + ' & '.join(fmt(models[k].params[term]) + stars(models[k].pvalues[term]) for k in keys) + ' \\\\')
        lines.append('  & ' + ' & '.join(f'({models[k].bse[term]:.3f})' for k in keys) + ' \\\\')
    lines += [
        '\\midrule',
        'Num.\\ Obs.  & ' + ' & '.join(str(int(models[k].nobs)) for k in keys) + ' \\\\',
        '\\bottomrule',
        '\\multicolumn{6}{l}{\\rule{0pt}{1em}* $p < 0.05$, ** $p < 0.01$, *** $p < 0.001$}\\\\',
        '\\multicolumn{6}{l}{\\rule{0pt}{1em}Each column reports OLS estimates from a regression of humanness scores on political lean,}\\\\',
        '\\multicolumn{6}{l}{\\rule{0pt}{1em}with Left as the reference group. The Left row reports the intercept (mean of Left posts);}\\\\',
        '\\multicolumn{6}{l}{\\rule{0pt}{1em}Center and Right rows report contrasts relative to Left. Column 1 pools all platforms;}\\\\',
        '\\multicolumn{6}{l}{\\rule{0pt}{1em}columns 2--5 estimate the same model separately for each platform. Standard errors in parentheses.}\\\\',
        '\\end{tabular}',
        '\\end{table}',
    ]
    out = os.path.join(OUT_DIR, 'tab_s15.tex')
    with open(out, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f"Saved {out}")
    print(models['Pooled'].summary().tables[1])


# ── Entry point ───────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--force', action='store_true',
                        help='Re-run politicalBiasBERT even if data/political_bias.csv exists')
    args = parser.parse_args()

    df = classify_political_lean(force=args.force)
    write_table_s14(df)
    write_table_s15(df)
    print("\nDone.")


if __name__ == '__main__':
    main()
