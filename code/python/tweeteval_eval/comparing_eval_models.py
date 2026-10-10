# comparing_eval_models.py
#
# Runs sentiment, emotion, hate, irony, and offensive classification across three
# model families (TweetEval, TweetNLP, BERTweet) on posts from Truth Social,
# TikTok, Twitter/X, and YouTube. TweetEval labels are read from pre-computed
# CSVs; TweetNLP and BERTweet are run fresh. For each model, saves a labelled
# CSV (binary 0/1 labels + continuous probability scores) and runs OLS regressions
# on both, producing two comparison forest plots with 95% CIs.

import os
os.environ['CUDA_VISIBLE_DEVICES'] = '0'

import warnings
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from scipy import stats
from sklearn.linear_model import LinearRegression
import torch

os.environ['CUDA_LAUNCH_BLOCKING'] = "1"
warnings.filterwarnings('ignore')
torch.backends.cuda.enable_flash_sdp(False)
torch.backends.cuda.enable_mem_efficient_sdp(False)
torch.backends.cuda.enable_math_sdp(True)

# ── Configuration ──────────────────────────────────────────────────────────────

DATA_DIR = os.path.dirname(os.path.abspath(__file__))

PLATFORM_FILES = {
    'Truth Social': 'post_traits_ts.csv',
    'TikTok':       'post_traits_tt.csv',
    'Twitter/X':    'post_traits_x.csv',
    'YouTube':      'post_traits_yt.csv',
}

BERTWEET_MODELS = {
    'sentiment': 'finiteautomata/bertweet-base-sentiment-analysis',  # NEG/NEU/POS
    'emotion':   'cardiffnlp/bertweet-base-emotion',                  # LABEL_0=joy, LABEL_1=optimism, LABEL_2=anger, LABEL_3=sadness
    'hate':      'cardiffnlp/bertweet-base-hate',                     # LABEL_0=non-hate, LABEL_1=hate
    'irony':     'cardiffnlp/bertweet-base-irony',                    # LABEL_0=non-irony, LABEL_1=irony
    'offensive': 'cardiffnlp/bertweet-base-offensive',                # LABEL_0=non-offensive, LABEL_1=offensive
}

BATCH_SIZE = 32
DEVICE     = 0 if torch.cuda.is_available() else -1
MAX_CHARS  = 512

FEATURE_GROUPS = [
    ('Sentiment', ['Sentiment - Negative', 'Sentiment - Positive']),
    ('Emotion',   ['Joy', 'Optimism', 'Anger', 'Sadness']),
    ('Hate',      ['Hateful Speech']),
    ('Irony',     ['Irony']),
    ('Offensive', ['Offensive']),
]

MODEL_COLORS = {
    'TweetEval': '#1f77b4',
    'TweetNLP':  '#2ca02c',
    'BERTweet':  '#ff7f0e',
}

# ── Helpers ────────────────────────────────────────────────────────────────────

def _sanitize(text):
    if not isinstance(text, str):
        text = str(text) if text is not None else ''
    text = ''.join(ch for ch in text if ch.isprintable()).replace('\x00', '').strip()
    return text[:MAX_CHARS] or '[empty]'

def load_combined_data():
    dfs = []
    for platform, fname in PLATFORM_FILES.items():
        path = os.path.join(DATA_DIR, fname)
        if os.path.exists(path):
            df = pd.read_csv(path)
            df['platform'] = platform
            dfs.append(df)
            print(f"  {fname}: {len(df)} rows")
    if not dfs:
        raise FileNotFoundError("No platform CSV files found.")
    return pd.concat(dfs, ignore_index=True)

# ── TweetEval — pre-computed labels + probability scores from source CSVs ──────

