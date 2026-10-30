from pydantic import BaseModel


class ModelConfig(BaseModel):

    model: str

    temperature: float

    max_tokens: int

    system_instruction: str


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