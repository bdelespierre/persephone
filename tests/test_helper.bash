# test_helper.bash - Shared helpers for bats tests

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CRYPT="$PROJECT_ROOT/bin/crypt"

source "$PROJECT_ROOT/lib/persephone/utils.bash"

find_encrypted_file() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type f | head -1
}

find_encrypted_dir() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type d ! -path "$dir" | head -1
}
