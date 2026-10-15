# 21_fig_s11_tweeteval.py
# author: Rebecca Ansell
#
# Fig. S11 — Distribution of TweetEval probability scores by authorship
# family (Human, GPT, LLaMA) for 9 emotive features.
# Individual posts shown as jittered scatter; diamond markers = group mean.
# Features grouped into: Sentiment (Negative, Positive) |
#   Emotion (Joy, Optimism, Anger, Sadness) | Other (Hateful, Irony, Offensive)
#
# Data: data/tweeteval_eval/labels_tweeteval.csv
#   columns: Text_ID, Text, Normalized Ability, platform, source, persona, model,
#            prob_Sentiment - Negative, prob_Sentiment - Positive,
#            prob_Joy, prob_Optimism, prob_Anger, prob_Sadness,
#            prob_Hateful Speech, prob_Irony, prob_Offensive, …
#
# Run from this folder:  python 21_fig_s11_tweeteval.py

import os
import warnings
warnings.filterwarnings('ignore')

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

PKG_ROOT  = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
DATA_FILE = os.path.join(PKG_ROOT, 'data', 'tweeteval_eval', 'labels_tweeteval.csv')
OUT_DIR   = os.path.join(PKG_ROOT, 'output')

FAMILY_COLORS = {
    'Human': '#2166ac',
    'GPT':   '#d6604d',
    'LLaMA': '#4dac26',
}

PROB_FEATURES = [
    ('Sentiment', ['prob_Sentiment - Negative', 'prob_Sentiment - Positive']),
    ('Emotion',   ['prob_Joy', 'prob_Optimism', 'prob_Anger', 'prob_Sadness']),
    ('Other',     ['prob_Hateful Speech', 'prob_Irony', 'prob_Offensive']),
]

FEATURE_LABELS = {
    'prob_Sentiment - Negative': 'Negative',
    'prob_Sentiment - Positive': 'Positive',
    'prob_Joy':                  'Joy',
    'prob_Optimism':             'Optimism',
    'prob_Anger':                'Anger',
    'prob_Sadness':              'Sadness',
    'prob_Hateful Speech':       'Hateful',
    'prob_Irony':                'Irony',
    'prob_Offensive':            'Offensive',
}


def assign_family(model_str):
    if not isinstance(model_str, str):
        return None
    m = model_str.lower()
    if m == 'human':
        return 'Human'
    if 'gpt' in m:
        return 'GPT'
    if 'llama' in m:
        return 'LLaMA'
    return None


def main():
    df = pd.read_csv(DATA_FILE)
    df['family'] = df['model'].apply(assign_family)
    df = df[df['family'].notna()]

    families = ['Human', 'GPT', 'LLaMA']
    all_features = [f for _, grp in PROB_FEATURES for f in grp]
    n_feats = len(all_features)

    fig, axes = plt.subplots(1, n_feats, figsize=(n_feats * 1.6 + 1, 5),
                             sharey=True)

    rng = np.random.default_rng(42)

    for ax_idx, feat in enumerate(all_features):
        ax = axes[ax_idx]
        label = FEATURE_LABELS[feat]

        for x_idx, family in enumerate(families):
            color = FAMILY_COLORS[family]
            vals = df.loc[df['family'] == family, feat].dropna()

            jitter = rng.uniform(-0.18, 0.18, size=len(vals))
            ax.scatter(
                np.full(len(vals), x_idx) + jitter, vals,
                color=color, alpha=0.12, s=6, linewidths=0, zorder=2,
            )

            m = vals.mean()
            ax.plot(x_idx, m, 'D', color=color, markersize=7,
                    markeredgecolor='white', markeredgewidth=0.8, zorder=4)

        ax.set_xticks(range(len(families)))
        ax.set_xticklabels(families, fontsize=7.5, rotation=30, ha='right')
        ax.set_title(label, fontsize=9, fontweight='bold', pad=4)
        ax.set_xlim(-0.6, len(families) - 0.4)
        ax.set_ylim(-0.02, 1.02)
        ax.tick_params(axis='y', labelsize=8)
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)

    axes[0].set_ylabel('Probability Score', fontsize=9)

    # Category background shading and group labels
    group_starts = [0]
    for _, grp in PROB_FEATURES[:-1]:
        group_starts.append(group_starts[-1] + len(grp))

    shading = ['#f5f5f5', '#ffffff', '#f5f5f5']
    for g_idx, (cat_name, grp) in enumerate(PROB_FEATURES):
        start = group_starts[g_idx]
        for feat_offset in range(len(grp)):
            axes[start + feat_offset].set_facecolor(shading[g_idx])
        axes[start].set_ylabel(cat_name, fontsize=8, color='#555555',
                               labelpad=30, rotation=90, va='center')

    axes[0].set_ylabel('Probability Score', fontsize=9)

    handles = [plt.Line2D([0], [0], marker='o', color='w',
               markerfacecolor=FAMILY_COLORS[f], markersize=8, label=f)
               for f in families]
    fig.legend(handles=handles, loc='lower center', ncol=3,
               fontsize=9, bbox_to_anchor=(0.5, -0.08), frameon=False)

    plt.tight_layout()

    for ext in ('png', 'pdf'):
        out = os.path.join(OUT_DIR, f'fig_s11.{ext}')
        plt.savefig(out, dpi=300, bbox_inches='tight')
        print(f'Saved {out}')


if __name__ == '__main__':
    main()
