# ZHITI

An offline-first quiz practice and learning analytics app. Import a question bank you are authorized to use, practice locally, and review mistakes and reports.

Open `index.html` in a modern browser. Core practice needs no account, server, dependencies, or network connection. The public version contains 300 single-choice questions and 300 true/false practice questions; answer keys follow the maintainer-provided sources and are not official examination material. Study data and imported banks stay in the current browser's local storage; there is no cloud sync.

Features include multiple-choice, true/false, and multiple-answer practice; sequential or randomized sessions; topic practice; mistakes, bookmarks, notes, reports; local JSON import and backup. Correct answers advance automatically after about 0.45 seconds by default; incorrect answers remain visible for review. Mock exams reveal answers only after submission.

An optional AI coach explains the first incorrect attempt, caches the explanation locally, and supports follow-up questions. Users supply their own OpenAI, DeepSeek, Qwen, or compatible API key and pay their provider directly. The key stays in page memory by default, with optional storage for the current browser session; it is never included in study backups or sent to a ZHITI server. AI requests need a network connection, and browser access depends on the provider's CORS policy. Local browser storage is not an absolute security guarantee.

**Code:** MIT License, including commercial use. **Identity:** you may identify the original project as 知题 ZHITI, but do not suggest that a modified version is official or endorsed. User supplied question banks are not covered by the project license; users must have the necessary rights. The study backup includes imported multiple-answer questions, while single-choice and true/false banks should be kept separately. See [NOTICE](NOTICE) and the Chinese [README](README.md).

Online demo (GitHub Pages): https://jin-shanghai.github.io/zhiti-learning/

Study backups now include question-bank fingerprints for single-choice and true/false questions; export these banks separately and restore matching banks before importing study history. Older backups without fingerprints are not accepted to avoid mixing unrelated questions.

## Bundled practice questions

The public web version includes 600 theory-practice questions supplied by the project maintainer: 300 single-choice questions with provided answer explanations, and 300 true/false questions without original explanations. Answer keys are reproduced from the supplied files; they are not independently certified or official examination material.

Stable release: **v1.1.0**. [Download the GitHub Release](https://github.com/jin-shanghai/zhiti-learning/releases/latest) or [use the online demo](https://jin-shanghai.github.io/zhiti-learning/).

The MIT license applies to the application code. The included question text and answer explanations do not automatically inherit that license; verify the applicable rights before redistributing them.
