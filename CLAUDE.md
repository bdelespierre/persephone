# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

persephone.sh — a pure Bash file encryption tool that encrypts both file contents and filenames using AES-256-CBC via OpenSSL. No dependencies beyond Bash and OpenSSL.

## Commands

```bash
make test                      # Run all tests (utils, crypt)
bash tests/test_crypt.sh       # Run crypt tests only
bash tests/test_utils.sh       # Run utility tests only
make install PREFIX=~/.local   # Install (default PREFIX=/usr/local)
make uninstall                 # Uninstall
```

To run the tool directly without installing, use `bin/crypt`.

## Architecture

**One command** (`bin/crypt`) with two library files in `lib/persephone/`.

- **`bin/crypt`** — Entry point: CLI argument parsing (`usage`, `main`), global state, and dispatch to `encrypt_item`/`decrypt_item`. Encrypts by default; `-d/--decrypt` switches to decrypt mode. Encrypt mode prompts for password confirmation (double-entry); decrypt mode prompts once.
- **`lib/persephone/crypt.sh`** — Core encryption logic: `encrypt_name`/`decrypt_name` (filename encryption via AES-256-CBC + URL-safe base64), `encrypt_file`/`decrypt_file` (file content encryption), `encrypt_item`/`decrypt_item` (recursive file/directory processing with dry-run support). These functions use globals (`$VERBOSE`, `$RECURSIVE`, `$PASSWORD`, `$DRY_RUN`) set by `main()`.
- **`lib/persephone/utils.sh`** — General utilities: colored logging (`log_info`, `log_warn`, `log_error`, `log_verbose`, `die`), `command_exists`, `file_readable`, `prompt_password` (masked input with backspace support), `warn_short_password` (warns if <8 chars), `prompt_password_confirm` (double-entry confirmation).

CLI pattern: `crypt [OPTIONS] [--] FILE...` with flags `-d` (decrypt), `-h` (help), `-v` (verbose), `-R` (recursive), `-p PASSWORD`, `-n` (dry-run).

## Testing

Tests use a custom Bash assertion framework defined inline in each test file:

- `assert_equals "expected" "actual" "message"`
- `assert_true "condition" "message"`
- `assert_exit_code expected actual "message"`

Each test file creates a temp directory, runs tests sequentially, and reports pass/fail counts. Tests cover argument validation, single/multiple file operations, recursive directory handling, dry-run mode, verbose output, password confirmation, short password warnings, special characters in filenames, and round-trip encryption/decryption verification.
