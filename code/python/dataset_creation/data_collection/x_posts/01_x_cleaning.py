"""
@author: ransell
"""

import pandas as pd
import os

# Define the folder containing the CSV files
folder_path = 'raw_x'  # Replace with the path to your folder
cleaned_folder_path = 'x_cleaned'  # Output folder

# Create the cleaned folder if it doesn't exist
os.makedirs(cleaned_folder_path, exist_ok=True)

# List of columns to drop
columns_to_drop = [
    'lang', 'edit_history_tweet_ids', 'author_id', 'user.name',
    'user.id', 'user.description', 'user.username', 'user.location',
    'user.url', 'geo.place_id', 'places.country_code', 'places.full_name',
    'places.id', 'user.withheld.country_codes'
]

# Process each CSV file in the folder
for filename in os.listdir(folder_path):
    if filename.endswith('.csv'):
        file_path = os.path.join(folder_path, filename)
        
        # Read the CSV file
        df = pd.read_csv(file_path)

        # Replace URLs with 'HTTPURL'
        df.replace(to_replace=r'http[s]?://\S+', value='HTTPURL', regex=True, inplace=True)

        # Replace usernames with '@USER'
        df.replace(to_replace=r'(?<=@)\w+', value='USER', regex=True, inplace=True)

        # Drop specified columns
        df.drop(columns=columns_to_drop, errors='ignore', inplace=True)

        # Save the cleaned DataFrame to the new cleaned folder
        cleaned_file_path = os.path.join(cleaned_folder_path, f'cleaned_{filename}')
        df.to_csv(cleaned_file_path, index=False)

print("Cleaning completed. Cleaned files are saved in 'x_cleaned' folder.")
