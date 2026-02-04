# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

persephone.sh — a pure Bash file encryption tool that encrypts both file contents and filenames using AES-256-CBC via OpenSSL. No dependencies beyond Bash and OpenSSL.

## Commands

```bash
make test                        # Run all tests (bats)
bats tests/                      # Run all tests directly
bats tests/test_crypt.bats       # Run crypt tests only
bats tests/test_utils.bats       # Run utility tests only
make install PREFIX=~/.local     # Install (default PREFIX=/usr/local)
make uninstall                   # Uninstall
```

To run the tool directly without installing, use `bin/crypt`.

## Architecture

**One command** (`bin/crypt`) with two library files in `lib/persephone/`.

- **`bin/crypt`** — Entry point: CLI argument parsing (`usage`, `main`), global state, and dispatch to `encrypt_item`/`decrypt_item`. Encrypts by default; `-d/--decrypt` switches to decrypt mode. Encrypt mode prompts for password confirmation (double-entry); decrypt mode prompts once.
- **`lib/persephone/crypt.sh`** — Core encryption logic: `encrypt_name`/`decrypt_name` (filename encryption via AES-256-CBC + URL-safe base64), `encrypt_file`/`decrypt_file` (file content encryption), `encrypt_item`/`decrypt_item` (recursive file/directory processing with dry-run support). These functions use globals (`$VERBOSE`, `$RECURSIVE`, `$PASSWORD`, `$DRY_RUN`) set by `main()`.
- **`lib/persephone/utils.sh`** — General utilities: colored logging (`log_info`, `log_warn`, `log_error`, `log_verbose`, `die`), `command_exists`, `file_readable`, `prompt_password` (masked input with backspace support), `warn_short_password` (warns if <8 chars), `prompt_password_confirm` (double-entry confirmation).

CLI pattern: `crypt [OPTIONS] [--] FILE...` with flags `-d` (decrypt), `-h` (help), `-v` (verbose), `-R` (recursive), `-p PASSWORD`, `-n` (dry-run).

## Testing

Tests use the [bats](https://github.com/bats-core/bats-core) framework (Bash Automated Testing System). No helper libraries required.

- **`tests/test_helper.bash`** — Shared setup: project root resolution, sources `utils.sh`, defines `find_encrypted_file()` and `find_encrypted_dir()` helpers.
- **`tests/test_utils.bats`** — Unit tests for `lib/persephone/utils.sh` functions (`command_exists`, `file_readable`, `warn_short_password`).
- **`tests/test_crypt.bats`** — Integration tests for `bin/crypt`: argument validation, single/multiple file operations, recursive directory handling, dry-run mode, verbose output, password warnings, special characters in filenames, and round-trip encryption/decryption verification.

Each crypt test creates a temporary directory in `setup()` and removes it in `teardown()`.
