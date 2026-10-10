"""
@author: ransell
"""
# Real world sample, 50 comments per video Includes check for English Includes check for unique posts

import os
import pandas as pd
import re
from langdetect import detect, LangDetectException

# Define the paths for real-world YouTube comments CSV files
youtube_csv_directory = r'./csv_yt_comments' # Replace with your folder path

# Output file for the YouTube combined dataset
youtube_output_csv_path = 'yt_combined_dataset.csv'

# Load existing dataset if it exists, otherwise initialize an empty DataFrame
if os.path.exists(youtube_output_csv_path):
    youtube_combined_dataset = pd.read_csv(youtube_output_csv_path)
else:
    youtube_combined_dataset = pd.DataFrame()

# Function to check if a post is in English
def is_english(text):
    try:
        return detect(text) == 'en'
    except LangDetectException:
        return False

# Function to ensure exactly 50 unique posts per video
def get_unique_posts(df, n=50):
    unique_posts = pd.DataFrame()
    sampled_df = df.copy()
    while len(unique_posts) < n and len(sampled_df) > 0:
        # Continue sampling remaining comments until 50 unique posts are reached
        sample_needed = n - len(unique_posts)
        sampled_comments = sampled_df.sample(n=min(sample_needed, len(sampled_df)), random_state=42)
        
        # Drop duplicates and update the set of unique posts
        unique_posts = pd.concat([unique_posts, sampled_comments]).drop_duplicates(subset=['textDisplay'], ignore_index=True)
        
        # Remove already-sampled comments from the pool to prevent re-selection
        sampled_df = sampled_df[~sampled_df['textDisplay'].isin(unique_posts['textDisplay'])]
        
        if len(sampled_df) == 0:
            print("Not enough unique English comments to reach 50 for this video.")

    return unique_posts

# Iterate over CSV files in the directory
for csv_file in os.listdir(youtube_csv_directory):
    if csv_file.endswith('.csv'):
        csv_path = os.path.join(youtube_csv_directory, csv_file)
        
        # Load each CSV file into a DataFrame
        df = pd.read_csv(csv_path)
        
        # Randomly select 1000 posts per video
        sampled_df = df[['textDisplay', 'videoId']].sample(n=min(1000, len(df)), random_state=42)
        
        # Filter for English posts only
        english_df = sampled_df[sampled_df['textDisplay'].apply(is_english)]
        
        # Ensure we get exactly 50 unique English posts
        unique_df = get_unique_posts(english_df, n=50)
        
        # Rename 'textDisplay' to 'comment'
        unique_df.rename(columns={'textDisplay': 'comment'}, inplace=True)
        
        # Remove numbers followed by a period at the start of the comment
        unique_df['comment'] = unique_df['comment'].apply(lambda x: re.sub(r'^\d+\.\s*', '', x))
        
        # Remove surrounding quotation marks if present
        unique_df['comment'] = unique_df['comment'].apply(lambda x: x.strip('"').strip() if x.startswith('"') and x.endswith('"') else x)
        
        # Set the source as 'YouTube'
        unique_df['source'] = 'YouTube'
        
        # Append the data to the combined dataset
        youtube_combined_dataset = pd.concat([youtube_combined_dataset, unique_df], ignore_index=True)

        # Print stats for each video
        print(f"Processed {csv_file}: Total unique English posts = {len(unique_df)}")

# Drop duplicate posts to ensure all comments are unique across the entire dataset
youtube_combined_dataset.drop_duplicates(subset=['comment', 'videoId'], inplace=True)

# Print the final dataset size before saving
print(f"Total comments saved to CSV: {youtube_combined_dataset.shape[0]}")

# Save the combined dataset to a CSV file
youtube_combined_dataset.to_csv(youtube_output_csv_path, index=False)

print("YouTube real-world combined dataset has been successfully updated.")