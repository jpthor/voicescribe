#!/usr/bin/env python3
"""Score one-transcription-per-line ASR output using normalized word error rate."""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path


def normalize(text: str) -> list[str]:
    text = unicodedata.normalize("NFKC", text).lower()
    text = text.replace("’", "'").replace("–", "-").replace("—", "-")
    text = re.sub(r"[^\w']+", " ", text, flags=re.UNICODE)
    return text.strip().split()


def edit_distance(reference: list[str], hypothesis: list[str]) -> int:
    previous = list(range(len(hypothesis) + 1))
    for row, reference_word in enumerate(reference, start=1):
        current = [row]
        for column, hypothesis_word in enumerate(hypothesis, start=1):
            substitution = previous[column - 1] + (reference_word != hypothesis_word)
            insertion = current[column - 1] + 1
            deletion = previous[column] + 1
            current.append(min(substitution, insertion, deletion))
        previous = current
    return previous[-1]


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reference", type=Path)
    parser.add_argument("hypothesis", type=Path)
    args = parser.parse_args()

    references = read_lines(args.reference)
    hypotheses = read_lines(args.hypothesis)
    if len(references) != len(hypotheses):
        print(
            f"Expected {len(references)} hypothesis lines, found {len(hypotheses)}.",
            file=sys.stderr,
        )
        return 2

    rows: list[tuple[int, int, int, str, str]] = []
    total_errors = 0
    total_words = 0
    exact_matches = 0

    for index, (reference, hypothesis) in enumerate(zip(references, hypotheses), start=1):
        reference_words = normalize(reference)
        hypothesis_words = normalize(hypothesis)
        errors = edit_distance(reference_words, hypothesis_words)
        total_errors += errors
        total_words += len(reference_words)
        exact_matches += errors == 0
        rows.append((errors, len(reference_words), index, reference, hypothesis))

    wer = total_errors / total_words if total_words else 0.0
    print(f"Phrases: {len(references)}")
    print(f"Exact normalized matches: {exact_matches}/{len(references)}")
    print(f"Word errors: {total_errors}/{total_words}")
    print(f"Aggregate WER: {wer:.2%}")

    print("\nHighest-error phrases:")
    for errors, words, index, reference, hypothesis in sorted(rows, reverse=True)[:10]:
        if errors == 0:
            break
        phrase_wer = errors / words if words else 0.0
        print(f"\n{index:02d}. {errors} errors / {words} words ({phrase_wer:.1%})")
        print(f"    REF: {reference}")
        print(f"    HYP: {hypothesis}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
