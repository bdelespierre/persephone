#!/usr/bin/env bash
#
# test_utils.sh - Tests for utility functions
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_ROOT/lib/utils.sh"

# Test counter
tests_passed=0
tests_failed=0

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

# Tests
test_command_exists() {
    assert_true "command_exists bash" "bash command should exist"
    assert_true "! command_exists nonexistent_command_xyz" "nonexistent command should not exist"
}

test_file_readable() {
    assert_true "file_readable $PROJECT_ROOT/lib/utils.sh" "utils.sh should be readable"
    assert_true "! file_readable /nonexistent/file" "nonexistent file should not be readable"
}

test_warn_short_password_short() {
    # Short password with 'n' should exit with error
    local exit_code=0
    echo "n" | warn_short_password "abc" 8 2>/dev/null || exit_code=$?
    assert_equals "1" "$exit_code" "Short password rejected with 'n' should exit 1"
}

test_warn_short_password_accepted() {
    # Short password with 'y' should continue
    local exit_code=0
    echo "y" | warn_short_password "abc" 8 2>/dev/null || exit_code=$?
    assert_equals "0" "$exit_code" "Short password accepted with 'y' should exit 0"
}

test_warn_short_password_long_enough() {
    # Long enough password should not prompt
    local exit_code=0
    warn_short_password "longpassword" 8 2>/dev/null || exit_code=$?
    assert_equals "0" "$exit_code" "Long password should exit 0 without prompt"
}

# Run tests
echo "Running tests..."
echo

test_command_exists
test_file_readable
test_warn_short_password_short
test_warn_short_password_accepted
test_warn_short_password_long_enough

echo
echo "================================"
echo "Tests passed: $tests_passed"
echo "Tests failed: $tests_failed"
echo "================================"

[[ $tests_failed -eq 0 ]] && exit 0 || exit 1
