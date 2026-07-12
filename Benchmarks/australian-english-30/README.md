# Australian English dictation benchmark

This 30-phrase set is designed for short push-to-talk dictation on an Australian English speaker. It covers ordinary prose, Australian expressions and place names, dates and numbers, technical vocabulary, proper nouns, similar-sounding numbers, and longer spontaneous-style sentences.

## Record a run

1. Quit other dictation tools so only the model being tested handles the trigger key.
2. Open `hypotheses.txt` in a plain-text editor with one result per line.
3. Read `phrases.txt` naturally. Do not imitate a newsreader or over-enunciate.
4. Use one trigger-key recording per phrase. Pause briefly before releasing the key.
5. After each transcription appears, press Return once to move to the next line. Do not correct errors.
6. Keep the room, microphone, speaking distance, and input level the same for every model.
7. Save the output under a model-specific name, such as `parakeet-unified-run-1.txt`.

Do at least two runs per model. Alternating models between runs reduces the effect of becoming more familiar with the phrases.

## Score a run

From the repository root:

```sh
python3 Benchmarks/australian-english-30/score.py \
  Benchmarks/australian-english-30/phrases.txt \
  Benchmarks/australian-english-30/parakeet-unified-run-1.txt
```

The scorer lowercases text and ignores punctuation. It reports aggregate word error rate, exact normalized matches, and the phrases with the most errors.

Dates, currency, phone numbers, initialisms, and commands need manual review as well. A recognizer may produce `3:45 PM` instead of `three forty-five p.m.` or `git status` instead of `Git status`; those can be functionally correct even when the word-error score penalizes the formatting.

## Decision rule

Use the lowest median word error rate across two runs, provided:

- no names, numbers, negations, or commands are changed in a dangerous way;
- typical short phrases appear quickly enough to feel immediate;
- long phrases do not lose their beginning or repeat text at the 15-second window boundary.

For replacing a daily dictation subscription, errors on names, numbers, and negations matter more than tiny differences in aggregate word error rate.

## Smoke-test an audio file directly

The repository also includes a small command-line harness that uses the exact same Parakeet Unified batch manager as the app:

```sh
swift run -c release parakeet-smoke /path/to/recording.wav
```

Its first run downloads and compiles the pinned INT8 Core ML model. Later runs reuse the local cache.
