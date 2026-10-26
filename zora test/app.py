from flask import Flask, request, jsonify, render_template
from ollama import chat
import sqlite3
import re

app = Flask(__name__)

MODEL = "gemma3:4b"
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATABASE = os.path.join(BASE_DIR, "chhan_memory.db")


# ---------- DATABASE ----------

def init_db():
    with sqlite3.connect(DATABASE) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS vocabulary (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                mizo TEXT NOT NULL,
                english TEXT NOT NULL,
                example TEXT DEFAULT '',
                UNIQUE(mizo, english)
            )
        """)


def save_word(mizo, english, example=""):
    with sqlite3.connect(DATABASE) as conn:
        conn.execute("""
            INSERT OR IGNORE INTO vocabulary
            (mizo, english, example)
            VALUES (?, ?, ?)
        """, (mizo, english, example))


def search_words(query):
    with sqlite3.connect(DATABASE) as conn:
        rows = conn.execute("""
            SELECT mizo, english, example
            FROM vocabulary
            WHERE mizo LIKE ? OR english LIKE ?
            LIMIT 10
        """, (f"%{query}%", f"%{query}%")).fetchall()

    return rows


init_db()


# ---------- CHAT PAGE ----------

@app.route("/")
def home():
    return render_template("index.html")


# ---------- CHAT API ----------

@app.route("/chat", methods=["POST"])
def chatbot():
    data = request.get_json(silent=True) or {}
    messages = data.get("messages", [])

    if not isinstance(messages, list):
        return jsonify({"error": "Messages must be a list."}), 400

    # Keep only valid text messages.
    messages = [
        message for message in messages
        if isinstance(message, dict)
        and message.get("role") in ("user", "assistant")
        and isinstance(message.get("content"), str)
    ]

    if not messages or messages[-1]["role"] != "user":
        return jsonify({"error": "A user message is required."}), 400

    user_text = messages[-1]["content"].strip()

    # ---------- CONFIRMATION ----------
    # The browser sends pending_word back when the user answers the save prompt.
    pending = data.get("pending_word")

    if isinstance(pending, dict):
        answer = re.sub(r"\\s+", " ", user_text.lower().strip())

        yes_answers = {
            "yes", "yes save it", "yes, save it", "save it", "confirm",
            "yes please", "please save it"
        }
        no_answers = {
            "no", "no cancel", "no, cancel", "cancel",
            "don't save", "do not save", "don't save it", "do not save it"
        }

        if answer in yes_answers:
            mizo = str(pending.get("mizo", "")).strip()
            english = str(pending.get("english", "")).strip()
            example = str(pending.get("example", "")).strip()

            if mizo and english:
                save_word(mizo, english, example)
                return jsonify({
                  "reply": (
                        "I've saved this vocabulary entry.\n\n"
                        f"Mizo: {mizo}\n"
                        f"English: {english}\n"
                        ),  

                    "pending_word": None
                })

        if answer in no_answers:
            return jsonify({
                "reply": "Okay, I haven't saved the word.",
                "pending_word": None
            })

        # Keep the pending word if the user did not answer yes or no.
        return jsonify({
            "reply": (
                    "Would you like me to save this vocabulary entry?\n\n"
f"Mizo: {mizo}\n"
f"English: {english}\n\n"
"Reply 'yes, save it' or 'no, cancel'."
),

            "pending_word": pending
        })

    # ---------- TEACHING DETECTION ----------
    # Accept both "Teach Chhana: Mizo = English" and "Mizo = English".
    match = re.match(
        r"^\s*(?:(?:teach Chhana|teach me|remember)\s*:\s*)?"
        r"(.+?)\s*(?:=|\bmeans\b)\s*(.+?)\s*$",
        user_text,
        flags=re.IGNORECASE
    )

    if match:
        mizo = match.group(1).strip()
        english = match.group(2).strip()

        # Avoid treating empty or extremely long messages as vocabulary entries.
        if mizo and english and len(mizo) <= 100 and len(english) <= 200:
            pending_word = {
                "mizo": mizo,
                "english": english,
                "example": ""
            }
            return jsonify({
                "reply": (
                    "Would you like me to save this vocabulary entry?\n\n"
                    f"Mizo: {mizo}\n"
                    f"English: {english}\n\n"
                    "Reply 'yes, save it' or 'no, cancel'."
                ),
                "pending_word": pending_word
            })

    # ---------- RETRIEVE SAVED VOCABULARY ----------

    # Search for relevant saved entries using words from the question.
    vocabulary = []
    words = re.findall(r"[\w'-]+", user_text)

    for word in words:
        if len(word) >= 3:
            vocabulary.extend(search_words(word))

    # Remove duplicate entries.
    vocabulary = list(dict.fromkeys(vocabulary))[:10]

    memory_text = "\n".join(
        f"Mizo: {mizo} | English: {english}"
        + (f" | Example: {example}" if example else "")
        for mizo, english, example in vocabulary
    )

    system_message = {
        "role": "system",
        "content": (
    "You are Chhana, a friendly AI assistant. "
    "Support English and Mizo, the language spoken in Mizoram, India. "
    "Reply in English when the user writes in English. "
    "Reply in Mizo when the user writes in Mizo. "
    "Use Latin letters when writing Mizo. "
    "Do not use Telugu, Hindi, or other languages unless the user "
    "specifically requests them. "
    "Be honest when unsure about Mizo translations. "
    "Use the saved vocabulary below as reference when relevant. "
    "Do not invent meanings for saved words.\n\n"
    "If a user asks for the meaning of a word already in the saved "
    "vocabulary, answer using the saved meaning and do not ask to save it again. "
    "Only ask to save vocabulary when the user explicitly teaches you a new entry. "
    "Do not ask to save a word merely because you explained its meaning.\n\n"
    "SAVED MIZO-ENGLISH VOCABULARY:\n"
    + (memory_text if memory_text else "No relevant saved entries.")


        )
    }

    try:
        response = chat(
            model=MODEL,
            messages=[system_message, *messages[-20:]]
        )

        return jsonify({
            "reply": response.message.content,
            "pending_word": None
        })

    except Exception:
        app.logger.exception("Chat request failed")
        return jsonify({
            "error": "Chhana couldn't respond. Check that Ollama is running."
        }), 500


if __name__ == "__main__":
    app.run(debug=True)