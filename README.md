# Flutter AI Chatbot

A full-stack AI chat application built with **Flutter**, **FastAPI**, and the **Groq LLM API**.

The project demonstrates how a frontend application can communicate securely with a Python backend, send conversation history to a hosted Large Language Model, stream responses back to the client, and preserve chat history locally.

## Features

- Flutter chat interface
- FastAPI Python backend
- Groq hosted LLM integration
- Streaming AI responses
- Multi-message conversation history
- Context-aware responses
- Local conversation persistence with `shared_preferences`
- Structured request and response validation with Pydantic
- Centralized model configuration
- Backend-only API key storage
- Basic retry, timeout, and error handling
- CORS support for Flutter Web

## Architecture

```text
Flutter Application
        |
        | HTTP / Streaming Request
        v
FastAPI Backend
        |
        | Conversation History
        | System Instructions
        | Model Configuration
        v
Groq API
        |
        v
Hosted LLM
        |
        | Streaming Response
        v
FastAPI
        |
        v
Flutter Chat UI
```

The Groq API key exists only in the Python backend.

```text
Flutter
   X
API Key

Backend
   ✓
API Key
```

## Project Structure

```text
phase3_flutter_ai_chat/
│
├── .gitignore
├── README.md
│
├── backend/
│   ├── main.py
│   ├── schemas.py
│   ├── config.py
│   ├── .env.example
│   └── .env
│
└── flutter_app/
    ├── lib/
    │   └── main.dart
    ├── android/
    ├── web/
    └── pubspec.yaml
```

> `.env` contains the real API key and must never be committed to GitHub.

## Backend

The backend is built using **FastAPI**.

It is responsible for:

- Receiving messages from Flutter
- Validating incoming data
- Managing conversation context
- Calling the Groq API
- Keeping the LLM API key secret
- Streaming generated text back to Flutter
- Handling provider errors and timeouts

### API Endpoints

#### Health Check

```http
GET /
```

Example response:

```json
{
  "message": "AI Chat backend is running",
  "provider": "Groq"
}
```

#### Normal Chat

```http
POST /chat
```

Receives conversation history and returns the complete AI response.

#### Streaming Chat

```http
POST /chat/stream
```

Streams the generated response incrementally to the Flutter client.

## Request Format

Example:

```json
{
  "messages": [
    {
      "role": "user",
      "content": "My name is Sara."
    },
    {
      "role": "assistant",
      "content": "Nice to meet you, Sara."
    },
    {
      "role": "user",
      "content": "What is my name?"
    }
  ]
}
```

## Conversation Context

The complete conversation history is sent to the backend.

The backend adds the configured system instruction and forwards the conversation to the hosted LLM.

```text
System Instruction
        +
Previous Messages
        +
Latest User Message
        |
        v
Hosted LLM
```

This allows follow-up questions such as:

```text
User:
My name is Sara.

User:
What is my name?

Assistant:
Your name is Sara.
```

## Conversation Persistence

The Flutter application stores messages locally using:

```text
shared_preferences
```

This allows the conversation to survive browser refreshes or application restarts.

Current persistence is client-side only.

A production version would normally store users and conversations in a backend database such as PostgreSQL.

## Streaming

Instead of waiting for the complete response:

```text
Request
   |
   | wait...
   |
Complete response
```

the application receives text while the model is generating it:

```text
Request
   |
   v
"Artificial"
   |
   v
" intelligence"
   |
   v
" is"
   |
   v
"..."
```

The Flutter assistant message bubble updates while chunks arrive.

## Model Configuration

Model behavior is configured centrally in:

```text
backend/config.py
```

Example configuration:

```python
MODEL_CONFIG = ModelConfig(
    model="openai/gpt-oss-20b",
    temperature=0.7,
    max_tokens=500,
    system_instruction=(
        "You are a helpful AI assistant. "
        "Answer clearly and concisely. "
        "Use previous conversation when relevant."
    ),
)
```

This keeps model-related settings separate from API route logic.

## Setup

### 1. Clone Repository

```bash
git clone <your-repository-url>
cd flutter-ai-chatbot
```

### 2. Create Python Virtual Environment

Example on Windows:

```powershell
python -m venv myenv
```

Activate it:

```powershell
.\myenv\Scripts\Activate.ps1
```

### 3. Install Backend Dependencies

```powershell
pip install fastapi uvicorn openai python-dotenv pydantic
```

### 4. Configure Groq API Key

Inside:

```text
backend/
```

copy:

```text
.env.example
```

to:

```text
.env
```

Then add your real key:

```env
GROQ_API_KEY=your_groq_api_key_here
```

Never commit `.env`.

### 5. Run Backend

```powershell
cd backend
python -m uvicorn main:app --reload
```

Backend:

```text
http://127.0.0.1:8000
```

Swagger documentation:

```text
http://127.0.0.1:8000/docs
```

## Flutter Setup

Move into the Flutter application:

```powershell
cd flutter_app
```

Install dependencies:

```powershell
flutter pub get
```

Run:

```powershell
flutter run
```

For Flutter Web or Windows running on the same computer, the backend URL is:

```text
http://127.0.0.1:8000
```

For an Android emulator:

```text
http://10.0.2.2:8000
```

For a physical Android device, use the local network IP address of the computer running FastAPI.

## Security

The LLM API key is stored only in:

```text
backend/.env
```

The Flutter application never receives the API key.

```text
Flutter
   |
   v
FastAPI
   |
   v
Groq API
```

This prevents secret credentials from being exposed inside a mobile or web client.

## Technologies

### Frontend

- Flutter
- Dart
- `http`
- `shared_preferences`

### Backend

- Python
- FastAPI
- Pydantic
- Uvicorn
- python-dotenv

### AI

- Groq API
- Hosted Large Language Model
- OpenAI-compatible API interface

## What I Learned

This project helped me understand:

- How hosted LLM APIs work
- System instructions vs user messages
- Conversation context
- Token and context considerations
- Prompt configuration
- Streaming responses
- Frontend/backend separation
- API key security
- Pydantic validation
- FastAPI endpoints
- Flutter HTTP communication
- Conversation history
- Local persistence
- LLM configuration
- Timeout and retry handling

## Known Limitations

- Conversation persistence currently uses local Flutter storage instead of a backend database.
- There is no authentication or user-account system.
- Long conversations may eventually consume too much model context.
- Markdown returned by the LLM is currently displayed as plain text unless Markdown rendering is added.
- The backend is configured primarily for local development.
- Production deployment should use HTTPS and stricter CORS settings.
- There is not yet a full automated evaluation suite for AI response quality.

## Possible Future Improvements

- PostgreSQL conversation storage
- User authentication
- Multiple conversations
- Markdown rendering
- Conversation titles
- Better streaming error recovery
- Token usage and cost dashboard
- Prompt evaluation tests
- Model selection
- File/image input
- Tool calling
- RAG/document chat
- Production deployment
- Docker support

## Phase 3 Goal

This project demonstrates using a hosted LLM as a software component rather than only as a chat endpoint.

The application separates responsibilities clearly:

```text
Flutter
→ user interface

FastAPI
→ application/backend logic

Groq
→ hosted LLM inference

Local storage
→ conversation persistence
```

Most importantly, secret API credentials remain on the backend and model output is handled through structured application logic.