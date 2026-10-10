
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
@author: ransell
"""

# IMPORT PACKAGES 
import argparse
import pandas as pd 
from openai import OpenAI
import os

# LOAD FILES
DEFAULT_PERSONA_FILEPATH = "./data/political_prompt_personas.csv"
DEFAULT_YT_TRANSCRIPTS_DIR = "./data/tt_transcripts"

# OPENAI USER CONFIG
MODEL = "gpt-4" # select model for generation

# FUNCTIONS
def prompt_gpt(client, system_prompt, user_prompt):
    try:
        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.7,
            top_p=0.8,
            n=1,
            stream=False,
            presence_penalty=0,
            frequency_penalty=0
        )
        output = response.choices[0].message.content
        return output 
    except Exception as e:
        print(f"Error in prompt_gpt: {e}")
        return None

def parse_gpt_response(gpt_text):
    if not gpt_text:
        print("No GPT response to parse.")
        return pd.DataFrame()

    # Split the string into lines
    lines = gpt_text.split('\n')

    # Remove any empty lines and strip "Comment X" from lines
    lines = [line.strip().split(':', 1)[-1].strip() if line.lower().startswith("comment") else line.strip() for line in lines if line.strip()]
    
    # Create a DataFrame with each line as a generated post
    df = pd.DataFrame({'generated_post': lines})

    return df

def main(args):
    print("Main function started.")

    # Initialize OpenAI client
    try:
        client = OpenAI(api_key=args.api_key)
        print("OpenAI client initialized successfully.")
    except Exception as e:
        print(f"Error initializing OpenAI client: {e}")
        return

    persona_filepath = args.persona_filepath
    yt_transcripts_dir = args.yt_transcripts_dir

    # Load personas
    try:
        persona_df = pd.read_csv(persona_filepath, header=0)
        print(f"Persona CSV loaded successfully from: {persona_filepath}")
    except FileNotFoundError:
        print(f"Error: Persona CSV file not found at {persona_filepath}")
        return
    except Exception as e:
        print(f"Error while loading persona CSV: {e}")
        return

    # Iterate through TikTok transcript files
    for transcript_filename in os.listdir(yt_transcripts_dir):
        transcript_filepath = os.path.join(yt_transcripts_dir, transcript_filename)
        if not transcript_filename.endswith(".txt"):
            continue

        # Load transcript
        try:
            with open(transcript_filepath, 'r', encoding='utf-8') as file:
                transcript = file.read()
                print(f"Transcript file loaded successfully from: {transcript_filepath}")
        except FileNotFoundError:
            print(f"Error: Transcript file not found at {transcript_filepath}")
            continue
        except Exception as e:
            print(f"Error while loading transcript file: {e}")
            continue

        # Set user prompt template for TikTok comments
        user_prompt_template = f"""
        You are fully embodying the persona described above. After reading the TikTok video transcript provided, generate {args.number_of_posts} TikTok-style comments reacting to the 2024 U.S. presidential debate between Kamala Harris and Donald Trump.
        
        Guidelines for comments:
        - Emulate TikTok-style comments that the persona would post during or immediately after the debate.
        - Vary length (5 to 50 words), tone, punctuation, emojis, casing, and sentence structure.
        - Base your comments on the *most frequently mentioned topics and emotional moments* in the transcript.
        - Especially focus on these top 5 debate topics if they appear: character/fitness, economy, abortion, foreign policy, and health care.
        - Use internet-speak and authentic emotional expression, including masked curse words (e.g., s**t, f**k).
        - Allow for slang, broken punctuation, emoji reactions (:skull:, :sob:, :clown_face:, etc.), and informal grammar.
        -Comments should feel *reactive, emotional, and organic*, not like polished writing. 
        """

        # Loop through each persona
        all_persona_posts = []
        for idx, row in persona_df.iterrows():
            print(f"Generating posts for persona: {row[0]} for video: {transcript_filename}")

            # Get persona text description
            persona = row[2]

            # Set system prompt (persona and transcript)
            system_prompt_template = f"{persona}. Take in this TikTok video transcript related to the 2024 U.S. presidential debate between Kamala Harris and Donald Trump: {transcript}"
            
            # Prompt GPT-4o
            gpt_response = prompt_gpt(client, system_prompt_template, user_prompt_template)
            if not gpt_response:
                print(f"Failed to generate posts for persona: {row[0]}")
                continue

            print(f"GPT Response for persona {row[0]}: {gpt_response}")

            # Parse response
            output_df = parse_gpt_response(gpt_response)
            if output_df.empty:
                print(f"No valid posts generated for persona: {row[0]}")
                continue

            # Add persona column 
            output_df['persona'] = row[0]
            all_persona_posts.append(output_df)

        # Concatenate all persona posts for the current video
        if all_persona_posts:
            final_df = pd.concat(all_persona_posts, ignore_index=True)
            final_df = final_df[['persona', 'generated_post']]

            # Ensure output directory exists
            output_dir = "./generated_data/tt_posts"
            if not os.path.exists(output_dir):
                os.makedirs(output_dir)

            # Save output to CSV
            video_id = os.path.splitext(transcript_filename)[0]
            outfile_name = f"{output_dir}/tt_{video_id}.csv"
            try:
                if os.path.exists(outfile_name):
                    existing_df = pd.read_csv(outfile_name)
                    updated_df = pd.concat([existing_df, final_df], ignore_index=True)
                    updated_df.to_csv(outfile_name, index=False)
                else:
                    final_df.to_csv(outfile_name, index=False)
                print(f"Output saved successfully to: {outfile_name}")
            except Exception as e:
                print(f"Error while saving output for video {transcript_filename}: {e}")

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--persona_filepath", default=DEFAULT_PERSONA_FILEPATH)
    parser.add_argument("-y", "--yt_transcripts_dir", default=DEFAULT_YT_TRANSCRIPTS_DIR)
    parser.add_argument("-n", "--number_of_posts", type=int, default=50)
    parser.add_argument("api_key")
    return parser.parse_args()

if __name__ == "__main__":
    main(parse_args())
