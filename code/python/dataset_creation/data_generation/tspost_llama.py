#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
@author: ransell
"""

# example run: python xpost_llama_3_2_3b.py -t ./data/FullDebateTranscript.txt -p ./data/political_prompt_personas.csv -n 20
# must have docker with ollama running

# IMPORT PACKAGES
import argparse
import pandas as pd
import os
from ollama import chat

# LLaMA MODEL CONFIG
MODEL = "llama2:70b"

def extract_posts_from_response(response):
    try:
        # Extract the content field from the response
        content = response.get("message", {}).get("content", None)
        if not content:
            print("No content found in the response.")
            return []

        # Split the content into lines and clean up
        posts = []
        for line in content.split("\n"):
            line = line.strip()
            if line and line[0].isdigit():  # Include only numbered lines
                posts.append(line.split(". ", 1)[1].strip())  # Remove numbering
        return posts
    except Exception as e:
        print(f"Error extracting posts: {e}")
        return []

def prompt_llama( model, system_prompt, user_prompt, output_file):
    try:
        # Generate response from LLaMA
        response = chat(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ]
        )

        # Debugging: Inspect the raw response structure
        print("Raw response from LLaMA:", response)

        # Extract posts from the response
        posts = extract_posts_from_response(response)

        # Save posts to CSV
        if posts:
            df = pd.DataFrame({"generated_post": posts})
            if os.path.exists(output_file):
                # Append to the existing file
                df.to_csv(output_file, mode='a', header=False, index=False)
                print(f"Appended posts to existing file: {output_file}")
            else:
                # Create a new file with header
                df.to_csv(output_file, index=False)
                print(f"Generated posts saved to new file: {output_file}")
        else:
            print(f"No posts extracted for output file: {output_file}")

        return posts
    except Exception as e:
        print(f"Error in prompt_llama: {e}")
        return None

def main(args):
    print("Main function started.")

    # Initialize LLaMA client
    # try:
    #     client = Client("http://localhost:11434")
    #     print("LLaMA client initialized successfully.")
    # except Exception as e:
    #     print(f"Error initializing LLaMA client: {e}")
    #     return

    # Load transcript
    try:
        with open(args.transcript_filepath, 'r') as file:
            transcript = file.read()
            print(f"Transcript file loaded successfully from: {args.transcript_filepath}")
    except Exception as e:
        print(f"Error loading transcript: {e}")
        return

    # Load personas
    try:
        persona_df = pd.read_csv(args.persona_filepath)
        print(f"Loaded personas:\n{persona_df.head()}")
    except Exception as e:
        print(f"Error loading persona file: {e}")
        return

    # Loop through each persona
    output_dir = "./generated_data/ts_posts/llama2_70b"
    os.makedirs(output_dir, exist_ok=True)

    for idx, row in persona_df.iterrows():
        persona_name = row.iloc[0].replace(" ", "_").lower()
        output_file = f"{output_dir}/posts_{persona_name}_llama_2.csv"

        # Set system prompt (persona and transcript)
        system_prompt = f"{row.iloc[2]}. Take in this transcript of the 2024 U.S. presidential debate between Kamala Harris and Donald Trump: {transcript}"

        user_prompt_template = f"""
        Fully embodying your persona described above, please create {args.number_of_posts} unique Truth Social social media posts related to the 2024 U.S. presidential debate between Kamala Harris and Donald Trump. 
        These posts should emulate what this persona would post during or shortly after watching the debate live. 

        {args.number_of_posts} posts requirements:
        - These posts should emulate the style of Truth Social posts.
        - Vary the {args.number_of_posts} posts in length, style and topics mentioned in the debate. 
        - Focus on the top 5 topics that were debated the longest in the debate.
            - Character and fitness
            - Economy
            - Abortion
            - Foreign policy
            - Health care

        Specifically, add variations of the following components below:
        - ‘RT @USER’ at the beginning of some posts.
        - ‘HTTPURL’ at the end of some posts.
        - Vary capitalization. Some words and phrasings should be all-caps, especially when the words are colloquially-used and some sentence structures can be completely lowercased.
        - Vary the sentence structures. Sometimes you can do line breaks and some posts can have breaks between sentences. Some sentences can be short.
        - Vary punctuation usage. Some posts can have faulty punctuations to make it look more authentic, as if it’s coming from a lay user.
        - Include variations of curse words to make the posts sound more expressive and emotional. Conventional bad words should be masked with asterisks ‘*’.
        - Include an emoji or emojis where appropriate.
        - Posts should vary between 70 and 279 characters in length. Some short be shorter and punchy. Some should be longer and more detailed.
        - If you are tagging another user, it should be censored as '@USER'
        - Include either #Debatenight or #Debate2024 in your post. Feel free to generate other relevant hashtags pertaining to what you write.
        """

        # Generate and save posts directly
        prompt_llama(MODEL, system_prompt, user_prompt_template, output_file)

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--transcript_filepath", default="./data/FullDebateTranscript.txt")
    parser.add_argument("-p", "--persona_filepath", default="./data/political_prompt_personas.csv")
    parser.add_argument("-n", "--number_of_posts", type=int, default=50)
    return parser.parse_args()

if __name__ == "__main__":
    main(parse_args())
  