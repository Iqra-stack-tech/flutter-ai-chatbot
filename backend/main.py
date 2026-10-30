import os
from pathlib import Path

from dotenv import load_dotenv

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse

from openai import OpenAI

from schemas import ChatRequest, ChatResponse
from config import MODEL_CONFIG


# --------------------------------------------------
# LOAD ENVIRONMENT VARIABLES
# --------------------------------------------------

env_path = Path(__file__).with_name(".env")

load_dotenv(
    dotenv_path=env_path
)


groq_api_key = os.getenv(
    "GROQ_API_KEY"
)


if not groq_api_key:

    raise RuntimeError(
        "GROQ_API_KEY was not found. "
        "Make sure backend/.env contains your Groq API key."
    )


# --------------------------------------------------
# CREATE GROQ CLIENT
# --------------------------------------------------

client = OpenAI(
    api_key=groq_api_key,

    base_url="https://api.groq.com/openai/v1",

    timeout=60.0,

    max_retries=2,
)


# --------------------------------------------------
# CREATE FASTAPI APP
# --------------------------------------------------

app = FastAPI(
    title="Flutter AI Chat Backend",

    version="1.0.0",
)


# --------------------------------------------------
# CORS
# Needed for Flutter Web
# --------------------------------------------------

app.add_middleware(
    CORSMiddleware,

    allow_origins=["*"],

    allow_credentials=False,

    allow_methods=["*"],

    allow_headers=["*"],
)


# --------------------------------------------------
# HOME / HEALTH CHECK
# --------------------------------------------------

@app.get("/")
def home():

    return {
        "message": "AI Chat backend is running",

        "provider": "Groq",

        "model": MODEL_CONFIG.model,
    }


# --------------------------------------------------
# STREAMING CHAT
# --------------------------------------------------

@app.post("/chat/stream")
def chat_stream(
    request: ChatRequest,
):

    # ------------------------------------------
    # Build conversation context
    # ------------------------------------------

    messages = [
        {
            "role": "system",

            "content":
                MODEL_CONFIG.system_instruction,
        }
    ]


    # Add previous conversation

    for message in request.messages:

        messages.append(
            {
                "role": message.role,

                "content": message.content,
            }
        )


    # ------------------------------------------
    # Streaming generator
    # ------------------------------------------

    def generate():

        try:

            stream = (
                client.chat.completions.create(

                    model=
                        MODEL_CONFIG.model,

                    messages=
                        messages,

                    temperature=
                        MODEL_CONFIG.temperature,

                    max_tokens=
                        MODEL_CONFIG.max_tokens,

                    stream=True,
                )
            )


            # ----------------------------------
            # Receive chunks from Groq
            # ----------------------------------

            for chunk in stream:

                content = (
                    chunk
                    .choices[0]
                    .delta
                    .content
                )


                if content:

                    yield content


        except Exception as error:

            print(
                "Streaming error:"
            )

            print(error)


            yield (
                "\n\n"
                "[Failed to generate response]"
            )


    # ------------------------------------------
    # Stream response to Flutter
    # ------------------------------------------

    return StreamingResponse(
        generate(),

        media_type="text/plain",

        headers={
            "Cache-Control": "no-cache",
        },
    )


# --------------------------------------------------
# NORMAL CHAT
# --------------------------------------------------

@app.post(
    "/chat",
    response_model=ChatResponse,
)
def chat(
    request: ChatRequest,
):

    try:

        # ------------------------------------------
        # System instruction
        # ------------------------------------------

        messages = [
            {
                "role": "system",

                "content":
                    MODEL_CONFIG.system_instruction,
            }
        ]


        # ------------------------------------------
        # Add conversation history
        # ------------------------------------------

        for message in request.messages:

            messages.append(
                {
                    "role":
                        message.role,

                    "content":
                        message.content,
                }
            )


        # ------------------------------------------
        # Call Groq
        # ------------------------------------------

        response = (
            client.chat.completions.create(

                model=
                    MODEL_CONFIG.model,

                messages=
                    messages,

                temperature=
                    MODEL_CONFIG.temperature,

                max_tokens=
                    MODEL_CONFIG.max_tokens,
            )
        )


        # ------------------------------------------
        # Get answer
        # ------------------------------------------

        answer = (
            response
            .choices[0]
            .message
            .content
        )


        # ------------------------------------------
        # Empty response check
        # ------------------------------------------

        if not answer:

            raise HTTPException(
                status_code=502,

                detail=(
                    "The AI provider returned "
                    "an empty response."
                ),
            )


        # ------------------------------------------
        # Return answer
        # ------------------------------------------

        return ChatResponse(
            answer=answer
        )


    except HTTPException:

        raise


    except Exception as error:

        print(
            "Groq API error:"
        )

        print(error)


        raise HTTPException(
            status_code=500,

            detail=(
                "Failed to generate AI response."
            ),
        )