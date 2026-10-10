"""
@author: ransell
"""

# IMPORT PACKAGES 
import argparse
import pandas as pd 
from openai import OpenAI
import os
import time

# LOAD FILES
DEFAULT_TRANSCRIPT_FILEPATH = "./data/FullDebateTranscript.txt"
DEFAULT_PERSONA_FILEPATH = "./data/political_prompt_personas.csv"

# OPENAI USER CONFIG
MODEL = "gpt-4o-2024-08-06" # set to desired model

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

    # Remove any empty lines
    lines = [line.strip() for line in lines if line.strip()]
    
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

    transcript_filepath = args.transcript_filepath
    persona_filepath = args.persona_filepath

    # Load transcript
    try:
        with open(transcript_filepath, 'r') as file:
            transcript = file.read()
            transcript = transcript[:4000]
            print(f"Transcript file loaded successfully from: {transcript_filepath}")
    except FileNotFoundError:
        print(f"Error: Transcript file not found at {transcript_filepath}")
        return
    except Exception as e:
        print(f"Error while loading transcript file: {e}")
        return

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

    # Set user prompt template
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


    # Loop through each persona
    for idx, row in persona_df.iterrows():
        print(f"Generating posts for persona: {row[0]}")

        # Get persona text description
        persona = row[2]

        # Set system prompt (persona and transcript)
        system_prompt_template = f"{persona}. Take in this transcript of the 2024 U.S. presidential debate between Kamala Harris and Donald Trump: {transcript}"
        
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

        # Ensure output directory exists
        output_dir = "./generated_data/ts_posts"
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)

        # Save output to CSV
        persona_name = row[0].replace(" ", "_").lower()
        outfile_name = f"{output_dir}/gen_ts_posts_{persona_name}.csv"
        try:
            if os.path.exists(outfile_name):
                existing_df = pd.read_csv(outfile_name)
                updated_df = pd.concat([existing_df, output_df], ignore_index=True)
                updated_df.to_csv(outfile_name, index=False)
            else:
                output_df.to_csv(outfile_name, index=False)
            print(f"Output saved successfully to: {outfile_name}")
        except Exception as e:
            print(f"Error while saving output for persona {row[0]}: {e}")

        time.sleep(90)  

        

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--transcript_filepath", default=DEFAULT_TRANSCRIPT_FILEPATH)
    parser.add_argument("-p", "--persona_filepath", default=DEFAULT_PERSONA_FILEPATH)
    parser.add_argument("-n", "--number_of_posts", type=int, default=50)
    parser.add_argument("api_key")
    return parser.parse_args()

if __name__ == "__main__":
    main(parse_args())
