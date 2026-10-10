"""
@author: ransell
"""

import os
import json
import csv

# Define the base and folder paths (relative to this script's location)
base_dir = os.path.dirname(os.path.abspath(__file__))
input_folder = os.path.join(base_dir, "json_updated")
output_folder = os.path.join(base_dir, "csv_updated")

# Create the output folder if it doesn't exist
if not os.path.exists(output_folder):
    os.makedirs(output_folder)

def convert_entry_to_dict(entry):
    if isinstance(entry, dict):
        return entry
    elif isinstance(entry, list):
        return {f"value_{i}": v for i, v in enumerate(entry)}
    else:
        return {"value": entry}

# Process each JSON file in the input folder
for filename in os.listdir(input_folder):
    if filename.endswith(".json"):
        input_file_path = os.path.join(input_folder, filename)
        output_file_path = os.path.join(output_folder, f"{os.path.splitext(filename)[0]}.csv")
        
        normalized_data = []
        try:
            with open(input_file_path, 'r', encoding='utf-8') as json_file:
                # Read each line separately since it's NDJSON
                for line in json_file:
                    line = line.strip()
                    if line:  # Skip empty lines
                        try:
                            normalized_data.append(json.loads(line))
                        except json.JSONDecodeError as e:
                            print(f"Error decoding JSON in {input_file_path}: {e}")
        except Exception as e:
            print(f"Error opening {input_file_path}: {e}")
            continue

        if not normalized_data:
            print(f"No data found in {input_file_path}. Skipping file.")
            continue

        # Normalize each entry to a dictionary
        normalized_data = [convert_entry_to_dict(entry) for entry in normalized_data]

        # Determine all fieldnames from the data
        fieldnames = set()
        for entry in normalized_data:
            if isinstance(entry, dict):
                fieldnames.update(entry.keys())
        fieldnames = list(fieldnames)

        try:
            with open(output_file_path, 'w', newline='', encoding='utf-8') as csv_file:
                writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
                writer.writeheader()
                for entry in normalized_data:
                    writer.writerow(entry)
        except Exception as e:
            print(f"Error writing CSV to {output_file_path}: {e}")
            continue

        print(f"Converted {filename} to CSV at {output_file_path}")
