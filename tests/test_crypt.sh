#!/usr/bin/env bash
#
# test_crypt.sh - Tests for crypt script (encrypt and decrypt modes)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CRYPT="$PROJECT_ROOT/bin/crypt"

source "$PROJECT_ROOT/lib/persephone/utils.sh"

# Test counter
tests_passed=0
tests_failed=0

# Temporary directory for test files
TEST_DIR=""

setup() {
    TEST_DIR="$(mktemp -d)"
}

teardown() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        ((tests_passed++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((tests_failed++)) || true
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-}"

    if eval "$condition"; then
        ((tests_passed++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((tests_failed++)) || true
        echo -e "${RED}FAIL${NC}: $message"
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        ((tests_passed++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((tests_failed++)) || true
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected exit code: $expected"
        echo "  Actual exit code:   $actual"
    fi
}

# Find an encrypted file in a directory (returns the first one found)
find_encrypted_file() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type f | head -1
}

# Find an encrypted directory in a directory (returns the first one found)
find_encrypted_dir() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type d ! -path "$dir" | head -1
}

# ============================================================
# Encrypt mode tests
# ============================================================

# Test: Help option (-h)
test_help_short() {
    local output
    output="$("$CRYPT" -h 2>&1)" || true
    assert_true "[[ \"\$output\" == *'Usage:'* ]]" "-h shows usage"
    assert_true "[[ \"\$output\" == *'--help'* ]]" "-h shows --help option"
    assert_true "[[ \"\$output\" == *'--verbose'* ]]" "-h shows --verbose option"
    assert_true "[[ \"\$output\" == *'--password'* ]]" "-h shows --password option"
    assert_true "[[ \"\$output\" == *'--recursive'* ]]" "-h shows --recursive option"
    assert_true "[[ \"\$output\" == *'--decrypt'* ]]" "-h shows --decrypt option"
}

# Test: Help option (--help)
test_help_long() {
    local output
    output="$("$CRYPT" --help 2>&1)" || true
    assert_true "[[ \"\$output\" == *'Usage:'* ]]" "--help shows usage"
}

# Test: No arguments shows error
test_no_arguments() {
    local exit_code=0
    "$CRYPT" 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "No arguments returns exit code 1"
}

# Test: Invalid option
test_invalid_option() {
    local exit_code=0
    "$CRYPT" -z 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "Invalid option returns exit code 1"
}

# Test: Encrypt a regular file
test_encrypt_file() {
    setup
    local testfile="$TEST_DIR/testfile.txt"
    local original_content="test content"
    echo "$original_content" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    assert_true "[[ ! -e \"$testfile\" ]]" "Original file should not exist"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Encrypted file should exist"

    # Verify file is encrypted with AES-256 (openssl salt marker: "U2FsdGVk" = "Salted__" in base64)
    local concealed_content
    concealed_content="$(cat "$hidden_file")"
    assert_true "[[ \"\$concealed_content\" != \"\$original_content\" ]]" "Encrypted file should be encrypted"
    assert_true "[[ \"\$concealed_content\" == U2FsdGVk* ]]" "Encrypted file should use AES-256 encryption (Salted__ header)"
    teardown
}

# Test: Encrypt a directory
test_encrypt_directory() {
    setup
    local testdir="$TEST_DIR/testdir"
    mkdir "$testdir"

    "$CRYPT" --password=testpassword "$testdir" >/dev/null 2>&1

    assert_true "[[ ! -e \"$testdir\" ]]" "Original directory should not exist"

    local hidden_dir
    hidden_dir="$(find_encrypted_dir "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_dir\" && -d \"$hidden_dir\" ]]" "Encrypted directory should exist"
    teardown
}

# Test: Encrypt multiple items
test_encrypt_multiple() {
    setup
    local file1="$TEST_DIR/file1.txt"
    local file2="$TEST_DIR/file2.txt"
    local content1="content1"
    local content2="content2"
    echo "$content1" > "$file1"
    echo "$content2" > "$file2"

    "$CRYPT" --password=testpassword "$file1" "$file2" >/dev/null 2>&1

    # Count encrypted files
    local encrypted_count
    encrypted_count=$(find "$TEST_DIR" -maxdepth 1 -type f | wc -l)
    assert_true "[[ $encrypted_count -eq 2 ]]" "Two encrypted files should exist"

    # Verify all files are encrypted with AES-256
    local all_encrypted=true
    while IFS= read -r encrypted_file; do
        local content
        content="$(cat "$encrypted_file")"
        if [[ "$content" != U2FsdGVk* ]]; then
            all_encrypted=false
        fi
    done < <(find "$TEST_DIR" -maxdepth 1 -type f)
    assert_true "$all_encrypted" "All files should use AES-256 encryption"
    teardown
}

# Test: Verbose output (encrypt)
test_encrypt_verbose_output() {
    setup
    local testfile="$TEST_DIR/verbosetest.txt"
    echo "test" > "$testfile"

    local output
    output="$("$CRYPT" -v --password=testpassword "$testfile" 2>&1)"

    assert_true "[[ \"\$output\" == *'Locked:'* ]]" "-v shows locked message"
    teardown
}

# Test: Verbose long option (encrypt)
test_encrypt_verbose_long() {
    setup
    local testfile="$TEST_DIR/verbosetest2.txt"
    echo "test" > "$testfile"

    local output
    output="$("$CRYPT" --verbose --password=testpassword "$testfile" 2>&1)"

    assert_true "[[ \"\$output\" == *'Locked:'* ]]" "--verbose shows locked message"
    teardown
}

# Test: Custom password option (encrypt)
test_encrypt_custom_password() {
    setup
    local testfile="$TEST_DIR/passwordtest.txt"
    local original_content="secret data"
    echo "$original_content" > "$testfile"

    local exit_code=0
    "$CRYPT" --password=mysecretpass "$testfile" >/dev/null 2>&1 || exit_code=$?

    assert_equals "0" "$exit_code" "Encrypt with --password should succeed"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Encrypted file should exist with custom password"

    # Verify file is encrypted with AES-256
    local concealed_content
    concealed_content="$(cat "$hidden_file" 2>/dev/null || echo "")"
    assert_true "[[ \"\$concealed_content\" == U2FsdGVk* ]]" "File should use AES-256 encryption with custom password"

    # Verify file can be decrypted with the correct password
    local decrypted
    decrypted="$(openssl enc -aes-256-cbc -d -pbkdf2 -base64 -pass pass:mysecretpass -in "$hidden_file" 2>/dev/null || echo "")"
    assert_equals "$original_content" "$decrypted" "File should be decryptable with custom password"
    teardown
}

# Test: Non-existent file (encrypt)
test_encrypt_nonexistent_file() {
    local exit_code=0
    "$CRYPT" "/nonexistent/file/path" 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "Non-existent file returns exit code 1"
}

# Test: Encrypt creates unique filenames (no conflict with encrypted names)
test_encrypt_no_conflict() {
    setup
    local testfile="$TEST_DIR/conflict.txt"
    echo "original" > "$testfile"

    local exit_code=0
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1 || exit_code=$?

    assert_equals "0" "$exit_code" "Encrypt should succeed"
    assert_true "[[ ! -f \"$testfile\" ]]" "Original file should not exist"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Encrypted file should exist"
    teardown
}

# Test: Using -- to separate options from arguments (encrypt)
test_encrypt_double_dash_separator() {
    setup
    local dashfile="$TEST_DIR/-file-with-dash.txt"
    echo "test" > "$dashfile"

    "$CRYPT" --password=testpassword -- "$dashfile" >/dev/null 2>&1

    assert_true "[[ ! -e \"$dashfile\" ]]" "Original file should not exist"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Encrypted file should exist"
    teardown
}

# Test: File with spaces in name (encrypt)
test_encrypt_file_with_spaces() {
    setup
    local spacefile="$TEST_DIR/file with spaces.txt"
    echo "test" > "$spacefile"

    "$CRYPT" --password=testpassword "$spacefile" >/dev/null 2>&1

    assert_true "[[ ! -e \"$spacefile\" ]]" "Original file should not exist"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Encrypted file should exist"
    teardown
}

# Test: Mixed success and failure (encrypt)
test_encrypt_mixed_results() {
    setup
    local goodfile="$TEST_DIR/good.txt"
    echo "good" > "$goodfile"

    local exit_code=0
    "$CRYPT" --password=testpassword "$goodfile" "/nonexistent" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Mixed results returns exit code 1"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Good file should be encrypted"
    teardown
}

# Test: Recursive encrypt of directory with contents
test_encrypt_recursive() {
    setup
    local testdir="$TEST_DIR/mydir"
    mkdir -p "$testdir/subdir"
    echo "file1 content" > "$testdir/file1.txt"
    echo "file2 content" > "$testdir/subdir/file2.txt"

    "$CRYPT" --password=testpassword -R "$testdir" >/dev/null 2>&1

    assert_true "[[ ! -e \"$testdir\" ]]" "Original directory should not exist"

    # Find the hidden directory
    local hidden_dir
    hidden_dir="$(find_encrypted_dir "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_dir\" && -d \"$hidden_dir\" ]]" "Encrypted directory should exist"

    # Check that contents are also concealed (subdirectory should be encrypted)
    local encrypted_subdir
    encrypted_subdir="$(find "$hidden_dir" -maxdepth 1 -type d ! -path "$hidden_dir" | head -1)"
    assert_true "[[ -n \"$encrypted_subdir\" && -d \"$encrypted_subdir\" ]]" "Encrypted subdirectory should exist"

    # Check that files inside are encrypted
    local encrypted_file1
    encrypted_file1="$(find "$hidden_dir" -maxdepth 1 -type f | head -1)"
    assert_true "[[ -n \"$encrypted_file1\" && -f \"$encrypted_file1\" ]]" "Encrypted file in directory should exist"

    local file1_content
    file1_content="$(cat "$encrypted_file1")"
    assert_true "[[ \"\$file1_content\" == U2FsdGVk* ]]" "File in directory should be encrypted"
    teardown
}

# Test: Recursive encrypt with verbose
test_encrypt_recursive_verbose() {
    setup
    local testdir="$TEST_DIR/verbosedir"
    mkdir "$testdir"
    echo "content" > "$testdir/innerfile.txt"

    local output
    output="$("$CRYPT" --password=testpassword -R -v "$testdir" 2>&1)"

    assert_true "[[ \"\$output\" == *'Locked:'* ]]" "-R -v shows locked messages"
    assert_true "[[ \"\$output\" == *'Encoded:'* ]]" "-R -v shows encoded messages for files"
    teardown
}

# Test: Dry-run mode does not modify files (encrypt)
test_encrypt_dry_run() {
    setup
    local testfile="$TEST_DIR/dryrun.txt"
    local original_content="dry run content"
    echo "$original_content" > "$testfile"

    local output
    output="$("$CRYPT" --password=testpassword -n "$testfile" 2>&1)"

    assert_true "[[ -f \"$testfile\" ]]" "Original file should still exist after dry-run"
    assert_true "[[ \"\$output\" == *'Would lock:'* ]]" "Dry-run shows 'Would lock:' message"

    # Verify content unchanged
    local content
    content="$(cat "$testfile")"
    assert_equals "$original_content" "$content" "File content should be unchanged after dry-run"
    teardown
}

# Test: Dry-run with recursive (encrypt)
test_encrypt_dry_run_recursive() {
    setup
    local testdir="$TEST_DIR/dryrundir"
    mkdir -p "$testdir/subdir"
    echo "file1" > "$testdir/file1.txt"
    echo "file2" > "$testdir/subdir/file2.txt"

    local output
    output="$("$CRYPT" --password=testpassword -n -R "$testdir" 2>&1)"

    assert_true "[[ -d \"$testdir\" ]]" "Directory should still exist after dry-run"
    assert_true "[[ -f \"$testdir/file1.txt\" ]]" "File1 should still exist after dry-run"
    assert_true "[[ -f \"$testdir/subdir/file2.txt\" ]]" "File2 should still exist after dry-run"
    assert_true "[[ \"\$output\" == *'Would lock:'* ]]" "Dry-run shows 'Would lock:' messages"
    teardown
}

# Test: Short password warning (encrypt, using -p flag which bypasses confirmation)
test_encrypt_short_password_warning() {
    setup
    local testfile="$TEST_DIR/shortpw.txt"
    echo "test" > "$testfile"

    # Short password should trigger warning, but we auto-answer N so it aborts
    local exit_code=0
    echo "n" | "$CRYPT" -p "abc" "$testfile" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Short password with 'n' response should abort"
    assert_true "[[ -f \"$testfile\" ]]" "File should still exist after abort"
    teardown
}

# Test: Short password accepted with 'y' (encrypt)
test_encrypt_short_password_accepted() {
    setup
    local testfile="$TEST_DIR/shortpw2.txt"
    echo "test" > "$testfile"

    # Short password with 'y' should proceed
    local exit_code=0
    echo "y" | "$CRYPT" -p "abc" "$testfile" >/dev/null 2>&1 || exit_code=$?

    assert_equals "0" "$exit_code" "Short password with 'y' response should succeed"
    assert_true "[[ ! -f \"$testfile\" ]]" "Original file should be encrypted"
    teardown
}

# ============================================================
# Decrypt mode tests
# ============================================================

# Test: No arguments shows error (decrypt)
test_decrypt_no_arguments() {
    local exit_code=0
    "$CRYPT" -d 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "No arguments returns exit code 1 (decrypt)"
}

# Test: Invalid option (decrypt)
test_decrypt_invalid_option() {
    local exit_code=0
    "$CRYPT" -d -z 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "Invalid option returns exit code 1 (decrypt)"
}

# Test: Decrypt an encrypted file (round-trip test)
test_decrypt_file() {
    setup
    local testfile="$TEST_DIR/testfile.txt"
    local original_content="test content"
    echo "$original_content" > "$testfile"

    # Encrypt the file first
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    # Decrypt it
    "$CRYPT" -d --password=testpassword "$encrypted_file" >/dev/null 2>&1

    assert_true "[[ ! -e \"$encrypted_file\" ]]" "Encrypted file should not exist"
    assert_true "[[ -f \"$TEST_DIR/testfile.txt\" ]]" "Decrypted file should exist"

    # Verify file is decrypted (content should match original)
    local revealed_content
    revealed_content="$(cat "$TEST_DIR/testfile.txt")"
    assert_equals "$original_content" "$revealed_content" "Decrypted file should match original content"
    teardown
}

# Test: Decrypt an encrypted directory (round-trip test)
test_decrypt_directory() {
    setup
    local testdir="$TEST_DIR/testdir"
    mkdir "$testdir"

    # Encrypt the directory first
    "$CRYPT" --password=testpassword "$testdir" >/dev/null 2>&1

    # Find the hidden directory
    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    # Decrypt it
    "$CRYPT" -d --password=testpassword "$encrypted_dir" >/dev/null 2>&1

    assert_true "[[ ! -e \"$encrypted_dir\" ]]" "Encrypted directory should not exist"
    assert_true "[[ -d \"$TEST_DIR/testdir\" ]]" "Decrypted directory should exist"
    teardown
}

# Test: Decrypt multiple items (round-trip test)
test_decrypt_multiple() {
    setup
    local file1="$TEST_DIR/file1.txt"
    local file2="$TEST_DIR/file2.txt"
    local content1="content1"
    local content2="content2"
    echo "$content1" > "$file1"
    echo "$content2" > "$file2"

    # Encrypt both files
    "$CRYPT" --password=testpassword "$file1" "$file2" >/dev/null 2>&1

    # Find encrypted files and decrypt them
    local encrypted_files
    encrypted_files=$(find "$TEST_DIR" -maxdepth 1 -type f)
    for ef in $encrypted_files; do
        "$CRYPT" -d --password=testpassword "$ef" >/dev/null 2>&1
    done

    assert_true "[[ -f \"$TEST_DIR/file1.txt\" ]]" "First decrypted file should exist"
    assert_true "[[ -f \"$TEST_DIR/file2.txt\" ]]" "Second decrypted file should exist"

    # Verify both files are decrypted
    local revealed1 revealed2
    revealed1="$(cat "$TEST_DIR/file1.txt")"
    revealed2="$(cat "$TEST_DIR/file2.txt")"
    assert_equals "$content1" "$revealed1" "First file should be decrypted"
    assert_equals "$content2" "$revealed2" "Second file should be decrypted"
    teardown
}

# Test: Verbose output (decrypt, round-trip test)
test_decrypt_verbose_output() {
    setup
    local testfile="$TEST_DIR/verbosetest.txt"
    echo "test" > "$testfile"

    # Encrypt the file first
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    local output
    output="$("$CRYPT" -d -v --password=testpassword "$encrypted_file" 2>&1)"

    assert_true "[[ \"\$output\" == *'Unlocked:'* ]]" "-v shows unlocked message"
    teardown
}

# Test: Verbose long option (decrypt, round-trip test)
test_decrypt_verbose_long() {
    setup
    local testfile="$TEST_DIR/verbosetest2.txt"
    echo "test" > "$testfile"

    # Encrypt the file first
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    local output
    output="$("$CRYPT" -d --verbose --password=testpassword "$encrypted_file" 2>&1)"

    assert_true "[[ \"\$output\" == *'Unlocked:'* ]]" "--verbose shows unlocked message"
    teardown
}

# Test: Custom password option (decrypt, round-trip test)
test_decrypt_custom_password() {
    setup
    local testfile="$TEST_DIR/passwordtest.txt"
    local original_content="secret data"
    echo "$original_content" > "$testfile"

    # Encrypt with custom password
    "$CRYPT" --password=mysecretpass "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    local exit_code=0
    "$CRYPT" -d --password=mysecretpass "$encrypted_file" >/dev/null 2>&1 || exit_code=$?

    assert_equals "0" "$exit_code" "Decrypt with --password should succeed"
    assert_true "[[ -f \"$TEST_DIR/passwordtest.txt\" ]]" "Decrypted file should exist with custom password"

    # Verify file is decrypted correctly
    local revealed_content
    revealed_content="$(cat "$TEST_DIR/passwordtest.txt" 2>/dev/null || echo "")"
    assert_equals "$original_content" "$revealed_content" "File should be decrypted with custom password"
    teardown
}

# Test: Non-existent file (decrypt)
test_decrypt_nonexistent_file() {
    local exit_code=0
    "$CRYPT" -d "/nonexistent/file/path" 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "Non-existent file returns exit code 1 (decrypt)"
}

# Test: Target already exists (decrypt, round-trip test)
test_decrypt_target_exists() {
    setup
    local testfile="$TEST_DIR/conflict.txt"
    echo "original" > "$testfile"

    # Encrypt the file
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    # Create a file with the original name (conflict)
    echo "existing" > "$TEST_DIR/conflict.txt"

    local exit_code=0
    "$CRYPT" -d --password=testpassword "$encrypted_file" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Target exists returns exit code 1"
    assert_true "[[ -f \"$encrypted_file\" ]]" "Encrypted file should still exist"
    teardown
}

# Test: Using -- to separate options from arguments (decrypt, round-trip test)
test_decrypt_double_dash_separator() {
    setup
    local testfile="$TEST_DIR/hidden-file.txt"
    echo "test" > "$testfile"

    # Encrypt the file
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    "$CRYPT" -d --password=testpassword -- "$encrypted_file" >/dev/null 2>&1

    assert_true "[[ ! -e \"$encrypted_file\" ]]" "Encrypted file should not exist"
    assert_true "[[ -f \"$TEST_DIR/hidden-file.txt\" ]]" "Decrypted file should exist"
    teardown
}

# Test: File with spaces in name (decrypt, round-trip test)
test_decrypt_file_with_spaces() {
    setup
    local testfile="$TEST_DIR/file with spaces.txt"
    echo "test" > "$testfile"

    # Encrypt the file
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    "$CRYPT" -d --password=testpassword "$encrypted_file" >/dev/null 2>&1

    assert_true "[[ ! -e \"$encrypted_file\" ]]" "Encrypted file should not exist"
    assert_true "[[ -f \"$TEST_DIR/file with spaces.txt\" ]]" "Decrypted file should exist"
    teardown
}

# Test: Mixed success and failure (decrypt, round-trip test)
test_decrypt_mixed_results() {
    setup
    local testfile="$TEST_DIR/good.txt"
    echo "good" > "$testfile"

    # Encrypt the file
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    local exit_code=0
    "$CRYPT" -d --password=testpassword "$encrypted_file" "/nonexistent" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Mixed results returns exit code 1"
    assert_true "[[ -f \"$TEST_DIR/good.txt\" ]]" "Good file should be decrypted"
    teardown
}

# Test: Recursive decrypt of directory with contents (round-trip test)
test_decrypt_recursive() {
    setup
    local testdir="$TEST_DIR/mydir"
    mkdir -p "$testdir/subdir"
    echo "file1 content" > "$testdir/file1.txt"
    echo "file2 content" > "$testdir/subdir/file2.txt"

    # Encrypt recursively
    "$CRYPT" --password=testpassword -R "$testdir" >/dev/null 2>&1

    # Find the hidden directory
    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    # Decrypt recursively
    "$CRYPT" -d --password=testpassword -R "$encrypted_dir" >/dev/null 2>&1

    assert_true "[[ ! -e \"$encrypted_dir\" ]]" "Encrypted directory should not exist"
    assert_true "[[ -d \"$TEST_DIR/mydir\" ]]" "Original directory should be restored"
    assert_true "[[ -d \"$TEST_DIR/mydir/subdir\" ]]" "Subdirectory should be restored"
    assert_true "[[ -f \"$TEST_DIR/mydir/file1.txt\" ]]" "File1 should be restored"
    assert_true "[[ -f \"$TEST_DIR/mydir/subdir/file2.txt\" ]]" "File2 should be restored"

    # Verify contents are decrypted
    local file1_content file2_content
    file1_content="$(cat "$TEST_DIR/mydir/file1.txt")"
    file2_content="$(cat "$TEST_DIR/mydir/subdir/file2.txt")"
    assert_equals "file1 content" "$file1_content" "File1 content should be restored"
    assert_equals "file2 content" "$file2_content" "File2 content should be restored"
    teardown
}

# Test: Recursive decrypt with verbose (round-trip test)
test_decrypt_recursive_verbose() {
    setup
    local testdir="$TEST_DIR/verbosedir"
    mkdir "$testdir"
    echo "content" > "$testdir/innerfile.txt"

    # Encrypt recursively
    "$CRYPT" --password=testpassword -R "$testdir" >/dev/null 2>&1

    # Find the hidden directory
    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    local output
    output="$("$CRYPT" -d --password=testpassword -R -v "$encrypted_dir" 2>&1)"

    assert_true "[[ \"\$output\" == *'Unlocked:'* ]]" "-R -v shows unlocked messages"
    assert_true "[[ \"\$output\" == *'Decoded:'* ]]" "-R -v shows decoded messages for files"
    teardown
}

# Test: Dry-run mode does not modify files (decrypt, round-trip test)
test_decrypt_dry_run() {
    setup
    local testfile="$TEST_DIR/dryrun.txt"
    echo "dry run content" > "$testfile"

    # Encrypt the file first
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the encrypted file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"
    local encrypted_content
    encrypted_content="$(cat "$encrypted_file")"

    local output
    output="$("$CRYPT" -d --password=testpassword -n "$encrypted_file" 2>&1)"

    assert_true "[[ -f \"$encrypted_file\" ]]" "Encrypted file should still exist after dry-run"
    assert_true "[[ \"\$output\" == *'Would unlock:'* ]]" "Dry-run shows 'Would unlock:' message"

    # Verify content unchanged
    local content
    content="$(cat "$encrypted_file")"
    assert_equals "$encrypted_content" "$content" "File content should be unchanged after dry-run"
    teardown
}

# Test: Dry-run with recursive (decrypt, round-trip test)
test_decrypt_dry_run_recursive() {
    setup
    local testdir="$TEST_DIR/dryrundir"
    mkdir -p "$testdir/subdir"
    echo "file1" > "$testdir/file1.txt"
    echo "file2" > "$testdir/subdir/file2.txt"

    # Encrypt recursively
    "$CRYPT" --password=testpassword -R "$testdir" >/dev/null 2>&1

    # Find the encrypted directory
    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    local output
    output="$("$CRYPT" -d --password=testpassword -n -R "$encrypted_dir" 2>&1)"

    assert_true "[[ -d \"$encrypted_dir\" ]]" "Encrypted directory should still exist after dry-run"
    assert_true "[[ \"\$output\" == *'Would unlock:'* ]]" "Dry-run shows 'Would unlock:' messages"
    teardown
}

# Test: Short password warning (decrypt)
test_decrypt_short_password_warning() {
    setup
    local testfile="$TEST_DIR/shortpw.txt"
    echo "test" > "$testfile"

    # Encrypt the file first with long password
    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the encrypted file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    # Short password should trigger warning, 'n' response aborts
    local exit_code=0
    echo "n" | "$CRYPT" -d -p "abc" "$encrypted_file" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Short password with 'n' response should abort"
    assert_true "[[ -f \"$encrypted_file\" ]]" "Encrypted file should still exist after abort"
    teardown
}

# ============================================================
# Run all tests
# ============================================================

echo "Running crypt tests..."
echo

echo "--- Encrypt mode ---"
echo
test_help_short
test_help_long
test_no_arguments
test_invalid_option
test_encrypt_file
test_encrypt_directory
test_encrypt_multiple
test_encrypt_verbose_output
test_encrypt_verbose_long
test_encrypt_custom_password
test_encrypt_nonexistent_file
test_encrypt_no_conflict
test_encrypt_double_dash_separator
test_encrypt_file_with_spaces
test_encrypt_mixed_results
test_encrypt_recursive
test_encrypt_recursive_verbose
test_encrypt_dry_run
test_encrypt_dry_run_recursive
test_encrypt_short_password_warning
test_encrypt_short_password_accepted

echo
echo "--- Decrypt mode ---"
echo
test_decrypt_no_arguments
test_decrypt_invalid_option
test_decrypt_file
test_decrypt_directory
test_decrypt_multiple
test_decrypt_verbose_output
test_decrypt_verbose_long
test_decrypt_custom_password
test_decrypt_nonexistent_file
test_decrypt_target_exists
test_decrypt_double_dash_separator
test_decrypt_file_with_spaces
test_decrypt_mixed_results
test_decrypt_recursive
test_decrypt_recursive_verbose
test_decrypt_dry_run
test_decrypt_dry_run_recursive
test_decrypt_short_password_warning

echo
echo "================================"
echo "Tests passed: $tests_passed"
echo "Tests failed: $tests_failed"
echo "================================"

[[ $tests_failed -eq 0 ]] && exit 0 || exit 1
