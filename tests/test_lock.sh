#!/usr/bin/env bash
#
# test_lock.sh - Tests for lock script
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOCK="$PROJECT_ROOT/bin/lock"

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

# Test: Help option (-h)
test_help_short() {
    local output
    output="$("$LOCK" -h 2>&1)" || true
    assert_true "[[ \"\$output\" == *'Usage:'* ]]" "-h shows usage"
    assert_true "[[ \"\$output\" == *'--help'* ]]" "-h shows --help option"
    assert_true "[[ \"\$output\" == *'--verbose'* ]]" "-h shows --verbose option"
    assert_true "[[ \"\$output\" == *'--password'* ]]" "-h shows --password option"
    assert_true "[[ \"\$output\" == *'--recursive'* ]]" "-h shows --recursive option"
}

# Test: Help option (--help)
test_help_long() {
    local output
    output="$("$LOCK" --help 2>&1)" || true
    assert_true "[[ \"\$output\" == *'Usage:'* ]]" "--help shows usage"
}

# Test: No arguments shows error
test_no_arguments() {
    local exit_code=0
    "$LOCK" 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "No arguments returns exit code 1"
}

# Test: Invalid option
test_invalid_option() {
    local exit_code=0
    "$LOCK" -z 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "Invalid option returns exit code 1"
}

# Test: Lock a regular file
test_lock_file() {
    setup
    local testfile="$TEST_DIR/testfile.txt"
    local original_content="test content"
    echo "$original_content" > "$testfile"

    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    assert_true "[[ ! -e \"$testfile\" ]]" "Original file should not exist"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Encrypted file should exist"

    # Verify file is encrypted with AES-256 (openssl salt marker: "U2FsdGVk" = "Salted__" in base64)
    local concealed_content
    concealed_content="$(cat "$hidden_file")"
    assert_true "[[ \"\$concealed_content\" != \"\$original_content\" ]]" "Locked file should be encrypted"
    assert_true "[[ \"\$concealed_content\" == U2FsdGVk* ]]" "Locked file should use AES-256 encryption (Salted__ header)"
    teardown
}

# Test: Lock a directory
test_lock_directory() {
    setup
    local testdir="$TEST_DIR/testdir"
    mkdir "$testdir"

    "$LOCK" --password=testpassword "$testdir" >/dev/null 2>&1

    assert_true "[[ ! -e \"$testdir\" ]]" "Original directory should not exist"

    local hidden_dir
    hidden_dir="$(find_encrypted_dir "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_dir\" && -d \"$hidden_dir\" ]]" "Encrypted directory should exist"
    teardown
}

