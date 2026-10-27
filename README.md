# ChhanAI — AI Chatbot

**ChhanAI** is an AI-powered chatbot application developed using Flutter, Python, Flask, and Google's Gemma 3 language model through Ollama.

The project aims to provide a simple, accessible conversational interface while exploring local AI inference, mobile application development, and backend integration.

## 1. Project Objectives

* Develop a mobile chatbot application using Flutter.
* Integrate a locally running language model using Ollama.
* Build a Python backend to handle communication between the mobile application and the AI model.
* Explore database integration for storing and managing chatbot-related information.
* Create a foundation for future improvements, including better Mizo-language support.

## 2. Features

* **Conversational interface:** Send messages and receive AI-generated responses.
* **AI integration:** Uses Gemma 3 through Ollama.
* **Flutter mobile application:** Provides the user interface for interacting with the chatbot.
* **Flask backend:** Processes chat requests and communicates with the AI model.
* **SQLite database:** Supports local storage of chatbot-related information.
* **Attachment interface:** Includes options for selecting images and files. Actual AI processing of attachments requires further backend integration.

## 3. Technologies Used

| Technology     | Purpose                                 |
| -------------- | --------------------------------------- |
| Flutter        | Mobile application interface            |
| Dart           | Frontend programming language           |
| Python         | Backend programming language            |
| Flask          | Backend API                             |
| Ollama         | Local AI model runtime                  |
| Gemma 3 (4B)   | Language model                          |
| SQLite         | Local database storage                  |
| Git and GitHub | Version control and source code hosting |

## 4. System Architecture

ChhanAI uses a client-server architecture.

1. **Mobile application:** The Flutter app accepts user messages.
2. **Backend API:** Flask receives chat requests from the application.
3. **AI model:** The backend communicates with Ollama, which runs Gemma 3.
4. **Response:** The generated answer is returned through Flask to the mobile application.
5. **Database:** SQLite provides local storage for supported chatbot data.

### Architecture Overview

Flutter Mobile App
↓
Flask Backend API
↓
Ollama
↓
Gemma 3 (4B)

SQLite provides local database storage alongside this workflow.

## 5. Project Structure

```text
ChhanAI/
├── android/
├── assets/
├── lib/
│   ├── main.dart
│   └── chat_api_service.dart
├── test/
├── web/
├── windows/
├── zora test/
│   ├── app.py
│   ├── requirements.txt
│   ├── static/
│   └── templates/
├── pubspec.yaml
└── README.md
```

The `lib/` directory contains the Flutter application code, while `zora test/` contains the Flask backend.

## 6. Requirements

Before running the project, install:

* Flutter SDK
* Python 3
* Ollama
* Git

The computer running the backend must have enough memory and processing resources to run the selected AI model.

## 7. Setup and Installation

### Step 1: Download the AI model

Install Ollama and download Gemma 3:

```bash
ollama pull gemma3:4b
```

Confirm that the model is available:

```bash
ollama list
```

### Step 2: Set up the backend

Open a terminal in the backend directory:

```bash
cd "zora test"
```

Create a Python virtual environment:

```bash
python -m venv .venv
```

Activate it in Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

Install the dependencies:

```bash
pip install -r requirements.txt
```

Start the backend:

```bash
python app.py
```

The Flask server should start on the configured address and port.

### Step 3: Set up the Flutter application

Open another terminal in the project root:

```bash
flutter pub get
```

Check connected devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

### Step 4: Configure the connection

The Flutter application must point to the address of the computer running Flask.

For Android devices on the same Wi-Fi network, configure the backend URL to use the computer's local network IP address and Flask port.

For example:

```text
http://192.168.1.100:5000
```

Replace this example with the actual address of your backend computer.

The Flask server and Ollama must be running for the chatbot to respond.

## 8. Current Limitations

* The current local setup depends on a computer running the Flask backend and AI model.
* Other devices need network access to the backend.
* AI response quality depends on the language model and its language capabilities.
* Image and file selection does not automatically provide AI analysis; the backend must support those operations.
* Public internet access requires additional deployment, security, and configuration work.

## 9. Future Improvements

* Improve Mizo-language response quality.
* Add secure conversation storage and management.
* Implement image and document analysis.
* Improve error handling and connection reliability.
* Deploy the backend to an appropriate server.
* Improve documentation, testing, and application security.

## 10. Project Status

ChhanAI is an ongoing development project exploring mobile application development and locally powered conversational AI.

Features and setup requirements may change as development continues.

## 11. License

A license has not yet been specified. Please check the repository for licensing information before reusing or redistributing the source code.