def extract_tweeteval_features(df):
    feats = {}
    if 'sentiment_label' in df.columns:
        feats['Sentiment - Negative'] = (df['sentiment_label'] == 'LABEL_0').astype(int).values
        feats['Sentiment - Positive'] = (df['sentiment_label'] == 'LABEL_2').astype(int).values
        feats['prob_Sentiment - Negative'] = df['sentiment_p_label_0'].values
        feats['prob_Sentiment - Positive'] = df['sentiment_p_label_2'].values

    if 'emotion_label' in df.columns:
        for e in ['joy', 'optimism', 'anger', 'sadness']:
            feats[e.title()] = df['emotion_label'].str.lower().eq(e).astype(int).values
            feats[f'prob_{e.title()}'] = df[f'emotion_p_{e}'].values

    prob_map = {
        'hate_label':      ('Hateful Speech', ['hate'],      'hate_p_hateful'),
        'irony_label':     ('Irony',          ['irony'],     'irony_p_irony'),
        'offensive_label': ('Offensive',      ['offensive'], 'offensive_p_offensive'),
    }
    for col, (name, pos_vals, prob_col) in prob_map.items():
        if col in df.columns:
            feats[name] = df[col].astype(str).str.lower().isin(pos_vals).astype(int).values
            feats[f'prob_{name}'] = df[prob_col].values
    return feats

# ── TweetNLP — fresh inference with probabilities ─────────────────────────────

def extract_tweetnlp_features(df):
    import tweetnlp
    texts = [_sanitize(t) for t in df['Text'].fillna('').tolist()]
    total = len(texts)
    feats = {}

    for task in ['sentiment', 'emotion', 'hate', 'irony', 'offensive']:
        print(f"    TweetNLP — {task} (0/{total})", flush=True)
        try:
            kwargs = {'multi_label': False} if task == 'emotion' else {}
            model = tweetnlp.load_model(task, **kwargs)
            results = []
            for i in range(0, total, BATCH_SIZE):
                batch = texts[i:i + BATCH_SIZE]
                results.extend(model.predict(batch, batch_size=len(batch), return_probability=True))
                done = min(i + BATCH_SIZE, total)
                print(f"\r    TweetNLP — {task} ({done}/{total})", end='', flush=True)
            print()

            if task == 'sentiment':
                labels = [r['label'].lower() for r in results]
                feats['Sentiment - Negative'] = np.array([1 if 'neg' in l else 0 for l in labels])
                feats['Sentiment - Positive'] = np.array([1 if 'pos' in l else 0 for l in labels])
                feats['prob_Sentiment - Negative'] = np.array([r['probability'].get('negative', 0) for r in results])
                feats['prob_Sentiment - Positive'] = np.array([r['probability'].get('positive', 0) for r in results])

            elif task == 'emotion':
                labels = [r['label'].lower() if isinstance(r['label'], str) else r['label'][0].lower() for r in results]
                for e in ['joy', 'optimism', 'anger', 'sadness']:
                    feats[e.title()] = np.array([1 if l == e else 0 for l in labels])
                    feats[f'prob_{e.title()}'] = np.array([r['probability'].get(e, 0) for r in results])

            elif task == 'hate':
                feats['Hateful Speech'] = np.array([1 if r['label'].upper() == 'HATE' else 0 for r in results])
                feats['prob_Hateful Speech'] = np.array([r['probability'].get('HATE', r['probability'].get('hate', 0)) for r in results])

            else:
                name = task.title()
                feats[name] = np.array([
                    1 if task in r['label'].lower() and 'non' not in r['label'].lower() else 0
                    for r in results
                ])
                feats[f'prob_{name}'] = np.array([r['probability'].get(task, 0) for r in results])

            del model
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
        except Exception as e:
            print(f"      TweetNLP Error: {e}")
    return feats

# ── BERTweet — pipeline with all class probabilities ─────────────────────────

