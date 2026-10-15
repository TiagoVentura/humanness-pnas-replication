# 20_fig_s1_botometer.py
# author: Rebecca Ansell
#
# Fig. S1 — Distribution of Botometer scores for the 147 X/Twitter authors
# included in the survey.  Scores range 0 (least bot-like) to 1 (most
# bot-like); red dashed line marks the 0.5 exclusion threshold.
#
# Data: data/botometer_output.csv
#   columns: bot_score, timestamp
#
# Run from this folder:  python 20_fig_s1_botometer.py

import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd

PKG_ROOT  = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
DATA_FILE = os.path.join(PKG_ROOT, 'data', 'botometer_output.csv')
OUT_DIR   = os.path.join(PKG_ROOT, 'output')


def main():
    df = pd.read_csv(DATA_FILE)
    df['bot_score'] = pd.to_numeric(df['bot_score'], errors='coerce')
    df = df.dropna(subset=['bot_score'])
    print(f"Authors: {len(df)}  |  above threshold: {(df['bot_score'] >= 0.5).sum()}")

    bins = [i / 10 for i in range(11)]  # 0.1-width bins

    fig, ax = plt.subplots(figsize=(7, 3.5))
    ax.hist(df['bot_score'], bins=bins,
            color='skyblue', edgecolor='black', alpha=0.8)
    ax.axvline(0.5, color='red', linestyle='--', linewidth=1.5,
               label='Threshold = 0.5')
    ax.set_xlim(0, 1)
    ax.set_xlabel('Bot Score')
    ax.set_ylabel('Number of Accounts')
    ax.set_title('Distribution of Botometer Scores')
    ax.legend()
    plt.tight_layout()

    for ext in ('png', 'pdf'):
        out = os.path.join(OUT_DIR, f'fig_s1.{ext}')
        plt.savefig(out, dpi=300, bbox_inches='tight')
        print(f'Saved {out}')


if __name__ == '__main__':
    main()
