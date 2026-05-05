# DMV learning engine

This module separates official state research from question-bank readiness.

## Current production status

| State | Status | What is loaded |
| --- | --- | --- |
| UT | `questions_ready` | Official DLD handbooks, written-test rules, learning modules, and 10 Spanish practice questions. |
| CA | `content_imported` | Official DMV knowledge-test sources and learning modules. Question bank pending. |
| FL | `content_imported` | Official FLHSMV Class E exam rule: 50 questions, 40 correct / 80 percent, plus modules. Question bank pending. |
| NY | `content_imported` | Official DMV rule: 14 of 20 correct and 2 of 4 road-sign questions, plus modules. Question bank pending. |
| TX | `content_imported` | Official DPS handbook and 70 percent pass rule, plus modules. Question bank pending. |

All remaining states keep the existing `source_verified` status until their handbook and exam metadata are imported.

## Source rules

- Only official government sources may be stored as authoritative DMV sources.
- Real confidential exam packets must not be copied into the app.
- Practice questions must be derived from public official handbooks, public sample tests, or public state learning pages.
- A state can show modules before it has a simulator, but it cannot show practice questions until a verified question set exists.

## Main tables

- `dmv_handbook_versions`: official handbook or handbook portal by state/language.
- `dmv_exam_configs`: state-specific exam format, pass rule, delivery modes, and language availability.
- `dmv_learning_modules`: Spanish study modules mapped to official source pages.
- `dmv_question_sets`: versioned bank of generated practice questions.
- `dmv_questions`: individual practice questions with module, difficulty, source reference, and display order.
- `dmv_practice_attempts`: user quiz/simulation attempts.
- `dmv_practice_attempt_answers`: selected answers per attempt.

## Expansion workflow

1. Verify the state portal through USAGov or the state `.gov`/`.us` motor vehicle agency.
2. Register official handbook, practice test, and exam rule sources in `official_sources`.
3. Add handbook versions and exam config with only values confirmed by the official source.
4. Add learning modules in Spanish.
5. Generate practice questions from public handbook/sample material and mark the state `questions_ready`.
6. Run `npm run typecheck`, `npm run lint`, `npm run build`, then verify the state in the PWA.
