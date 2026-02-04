#!/usr/bin/env bash
#
# test_unlock.sh - Tests for unlock script
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
UNLOCK="$PROJECT_ROOT/bin/unlock"
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
    output="$("$UNLOCK" -h 2>&1)" || true
    assert_true "[[ \"\$output\" == *'Usage:'* ]]" "-h shows usage"
    assert_true "[[ \"\$output\" == *'--help'* ]]" "-h shows --help option"
    assert_true "[[ \"\$output\" == *'--verbose'* ]]" "-h shows --verbose option"
    assert_true "[[ \"\$output\" == *'--password'* ]]" "-h shows --password option"
    assert_true "[[ \"\$output\" == *'--recursive'* ]]" "-h shows --recursive option"
}

# Test: Help option (--help)
test_help_long() {
    local output
    output="$("$UNLOCK" --help 2>&1)" || true
    assert_true "[[ \"\$output\" == *'Usage:'* ]]" "--help shows usage"
}

# Test: No arguments shows error
test_no_arguments() {
    local exit_code=0
    "$UNLOCK" 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "No arguments returns exit code 1"
}

# Test: Invalid option
test_invalid_option() {
    local exit_code=0
    "$UNLOCK" -z 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "Invalid option returns exit code 1"
}

# Test: Unlock an encrypted file (round-trip test)
test_unlock_file() {
    setup
    local testfile="$TEST_DIR/testfile.txt"
    local original_content="test content"
    echo "$original_content" > "$testfile"

    # Lock the file first
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    # Unlock it
    "$UNLOCK" --password=testpassword "$encrypted_file" >/dev/null 2>&1

    assert_true "[[ ! -e \"$encrypted_file\" ]]" "Encrypted file should not exist"
    assert_true "[[ -f \"$TEST_DIR/testfile.txt\" ]]" "Unlocked file should exist"

    # Verify file is decrypted (content should match original)
    local revealed_content
    revealed_content="$(cat "$TEST_DIR/testfile.txt")"
    assert_equals "$original_content" "$revealed_content" "Unlocked file should be decrypted to original content"
    teardown
}

# Test: Unlock an encrypted directory (round-trip test)
test_unlock_directory() {
    setup
    local testdir="$TEST_DIR/testdir"
    mkdir "$testdir"

    # Lock the directory first
    "$LOCK" --password=testpassword "$testdir" >/dev/null 2>&1

    # Find the hidden directory
    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    # Unlock it
    "$UNLOCK" --password=testpassword "$encrypted_dir" >/dev/null 2>&1

    assert_true "[[ ! -e \"$encrypted_dir\" ]]" "Encrypted directory should not exist"
    assert_true "[[ -d \"$TEST_DIR/testdir\" ]]" "Unlocked directory should exist"
    teardown
}

# Test: Unlock multiple items (round-trip test)
test_unlock_multiple() {
    setup
    local file1="$TEST_DIR/file1.txt"
    local file2="$TEST_DIR/file2.txt"
    local content1="content1"
    local content2="content2"
    echo "$content1" > "$file1"
    echo "$content2" > "$file2"

    # Lock both files
    "$LOCK" --password=testpassword "$file1" "$file2" >/dev/null 2>&1

    # Find encrypted files and reveal them
    local encrypted_files
    encrypted_files=$(find "$TEST_DIR" -maxdepth 1 -type f)
    for ef in $encrypted_files; do
        "$UNLOCK" --password=testpassword "$ef" >/dev/null 2>&1
    done

    assert_true "[[ -f \"$TEST_DIR/file1.txt\" ]]" "First unlocked file should exist"
    assert_true "[[ -f \"$TEST_DIR/file2.txt\" ]]" "Second unlocked file should exist"

    # Verify both files are decrypted
    local revealed1 revealed2
    revealed1="$(cat "$TEST_DIR/file1.txt")"
    revealed2="$(cat "$TEST_DIR/file2.txt")"
    assert_equals "$content1" "$revealed1" "First file should be decrypted"
    assert_equals "$content2" "$revealed2" "Second file should be decrypted"
    teardown
}

