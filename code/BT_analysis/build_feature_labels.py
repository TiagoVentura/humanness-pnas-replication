# build_feature_labels.py
# author: Rebecca Ansell
#
# Builds the two classifier-label files read by code/08_semantic_features.R:
#   data/tweeteval_eval/labels_tweeteval.csv  (Cardiff NLP TweetEval RoBERTa labels,
#                                              taken from the post_traits_*.csv files)
#   data/tweeteval_eval/labels_bertweet.csv   (BERTweet models, fresh inference through
#                                              HuggingFace; GPU used if available)
# Each file holds one row per post with binary 0/1 labels and the class probabilities
# for sentiment, emotion, hate, irony and offensive classification.
#
# Run from this folder:  python build_feature_labels.py

import os
import numpy as np
import pandas as pd

try:
    import torch
    DEVICE = 0 if torch.cuda.is_available() else -1
except ImportError:
    DEVICE = -1

HERE       = os.path.dirname(os.path.abspath(__file__))
INPUT_DIR  = os.path.join(HERE, '..', '..', 'data', 'bt_scores_features')
OUTPUT_DIR = os.path.join(HERE, '..', '..', 'data', 'tweeteval_eval')

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
MAX_CHARS  = 512

# ── Helpers ────────────────────────────────────────────────────────────────────

def _sanitize(text):
    if not isinstance(text, str):
        text = str(text) if text is not None else ''
    text = ''.join(ch for ch in text if ch.isprintable()).replace('\x00', '').strip()
    return text[:MAX_CHARS] or '[empty]'

def load_combined_data():
    dfs = []
    for platform, fname in PLATFORM_FILES.items():
        path = os.path.join(INPUT_DIR, fname)
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

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=== Loading data ===")
    df = load_combined_data()

    meta_cols = [c for c in ['Text_ID', 'Text', 'Normalized Ability', 'platform', 'source', 'persona', 'model']
                 if c in df.columns]
    meta = df[meta_cols].reset_index(drop=True)

    def save_csv(feats, fname):
        out = pd.concat([meta, pd.DataFrame({k: np.array(v) for k, v in feats.items()})], axis=1)
        out.to_csv(os.path.join(OUTPUT_DIR, fname), index=False)
        print(f"  Saved {fname}")

    print("\n--- TweetEval (from CSV) ---")
    save_csv(extract_tweeteval_features(df), 'labels_tweeteval.csv')

    print("\n--- BERTweet ---")
    save_csv(extract_bertweet_features(df), 'labels_bertweet.csv')

    print("\nDone.")

if __name__ == '__main__':
    main()
