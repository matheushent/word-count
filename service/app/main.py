from fastapi import FastAPI, File, UploadFile
from pydantic import BaseModel


app = FastAPI()


class WordCounter(BaseModel):
    word_count: int


def count_words(file_contents: str):
    return len(file_contents.split())


@app.post("/wc/", response_model=WordCounter)
async def word_count(file: UploadFile = File(...)):
    contents = await file.read()
    word_count = count_words(contents)
    return {"word_count": word_count}