# Test: Verbose output (round-trip test)
test_verbose_output() {
    setup
    local testfile="$TEST_DIR/verbosetest.txt"
    echo "test" > "$testfile"

    # Lock the file first
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    local output
    output="$("$UNLOCK" -v --password=testpassword "$encrypted_file" 2>&1)"

    assert_true "[[ \"\$output\" == *'Unlocked:'* ]]" "-v shows unlocked message"
    teardown
}

# Test: Verbose long option (round-trip test)
test_verbose_long() {
    setup
    local testfile="$TEST_DIR/verbosetest2.txt"
    echo "test" > "$testfile"

    # Lock the file first
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    local output
    output="$("$UNLOCK" --verbose --password=testpassword "$encrypted_file" 2>&1)"

    assert_true "[[ \"\$output\" == *'Unlocked:'* ]]" "--verbose shows unlocked message"
    teardown
}

# Test: Custom password option (round-trip test)
test_custom_password() {
    setup
    local testfile="$TEST_DIR/passwordtest.txt"
    local original_content="secret data"
    echo "$original_content" > "$testfile"

    # Lock with custom password
    "$LOCK" --password=mysecretpass "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    local exit_code=0
    "$UNLOCK" --password=mysecretpass "$encrypted_file" >/dev/null 2>&1 || exit_code=$?

    assert_equals "0" "$exit_code" "Unlock with --password should succeed"
    assert_true "[[ -f \"$TEST_DIR/passwordtest.txt\" ]]" "Unlocked file should exist with custom password"

    # Verify file is decrypted correctly
    local revealed_content
    revealed_content="$(cat "$TEST_DIR/passwordtest.txt" 2>/dev/null || echo "")"
    assert_equals "$original_content" "$revealed_content" "File should be decrypted with custom password"
    teardown
}

# Test: Non-existent file
test_nonexistent_file() {
    local exit_code=0
    "$UNLOCK" "/nonexistent/file/path" 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "Non-existent file returns exit code 1"
}

# Test: Target already exists (round-trip test)
test_target_exists() {
    setup
    local testfile="$TEST_DIR/conflict.txt"
    echo "original" > "$testfile"

    # Lock the file
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    # Create a file with the original name (conflict)
    echo "existing" > "$TEST_DIR/conflict.txt"

    local exit_code=0
    "$UNLOCK" --password=testpassword "$encrypted_file" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Target exists returns exit code 1"
    assert_true "[[ -f \"$encrypted_file\" ]]" "Encrypted file should still exist"
    teardown
}

# Test: Using -- to separate options from arguments (round-trip test)
test_double_dash_separator() {
    setup
    local testfile="$TEST_DIR/hidden-file.txt"
    echo "test" > "$testfile"

    # Lock the file
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    "$UNLOCK" --password=testpassword -- "$encrypted_file" >/dev/null 2>&1

    assert_true "[[ ! -e \"$encrypted_file\" ]]" "Encrypted file should not exist"
    assert_true "[[ -f \"$TEST_DIR/hidden-file.txt\" ]]" "Unlocked file should exist"
    teardown
}

# Test: File with spaces in name (round-trip test)
test_file_with_spaces() {
    setup
    local testfile="$TEST_DIR/file with spaces.txt"
    echo "test" > "$testfile"

    # Lock the file
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    "$UNLOCK" --password=testpassword "$encrypted_file" >/dev/null 2>&1

    assert_true "[[ ! -e \"$encrypted_file\" ]]" "Encrypted file should not exist"
    assert_true "[[ -f \"$TEST_DIR/file with spaces.txt\" ]]" "Unlocked file should exist"
    teardown
}

# Test: Mixed success and failure (round-trip test)
test_mixed_results() {
    setup
    local testfile="$TEST_DIR/good.txt"
    echo "good" > "$testfile"

    # Lock the file
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the hidden file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    local exit_code=0
    "$UNLOCK" --password=testpassword "$encrypted_file" "/nonexistent" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Mixed results returns exit code 1"
    assert_true "[[ -f \"$TEST_DIR/good.txt\" ]]" "Good file should be unlocked"
    teardown
}

