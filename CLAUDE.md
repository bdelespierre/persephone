# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

persephone.sh — a pure Bash file encryption tool that encrypts both file contents and filenames using AES-256-CBC via OpenSSL. No dependencies beyond Bash and OpenSSL.

## Commands

```bash
make test                      # Run all tests (utils, lock, unlock)
bash tests/test_lock.sh        # Run lock tests only
bash tests/test_unlock.sh      # Run unlock tests only
bash tests/test_utils.sh       # Run utility tests only
make install PREFIX=~/.local   # Install (default PREFIX=/usr/local)
make uninstall                 # Uninstall
```

To run the tools directly without installing, use `bin/lock` and `bin/unlock`.

## Architecture

**Two commands** (`bin/lock` and `bin/unlock`) share a utility library (`lib/persephone/utils.sh`).

- **`bin/lock`** — Encrypts files: encrypts content with `openssl enc -aes-256-cbc -salt -pbkdf2 -base64`, then renames the file to a URL-safe base64 encoding of the encrypted original filename. Supports recursive directory locking.
- **`bin/unlock`** — Reverses the process: decodes the filename, renames, then decrypts content.
- **`lib/persephone/utils.sh`** — Shared functions: colored logging (`log_info`, `log_warn`, `log_error`, `die`), `command_exists`, `file_readable`, `prompt_password` (masked input with backspace support), `warn_short_password` (warns if <8 chars), `prompt_password_confirm` (double-entry confirmation).

Both commands follow the same CLI pattern: `[OPTIONS] [--] FILE...` with flags `-h` (help), `-v` (verbose), `-R` (recursive), `-p PASSWORD`, `-n` (dry-run). Lock prompts for password confirmation; unlock does not.

## Testing

Tests use a custom Bash assertion framework defined inline in each test file:

- `assert_equals "expected" "actual" "message"`
- `assert_true "condition" "message"`
- `assert_exit_code expected actual "message"`

Each test file creates a temp directory, runs tests sequentially, and reports pass/fail counts. Tests cover argument validation, single/multiple file operations, recursive directory handling, dry-run mode, verbose output, password confirmation, short password warnings, special characters in filenames, and round-trip encryption/decryption verification.
