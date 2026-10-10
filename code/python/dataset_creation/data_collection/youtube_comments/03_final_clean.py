"""
@author: ransell
"""
import os
import pandas as pd
import re

file_path = "yt_combined_dataset.csv"

def clean_comment(comment):
    # Replace any sequence of one or more @ symbols plus word/digit/underscore/dash characters with @USER
    # Examples matched:
    #   @@USER-w9uNews -> @USER
    #   @username_123 -> @USER
    #   @my-username -> @USER
    comment = re.sub(r'@+[A-Za-z0-9_\-]+', '@USER', comment)
    
    # Replace URLs with HTTPURL
    comment = re.sub(r'\b(?:https?://|ftp://|www\.)\S+\b', 'HTTPURL', comment)
    
    return comment.strip()

if os.path.exists(file_path):
    df = pd.read_csv(file_path)
    
    if "comment" in df.columns:
        df["comment"] = df["comment"].astype(str).apply(clean_comment)
    else:
        print(f"'comment' column not found in {file_path}. Check the input file.")
    
    # Overwrite the file with cleaned data
    df.to_csv(file_path, index=False)
    print(f"Cleaned dataset saved to {file_path}")
else:
    print(f"Input file '{file_path}' not found. Ensure the file exists in the same directory as this script.")
