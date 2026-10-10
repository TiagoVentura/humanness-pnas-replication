"""
@author: ransell
"""

import os
import json
import pandas as pd

# Define the path where the JSON files are located - replace with your folder path
json_directory = './raw_yt_comments'

# Output directory for CSV files
output_directory = './csv_yt_comments'
os.makedirs(output_directory, exist_ok=True)

# Create a new directory for cleaned JSON files
cleaned_json_directory = './cleaned_yt_comments'
os.makedirs(cleaned_json_directory, exist_ok=True)

# Hard-coded dictionary mapping video IDs to the desired CSV names
id_to_name_mapping = {
    'OQgE0ETV81s': 'v1',
    '4aw5FziSc14': 'v2',
    'FxgOR1KHCpQ': 'v4',
    'tv_xWNfp0Bc': 'v6',
    'ceVV5rwV4L4': 'v7',
    'kADujQsWO68': 'v8',
    'KtHn59wqdBc': 'v9',
    'fgN3DZNHtFI': 'v13',
    '5cft5c6mE8k': 'v15',
    'Xp_xIfyDIG4': 'v17'
}

# Iterate over JSON files in the directory
for json_file in os.listdir(json_directory):
    if json_file.endswith('.json'):
        json_path = os.path.join(json_directory, json_file)

        # Extract video ID from the filename (remove '_comments' part)
        video_id = json_file.replace('_comments.json', '')

        # Open the JSON file and parse its content
        with open(json_path, 'r') as file:
            comments_data = [json.loads(line) for line in file]

        # Extract the required fields and filter out comments with 5 words or fewer
        filtered_comments = []
        for comment in comments_data:
            snippet = comment.get('snippet', {})
            text = snippet.get('textDisplay', "")
            word_count = len(text.split())

            if word_count > 5:
                filtered_comments.append({
                    'etag': comment.get('etag'),
                    'id': comment.get('id'),
                    'videoId': snippet.get('videoId'),
                    'textDisplay': text
                })

        # Determine the mapped CSV name based on videoId
        csv_name = id_to_name_mapping.get(video_id, f"unknown_{video_id}")
        output_csv_path = os.path.join(output_directory, f"{csv_name}.csv")

        # Convert the filtered data to a DataFrame and save it as CSV
        filtered_df = pd.DataFrame(filtered_comments)
        filtered_df.to_csv(output_csv_path, index=False)

print("CSV files have been successfully created.")