def _run_bt_pipe(texts, task, model_id):
    from transformers import pipeline, AutoTokenizer
    total = len(texts)
    print(f"    BERTweet — {task} (0/{total})", flush=True)
    try:
        tok = AutoTokenizer.from_pretrained(model_id, normalization=True)
        pipe = pipeline('text-classification', model=model_id, tokenizer=tok,
                        device=DEVICE, max_length=128, truncation=True, top_k=None)
        out = []
        for i in range(0, total, BATCH_SIZE):
            batch = texts[i:i + BATCH_SIZE]
            out.extend(pipe(batch, batch_size=len(batch)))
            done = min(i + BATCH_SIZE, total)
            print(f"\r    BERTweet — {task} ({done}/{total})", end='', flush=True)
        print()
        # out is a list of lists: [[{'label': 'LABEL_0', 'score': 0.9}, ...], ...]
        labels = [max(row, key=lambda x: x['score'])['label'].lower() for row in out]
        probs  = [{item['label'].lower(): item['score'] for item in row} for row in out]
        return labels, probs
    except Exception as e:
        print(f"\n      BERTweet Error: {e}")
        return ['none'] * total, [{}] * total

def extract_bertweet_features(df):
    texts = [_sanitize(t) for t in df['Text'].fillna('').tolist()]
    feats = {}

    # Sentiment: NEG/NEU/POS
    labels, probs = _run_bt_pipe(texts, 'sentiment', BERTWEET_MODELS['sentiment'])
    feats['Sentiment - Negative'] = np.array([1 if 'neg' in l else 0 for l in labels])
    feats['Sentiment - Positive'] = np.array([1 if 'pos' in l else 0 for l in labels])
    feats['prob_Sentiment - Negative'] = np.array([p.get('neg', 0) for p in probs])
    feats['prob_Sentiment - Positive'] = np.array([p.get('pos', 0) for p in probs])

    # Emotion — verified label order: LABEL_0=joy, LABEL_1=optimism, LABEL_2=anger, LABEL_3=sadness
    labels, probs = _run_bt_pipe(texts, 'emotion', BERTWEET_MODELS['emotion'])
    emo_map = {'Joy': 'label_0', 'Optimism': 'label_1', 'Anger': 'label_2', 'Sadness': 'label_3'}
    for name, lbl in emo_map.items():
        feats[name] = np.array([1 if l == lbl else 0 for l in labels])
        feats[f'prob_{name}'] = np.array([p.get(lbl, 0) for p in probs])

    # Binary tasks: LABEL_0=negative, LABEL_1=positive
    for task in ['hate', 'irony', 'offensive']:
        labels, probs = _run_bt_pipe(texts, task, BERTWEET_MODELS[task])
        name = 'Hateful Speech' if task == 'hate' else task.title()
        feats[name] = np.array([1 if l == 'label_1' else 0 for l in labels])
        feats[f'prob_{name}'] = np.array([p.get('label_1', 0) for p in probs])

    return feats

# ── Regression ────────────────────────────────────────────────────────────────

def ols_with_ci(y, x):
    if hasattr(x, 'values'):
        x = x.values
    x = x.astype(float)
    valid = ~(np.isnan(y) | np.isnan(x))
    y_v, x_v = y[valid], x[valid]
    if x_v.var() == 0 or len(y_v) < 5:
        return None
    coef = LinearRegression().fit(x_v.reshape(-1, 1), y_v).coef_[0]
    y_hat = x_v * coef + (y_v.mean() - coef * x_v.mean())
    mse = np.mean((y_v - y_hat) ** 2)
    ss_x = np.sum((x_v - x_v.mean()) ** 2)
    se = np.sqrt(mse / ss_x) if ss_x > 0 else 0
    t = stats.t.ppf(0.975, len(y_v) - 2)
    return {'coefficient': coef, 'ci_lower': coef - t * se, 'ci_upper': coef + t * se}

def run_analysis(y, feats):
    return {n: r for n, f in feats.items() if (r := ols_with_ci(y, f)) is not None}

# ── Forest plot ───────────────────────────────────────────────────────────────

