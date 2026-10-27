# ChhanaAI

A small Flask chat app for English and Mizo vocabulary, backed by Ollama and a local SQLite database.

## Requirements

- Python 3.10 or newer
- [Ollama](https://ollama.com/) with the `gemma3:4b` model available

## Run locally

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
ollama pull gemma3:4b
python app.py
```

Then open http://127.0.0.1:5000. The app creates `chhan_memory.db` locally when it starts; database files are excluded from Git.
