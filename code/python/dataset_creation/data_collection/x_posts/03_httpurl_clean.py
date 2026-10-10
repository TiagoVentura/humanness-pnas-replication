"""
@author: ransell
"""

import os
import pandas as pd
import random
import re

input_file = "x_combined_dataset.csv"
output_file = "x_combined_dataset_clean.csv"

# List of intentionally broken t.co links
broken_links = [
    "https://t.co/ekfjwqir",
    "https://t.co/bnqupjzi",
    "https://t.co/vrmcploz",
    "https://t.co/hdyflqzw",
    "https://t.co/otrvbxam",
    "https://t.co/xzfcgwsr",
    "https://t.co/lpnevqok",
    "https://t.co/zurypbnm",
    "https://t.co/iqtmjczr",
    "https://t.co/wclxuvds"
]

def replace_httpurl_with_broken_link(text):

    # Replace every instance of 'HTTPURL' in the text with a randomly chosen broken link.

    if isinstance(text, str):
        return re.sub(r"HTTPURL", lambda m: random.choice(broken_links), text)
    return text

if os.path.exists(input_file):
    df = pd.read_csv(input_file)
    
    # Process all columns with string data
    for col in df.select_dtypes(include=['object']).columns:
        df[col] = df[col].apply(replace_httpurl_with_broken_link)
    
    # Save the cleaned DataFrame to a new CSV file
    df.to_csv(output_file, index=False)
    print(f"Cleaned dataset saved to {output_file}")
else:
    print(f"Input file '{input_file}' not found. Ensure the file exists in the same directory as this script.")
