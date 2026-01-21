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
        ((tests_passed++))
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((tests_failed++))
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-}"

    if eval "$condition"; then
        ((tests_passed++))
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((tests_failed++))
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

# Run tests
echo "Running tests..."
echo

test_command_exists
test_file_readable

echo
echo "================================"
echo "Tests passed: $tests_passed"
echo "Tests failed: $tests_failed"
echo "================================"

[[ $tests_failed -eq 0 ]] && exit 0 || exit 1
