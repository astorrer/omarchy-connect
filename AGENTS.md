# AGENTS.md

Instructions for AI coding agents working in this repository.

## Project

Konnectarchy is an Omarchy bar-widget plugin that pairs a phone over the KDE
Connect protocol. `Panel.qml` (and the other `.qml` files at the root) form
the UI, loaded via `manifest.json`. The Python package `connectlib/` talks to
`kdeconnectd` and provides the CLI entry point `connect.py`.

## Commands

```sh
ruff check .   # lint (config in ruff.toml, narrow ruleset)
./tests/run    # run all unit tests (Python via pytest-style asserts, plus JS tests)
```

CI (`.github/workflows/test.yml`) runs both on every push and pull request.
Run them before you finish; both must pass.

Python is 3.12, ruff is the only Python linter, and Node 20 runs the JS tests
(`tests/test_model.js`) inside `./tests/run`.

## Conventions

- Trunk-based development: single `main` branch, commits go directly to it.
- Keep `CHANGELOG.md` updated for user-facing changes.
- Bump `version` in `manifest.json` when releasing.
- Match the existing style: concise code, no speculative abstractions, no
  comments unless they earn their place.
- Do not commit secrets, and do not touch `__pycache__/` or `.ruff_cache/`.

## Scope notes

- `setup.sh` is user-facing; `uninstall` must only remove files this plugin
  wrote (see the marker comment in the file).
- Settings keys in `manifest.json` `barWidget.schema` must stay in sync with
  the QML that reads them.
