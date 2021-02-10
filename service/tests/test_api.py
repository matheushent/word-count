import pytest
from fastapi.testclient import TestClient

from app.main import app, count_words


client = TestClient(app)


def test_read_main():
    files = {"file": ("testfile.txt", "the data")}
    response = client.post("/wc/", files=files)
    response_data = response.json()
    assert response.status_code == 200
    assert response_data.get("word_count") == 2


def test_read_main_without_file():
    response = client.post("/wc/")
    assert response.status_code == 422


@pytest.mark.parametrize("file_contents,expected_word_count", [
    ("", 0),
    ("test", 1),
    ("word1 word2 word3", 3)
])
def test_count_words(file_contents, expected_word_count):
    assert count_words(file_contents) == expected_word_count
