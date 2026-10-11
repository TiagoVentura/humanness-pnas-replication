# Data Generation for Social Media Posts

This directory contains scripts to generate synthetic social media posts and comments for our academic paper. We support four “platforms” × two back-ends:

* **Truth Social (TS)**

  * `tspost_gpt.py` (OpenAI GPT)
  * `tspost_llama.py` (LLaMA via Ollama)

* **TikTok (TT)**

  * `ttpost_gpt.py` (OpenAI GPT)
  * `ttpost_llama.py` (LLaMA via Ollama)

* **X (formerly Twitter)**

  * `xpost_gpt.py` (OpenAI GPT)
  * `xpost_llama.py` (LLaMA via Ollama)

* **YouTube (YT)**

  * `ytpost_gpt.py` (OpenAI GPT)
  * `ytpost_llama.py` (LLaMA via Ollama)

---

## Folder Structure

```
data_generation/
├── data/
│   ├── FullDebateTranscript.txt       # 2024 debate transcript
│   ├── political_prompt_personas.csv  # Persona definitions (name + prompt)
│   ├── tt_transcripts/                # TikTok transcripts (.txt)
│   └── yt_transcripts/                # YouTube transcripts (.txt)
├── generated_data/                    # Created at runtime by scripts
│   ├── ts_posts/
│   ├── tt_posts/
│   └── ...
├── tspost_gpt.py
├── tspost_llama.py
├── ttpost_gpt.py
├── ttpost_llama.py
├── xpost_gpt.py
├── xpost_llama.py
├── ytpost_gpt.py
├── ytpost_llama.py
├── requirements.txt
└── readme.md
```

---

## Installation

1. **Clone** this repo and change directory to `data_generation/`.
2. *(Optional)* Create a virtual environment:

   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. **Install Python dependencies**:

   ```bash
   pip install -r requirements.txt
   ```
4. **Setup Ollama** (for LLaMA scripts):

   * Install Docker.
   * Follow Ollama documentation to install and run.
   * Pull required models, for example:

     ```bash
     ollama pull llama2:70b
     ollama pull llama3.3
     ollama pull llama3.2:3b
     ```

---

## Usage

### OpenAI-powered scripts

Each GPT script requires your OpenAI API key as a positional argument. Defaults are shown in brackets (default 20).

#### Truth Social (GPT)

```bash
python tspost_gpt.py \
  -t ./data/FullDebateTranscript.txt \
  -p ./data/political_prompt_personas.csv \
  -n 20 \
  YOUR_OPENAI_API_KEY
```

* `-t`, `--transcript_filepath` (default `./data/FullDebateTranscript.txt`)
* `-p`, `--persona_filepath` (default `./data/political_prompt_personas.csv`)
* `-n`, `--number_of_posts` (default `20`)

**Output:**
`generated_data/ts_posts/gen_ts_posts_<persona>.csv`

---

#### TikTok (GPT)

```bash
python ttpost_gpt.py \
  -p ./data/political_prompt_personas.csv \
  -y ./data/tt_transcripts \
  -n 20 \
  YOUR_OPENAI_API_KEY
```

* `-p`, `--persona_filepath`
* `-y`, `--yt_transcripts_dir` (default `./data/tt_transcripts`)
* `-n`, `--number_of_posts`

**Output:**
`generated_data/tt_posts/tt_<video_id>.csv`

---

#### X (GPT)

```bash
python xpost_gpt.py \
  -t ./data/FullDebateTranscript.txt \
  -p ./data/political_prompt_personas.csv \
  -n 20 \
  YOUR_OPENAI_API_KEY
```

**Output:**
`generated_data/gen_x_posts_<persona>.csv`

---

#### YouTube (GPT)

```bash
python ytpost_gpt.py \
  -p ./data/political_prompt_personas.csv \
  -y ./data/yt_transcripts \
  -n 20 \
  YOUR_OPENAI_API_KEY
```

**Output:**
`generated_data/yt_<video_id>.csv`

---

### LLaMA-powered scripts

Ensure Ollama is running locally with the required model.

#### Truth Social (LLama)

```bash
python tspost_llama.py \
  -t ./data/FullDebateTranscript.txt \
  -p ./data/political_prompt_personas.csv \
  -n 20
```

**Output:**
`generated_data/ts_posts/llama2_70b/posts_<persona>_llama_2.csv`

---

#### TikTok (LLama)

```bash
python ttpost_llama.py \
  -p ./data/political_prompt_personas.csv \
  -y ./data/tt_transcripts \
  -n 20
```

**Output:**
`generated_data/tt_posts/tt_<video_id>_llama.csv`

---

#### X (LLama)

```bash
python xpost_llama.py \
  -t ./data/FullDebateTranscript.txt \
  -p ./data/political_prompt_personas.csv \
  -n 20
```

**Output:**
`generated_data/posts_<persona>_llama.csv`

---

#### YouTube (LLama)

```bash
python ytpost_llama.py \
  -p ./data/political_prompt_personas.csv \
  -y ./data/yt_transcripts \
  -n 20
```

**Output:**
`generated_data/yt_<video_id>_llama.csv`

---

## Input Data

* `FullDebateTranscript.txt` – Full transcript of the 2024 U.S. presidential debate.
* `political_prompt_personas.csv` – CSV of personas.
  Expected columns:

  1. Name
  2. (unused)
  3. Prompt text
* `tt_transcripts/` – TikTok video transcripts (.txt).
* `yt_transcripts/` – YouTube video transcripts (.txt).

---

## Output Data

All scripts write into `generated_data/`, creating per-platform subfolders or files.
Each CSV contains at least:

* `generated_post` (the synthetic post/comment)
* `persona` (for the TT and YT scripts)

---

## Notes

* Each script creates the `generated_data` directory (and any required subfolders) automatically if it does not already exist.

* GPT scripts include a 90s sleep between personas to respect rate limits.

* LLaMA scripts rely on your local Ollama server; no API key is needed.

* Adjust the `MODEL` constants in each script to switch back-ends or model sizes.

* Adjust the \`MODEL\` constants in each script to switch between models.
