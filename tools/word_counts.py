"""
Provide word counts for various documents
to enhance writer knowledge of contents.
"""
import pathlib
import re
from collections import Counter
from string import punctuation
from typing import List

import spacy
from spacy.cli import download

# download spacy model for use within this file
download("en_core_web_sm")

# https://universaldependencies.org/u/pos/
UNIVERSAL_POS = {
    "ADJ": "adjective",
    "ADP": "adposition",
    "ADV": "adverb",
    "AUX": "auxiliary",
    "CCONJ": "coordinating conjunction",
    "DET": "determiner",
    "INTJ": "interjection",
    "NOUN": "noun",
    "NUM": "numeral",
    "PART": "particle",
    "PRON": "pronoun",
    "PROPN": "proper noun",
    "PUNCT": "punctuation",
    "SCONJ": "subordinating conjunction",
    "SYM": "symbol",
    "VERB": "verb",
    "X": "other",
}


def clean_text(text: str) -> str:
    """
    Clean text of special characters, etc.

    Args:
      text: str:
        Str of text content which may need to be cleaned

    Returns:
      str:
        Cleaned text.

    """

    return re.sub("\n", "", text)


def gather_words(doc: spacy.tokens.doc.Doc) -> List[str]:
    """
    Gather words from provided document.

    Args:
      doc: spacy.tokens.doc.Doc:
        Document to find words in.

    Returns:
      List[str]:
        List of words found within the document.
    """
    return [
        token.text
        for token in doc
        if not token.is_stop and not token.is_space and token.text not in punctuation
    ]


def create_document(text: str, model: str = "en_core_web_sm") -> spacy.tokens.doc.Doc:
    """
    Create a Spacy Doc from text using a specified model.

    Args:
      text: str:
        Text to create Doc from.
      model: str:  (Default value = "en_core_web_sm"):
        Spacy str reference for model to use.

    Returns:
      Spacy Doc:
        Document created from text and model.
    """
    # requires: python -m spacy download en_core_web_sm
    return spacy.load(name=model)(text)


def gather_pos_words(pos: str, doc: spacy.tokens.doc.Doc) -> List[str]:
    """
    Gather parts of speech words.

    Args:
      pos: str:
        Part of speech to gather.
      doc: spacy.tokens.doc.Doc:
        Doc to gather the parts of speech from.

    Returns:
      List[str]:
        List of words or characters which are the specified
        part of speech from the Doc provided.
    """
    return [token.text for token in doc if token.pos_ == pos]


def most_common_words(words: list, top: int) -> List[tuple[str, int]]:
    """
    Finds the most common words from the word list provided.

    Args:
      words: list:
        List of words to count from.
      top: int:
        Sorted top result count to return.

    Returns:
      List[tuple[str, int]]:
        A list of tuples which includes word itself and count.
    """
    return Counter(words).most_common(top)


def printable_most_common_words(counter_word_list: List[tuple[str, int]]) -> str:
    """
    Printable version of most common words.

    Args:
      counter_word_list: List[tuple[str, int]]:
        List of tuples which includes the word and word count.

    Returns:
      str:
        Human-friendly word counts for readability.
    """
    if len(counter_word_list) > 0:
        return "\n".join([f"{item[0]} : {item[1]}" for item in counter_word_list])
    return "None detected."


def print_document_findings(text: str) -> None:
    """
    Prints findings from block of text

    Args:
      text: str:
        Text to extract information from.

    Returns:
      None
    """

    print("")
    print("\n\033[4mMost common non-puncuation words:\033[0m\n")
    print(
        printable_most_common_words(
            most_common_words(
                words=gather_words(doc=create_document(text=clean_text(text=text))),
                top=10,
            )
        )
    )

    for key, val in UNIVERSAL_POS.items():
        print(f"\n\033[4mMost common {val}s:\033[0m\n")
        print(
            printable_most_common_words(
                most_common_words(
                    words=gather_pos_words(
                        doc=create_document(text=clean_text(text=text)), pos=key
                    ),
                    top=10,
                )
            )
        )


# for each file within specified path, find and print findings
for file in pathlib.Path("./research").glob("**/*.md"):
    if file.is_file():
        print(f"\n\033[1mWord findings for: {str(file)}\033[0m")
        with open(file, "r", encoding="utf-8") as readfile:
            print_document_findings(text=readfile.read())