# Test: Recursive unlock of directory with contents (round-trip test)
test_recursive_unlock() {
    setup
    local testdir="$TEST_DIR/mydir"
    mkdir -p "$testdir/subdir"
    echo "file1 content" > "$testdir/file1.txt"
    echo "file2 content" > "$testdir/subdir/file2.txt"

    # Lock recursively
    "$LOCK" --password=testpassword -R "$testdir" >/dev/null 2>&1

    # Find the hidden directory
    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    # Unlock recursively
    "$UNLOCK" --password=testpassword -R "$encrypted_dir" >/dev/null 2>&1

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

# Test: Recursive unlock with verbose (round-trip test)
test_recursive_verbose() {
    setup
    local testdir="$TEST_DIR/verbosedir"
    mkdir "$testdir"
    echo "content" > "$testdir/innerfile.txt"

    # Lock recursively
    "$LOCK" --password=testpassword -R "$testdir" >/dev/null 2>&1

    # Find the hidden directory
    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    local output
    output="$("$UNLOCK" --password=testpassword -R -v "$encrypted_dir" 2>&1)"

    assert_true "[[ \"\$output\" == *'Unlocked:'* ]]" "-R -v shows unlocked messages"
    assert_true "[[ \"\$output\" == *'Decoded:'* ]]" "-R -v shows decoded messages for files"
    teardown
}

# Test: Dry-run mode does not modify files (round-trip test)
test_dry_run() {
    setup
    local testfile="$TEST_DIR/dryrun.txt"
    echo "dry run content" > "$testfile"

    # Lock the file first
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the encrypted file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"
    local encrypted_content
    encrypted_content="$(cat "$encrypted_file")"

    local output
    output="$("$UNLOCK" --password=testpassword -n "$encrypted_file" 2>&1)"

    assert_true "[[ -f \"$encrypted_file\" ]]" "Encrypted file should still exist after dry-run"
    assert_true "[[ \"\$output\" == *'Would unlock:'* ]]" "Dry-run shows 'Would unlock:' message"

    # Verify content unchanged
    local content
    content="$(cat "$encrypted_file")"
    assert_equals "$encrypted_content" "$content" "File content should be unchanged after dry-run"
    teardown
}

# Test: Dry-run with recursive (round-trip test)
test_dry_run_recursive() {
    setup
    local testdir="$TEST_DIR/dryrundir"
    mkdir -p "$testdir/subdir"
    echo "file1" > "$testdir/file1.txt"
    echo "file2" > "$testdir/subdir/file2.txt"

    # Lock recursively
    "$LOCK" --password=testpassword -R "$testdir" >/dev/null 2>&1

    # Find the encrypted directory
    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    local output
    output="$("$UNLOCK" --password=testpassword -n -R "$encrypted_dir" 2>&1)"

    assert_true "[[ -d \"$encrypted_dir\" ]]" "Encrypted directory should still exist after dry-run"
    assert_true "[[ \"\$output\" == *'Would unlock:'* ]]" "Dry-run shows 'Would unlock:' messages"
    teardown
}

# Test: Short password warning
test_short_password_warning() {
    setup
    local testfile="$TEST_DIR/shortpw.txt"
    echo "test" > "$testfile"

    # Lock the file first with long password
    "$LOCK" --password=testpassword "$testfile" >/dev/null 2>&1

    # Find the encrypted file
    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    # Short password should trigger warning, 'n' response aborts
    local exit_code=0
    echo "n" | "$UNLOCK" -p "abc" "$encrypted_file" 2>/dev/null || exit_code=$?

    assert_equals "1" "$exit_code" "Short password with 'n' response should abort"
    assert_true "[[ -f \"$encrypted_file\" ]]" "Encrypted file should still exist after abort"
    teardown
}

# Run all tests
echo "Running unlock tests..."
echo

test_help_short
test_help_long
test_no_arguments
test_invalid_option
test_unlock_file
test_unlock_directory
test_unlock_multiple
test_verbose_output
test_verbose_long
test_custom_password
test_nonexistent_file
test_target_exists
test_double_dash_separator
test_file_with_spaces
test_mixed_results
test_recursive_unlock
test_recursive_verbose
test_dry_run
test_dry_run_recursive
test_short_password_warning

echo
echo "================================"
echo "Tests passed: $tests_passed"
echo "Tests failed: $tests_failed"
echo "================================"

[[ $tests_failed -eq 0 ]] && exit 0 || exit 1