# Test: Lock multiple items
test_lock_multiple() {
    setup
    local file1="$TEST_DIR/file1.txt"
    local file2="$TEST_DIR/file2.txt"
    local content1="content1"
    local content2="content2"
    echo "$content1" > "$file1"
    echo "$content2" > "$file2"

    "$LOCK" --password=testpassword "$file1" "$file2" >/dev/null 2>&1

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

# Test: Verbose output
test_verbose_output() {
    setup
    local testfile="$TEST_DIR/verbosetest.txt"
    echo "test" > "$testfile"

    local output
    output="$("$LOCK" -v --password=testpassword "$testfile" 2>&1)"

    assert_true "[[ \"\$output\" == *'Locked:'* ]]" "-v shows locked message"
    teardown
}

# Test: Verbose long option
test_verbose_long() {
    setup
    local testfile="$TEST_DIR/verbosetest2.txt"
    echo "test" > "$testfile"

    local output
    output="$("$LOCK" --verbose --password=testpassword "$testfile" 2>&1)"

    assert_true "[[ \"\$output\" == *'Locked:'* ]]" "--verbose shows locked message"
    teardown
}

# Test: Custom password option
test_custom_password() {
    setup
    local testfile="$TEST_DIR/passwordtest.txt"
    local original_content="secret data"
    echo "$original_content" > "$testfile"

    local exit_code=0
    "$LOCK" --password=mysecretpass "$testfile" >/dev/null 2>&1 || exit_code=$?

    assert_equals "0" "$exit_code" "Lock with --password should succeed"

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

# Test: Non-existent file
test_nonexistent_file() {
    local exit_code=0
    "$LOCK" "/nonexistent/file/path" 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "Non-existent file returns exit code 1"
}

# Test: Lock creates unique filenames (no conflict with encrypted names)
test_no_conflict() {
    setup
    local testfile="$TEST_DIR/conflict.txt"
    echo "original" > "$testfile"

    local exit_code=0
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1 || exit_code=$?

    assert_equals "0" "$exit_code" "Lock should succeed"
    assert_true "[[ ! -f \"$testfile\" ]]" "Original file should not exist"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Encrypted file should exist"
    teardown
}

# Test: Using -- to separate options from arguments
test_double_dash_separator() {
    setup
    local dashfile="$TEST_DIR/-file-with-dash.txt"
    echo "test" > "$dashfile"

    "$LOCK" --password=testpassword -- "$dashfile" >/dev/null 2>&1

    assert_true "[[ ! -e \"$dashfile\" ]]" "Original file should not exist"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Encrypted file should exist"
    teardown
}

# Test: File with spaces in name
test_file_with_spaces() {
    setup
    local spacefile="$TEST_DIR/file with spaces.txt"
    echo "test" > "$spacefile"

    "$LOCK" --password=testpassword "$spacefile" >/dev/null 2>&1

    assert_true "[[ ! -e \"$spacefile\" ]]" "Original file should not exist"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Encrypted file should exist"
    teardown
}

# Test: Mixed success and failure
test_mixed_results() {
    setup
    local goodfile="$TEST_DIR/good.txt"
    echo "good" > "$goodfile"

    local exit_code=0
    "$LOCK" --password=testpassword "$goodfile" "/nonexistent" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Mixed results returns exit code 1"

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    assert_true "[[ -n \"$hidden_file\" && -f \"$hidden_file\" ]]" "Good file should be locked"
    teardown
}

# Test: Recursive lock of directory with contents
test_recursive_lock() {
    setup
    local testdir="$TEST_DIR/mydir"
    mkdir -p "$testdir/subdir"
    echo "file1 content" > "$testdir/file1.txt"
    echo "file2 content" > "$testdir/subdir/file2.txt"

    "$LOCK" --password=testpassword -R "$testdir" >/dev/null 2>&1

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

# Test: Recursive lock with verbose
test_recursive_verbose() {
    setup
    local testdir="$TEST_DIR/verbosedir"
    mkdir "$testdir"
    echo "content" > "$testdir/innerfile.txt"

    local output
    output="$("$LOCK" --password=testpassword -R -v "$testdir" 2>&1)"

    assert_true "[[ \"\$output\" == *'Locked:'* ]]" "-R -v shows locked messages"
    assert_true "[[ \"\$output\" == *'Encoded:'* ]]" "-R -v shows encoded messages for files"
    teardown
}

# Test: Dry-run mode does not modify files
test_dry_run() {
    setup
    local testfile="$TEST_DIR/dryrun.txt"
    local original_content="dry run content"
    echo "$original_content" > "$testfile"

    local output
    output="$("$LOCK" --password=testpassword -n "$testfile" 2>&1)"

    assert_true "[[ -f \"$testfile\" ]]" "Original file should still exist after dry-run"
    assert_true "[[ \"\$output\" == *'Would lock:'* ]]" "Dry-run shows 'Would lock:' message"

    # Verify content unchanged
    local content
    content="$(cat "$testfile")"
    assert_equals "$original_content" "$content" "File content should be unchanged after dry-run"
    teardown
}

# Test: Dry-run with recursive
test_dry_run_recursive() {
    setup
    local testdir="$TEST_DIR/dryrundir"
    mkdir -p "$testdir/subdir"
    echo "file1" > "$testdir/file1.txt"
    echo "file2" > "$testdir/subdir/file2.txt"

    local output
    output="$("$LOCK" --password=testpassword -n -R "$testdir" 2>&1)"

    assert_true "[[ -d \"$testdir\" ]]" "Directory should still exist after dry-run"
    assert_true "[[ -f \"$testdir/file1.txt\" ]]" "File1 should still exist after dry-run"
    assert_true "[[ -f \"$testdir/subdir/file2.txt\" ]]" "File2 should still exist after dry-run"
    assert_true "[[ \"\$output\" == *'Would lock:'* ]]" "Dry-run shows 'Would lock:' messages"
    teardown
}

# Test: Short password warning (using -p flag which bypasses confirmation)
test_short_password_warning() {
    setup
    local testfile="$TEST_DIR/shortpw.txt"
    echo "test" > "$testfile"

    # Short password should trigger warning, but we auto-answer N so it aborts
    local exit_code=0
    echo "n" | "$LOCK" -p "abc" "$testfile" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Short password with 'n' response should abort"
    assert_true "[[ -f \"$testfile\" ]]" "File should still exist after abort"
    teardown
}

# Test: Short password accepted with 'y'
test_short_password_accepted() {
    setup
    local testfile="$TEST_DIR/shortpw2.txt"
    echo "test" > "$testfile"

    # Short password with 'y' should proceed
    local exit_code=0
    echo "y" | "$LOCK" -p "abc" "$testfile" >/dev/null 2>&1 || exit_code=$?

    assert_equals "0" "$exit_code" "Short password with 'y' response should succeed"
    assert_true "[[ ! -f \"$testfile\" ]]" "Original file should be locked"
    teardown
}

# Run all tests
echo "Running lock tests..."
echo

test_help_short
test_help_long
test_no_arguments
test_invalid_option
test_lock_file
test_lock_directory
test_lock_multiple
test_verbose_output
test_verbose_long
test_custom_password
test_nonexistent_file
test_no_conflict
test_double_dash_separator
test_file_with_spaces
test_mixed_results
test_recursive_lock
test_recursive_verbose
test_dry_run
test_dry_run_recursive
test_short_password_warning
test_short_password_accepted

echo
echo "================================"
echo "Tests passed: $tests_passed"
echo "Tests failed: $tests_failed"
echo "================================"

[[ $tests_failed -eq 0 ]] && exit 0 || exit 1
