import pathlib
import re
from collections import Counter
from string import punctuation
from typing import List

import spacy

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
    return re.sub("\n", "", text)


def gather_words(doc: spacy.tokens.doc.Doc) -> List[str]:
    return [
        token.text
        for token in doc
        if not token.is_stop and not token.is_space and token.text not in punctuation
    ]


def create_document(text: str, model: str = "en_core_web_sm") -> spacy.tokens.doc.Doc:
    # requires: python -m spacy download en_core_web_sm
    return spacy.load(name=model)(text)


def gather_pos_words(pos: str, doc: spacy.tokens.doc.Doc) -> List[str]:
    return [token.text for token in doc if token.pos_ == pos]


def most_common_words(words: list, top: int) -> List[tuple[str, int]]:
    return Counter(words).most_common(top)


def printable_most_common_words(counter_word_list: List[tuple[str, int]]) -> str:
    if len(counter_word_list) > 0:
        return "\n".join([f"{item[0]} : {item[1]}" for item in counter_word_list])
    return "None detected."


def print_document_findings(text: str) -> None:

    print("")
    print(f"\n\033[4mMost common non-puncuation words:\033[0m\n")
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


for file in pathlib.Path("./research").glob("**/*.md"):
    if file.is_file():
        print(f"\n\033[1mWord findings for: {str(file)}\033[0m")
        with open(file, "r", encoding="utf-8") as readfile:
            print_document_findings(text=readfile.read())
