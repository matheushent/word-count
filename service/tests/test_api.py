import pytest

from app.main import count_words


@pytest.mark.parametrize("file_contents,expected_word_count", [
    ("", 0),
    ("test", 1),
    ("word1 word2 word3", 3)
])
def test_count_words(file_contents, expected_word_count):
    assert count_words(file_contents) == expected_word_count