def forest_plot(all_results, title, out_path):
    all_keys = set(k for m in all_results.values() for k in m.keys())
    order = [f for _, grp in FEATURE_GROUPS for f in grp if f in all_keys]
    if not order:
        print(f"  No results to plot for {title}")
        return

    models   = list(all_results.keys())
    offsets  = np.linspace(-0.25, 0.25, len(models))
    fig, ax  = plt.subplots(figsize=(12, len(order) * 0.7 + 2))

    for i, model_name in enumerate(models):
        color = MODEL_COLORS.get(model_name, 'black')
        for j, feat in enumerate(order):
            if feat not in all_results[model_name]:
                continue
            r = all_results[model_name][feat]
            y_pos = j + offsets[i]
            ax.plot([r['ci_lower'], r['ci_upper']], [y_pos, y_pos], color=color, lw=2, alpha=0.7)
            ax.plot(r['coefficient'], y_pos, 'o', color=color, mfc='w', markersize=6)

    for j in range(len(order) - 1):
        ax.axhline(j + 0.5, color='grey', linewidth=1.0, linestyle='-', alpha=0.5)

    ax.axvline(0, color='black', alpha=0.3, ls='--')
    ax.set_yticks(range(len(order)))
    ax.set_yticklabels(order)
    ax.set_xlabel('Effect Coefficient (95% CI)')
    ax.set_title(title)
    ax.legend(handles=[mpatches.Patch(color=MODEL_COLORS[m], label=m) for m in models])
    plt.tight_layout()
    plt.savefig(out_path, dpi=300, bbox_inches='tight')
    plt.savefig(out_path.replace('.png', '.pdf'), bbox_inches='tight')
    plt.close()
    print(f"  Saved {out_path}")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=== Loading data ===")
    df = load_combined_data()
    y  = df['Normalized Ability'].values.astype(float)

    meta_cols = [c for c in ['Text_ID', 'Text', 'Normalized Ability', 'platform', 'source', 'persona', 'model']
                 if c in df.columns]
    meta = df[meta_cols].reset_index(drop=True)

    def save_csv(feats, fname):
        out = pd.concat([meta, pd.DataFrame({k: np.array(v) for k, v in feats.items()})], axis=1)
        out.to_csv(os.path.join(DATA_DIR, fname), index=False)
        print(f"  Saved {fname}")

    def split(feats):
        binary = {k: v for k, v in feats.items() if not k.startswith('prob_')}
        prob   = {k[5:]: v for k, v in feats.items() if k.startswith('prob_')}
        return binary, prob

    # ── Inference ──────────────────────────────────────────────────────────────
    print("\n--- TweetEval (from CSV) ---")
    te_feats = extract_tweeteval_features(df)
    save_csv(te_feats, 'labels_tweeteval.csv')

    print("\n--- TweetNLP ---")
    tnlp_feats = extract_tweetnlp_features(df)
    save_csv(tnlp_feats, 'labels_tweetnlp.csv')

    print("\n--- BERTweet ---")
    bt_feats = extract_bertweet_features(df)
    save_csv(bt_feats, 'labels_bertweet.csv')

    # ── Regression ─────────────────────────────────────────────────────────────
    print("\n=== Running regressions ===")
    te_bin,   te_prob   = split(te_feats)
    tnlp_bin, tnlp_prob = split(tnlp_feats)
    bt_bin,   bt_prob   = split(bt_feats)

    binary_results = {
        'TweetEval': run_analysis(y, te_bin),
        'TweetNLP':  run_analysis(y, tnlp_bin),
        'BERTweet':  run_analysis(y, bt_bin),
    }
    prob_results = {
        'TweetEval': run_analysis(y, te_prob),
        'TweetNLP':  run_analysis(y, tnlp_prob),
        'BERTweet':  run_analysis(y, bt_prob),
    }

    # ── Plots ──────────────────────────────────────────────────────────────────
    print("\n=== Generating plots ===")
    forest_plot(binary_results,
                'Impact of Text Features on Perceived Humanness (Binary Labels)',
                os.path.join(DATA_DIR, 'model_comparison_binary.png'))
    forest_plot(prob_results,
                'Impact of Text Features on Perceived Humanness (Probability Scores)',
                os.path.join(DATA_DIR, 'model_comparison_probability.png'))

    print("\nDone.")

if __name__ == '__main__':
    main()
