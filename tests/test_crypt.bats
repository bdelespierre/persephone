#!/usr/bin/env bats

load test_helper

setup() {
    TEST_DIR="$(mktemp -d)"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# ============================================================
# Encrypt mode tests
# ============================================================

@test "encrypt: -h shows complete usage information" {
    run "$CRYPT" -h
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'Usage:'* ]]
    [[ "$output" == *'--help'* ]]
    [[ "$output" == *'--verbose'* ]]
    [[ "$output" == *'--password'* ]]
    [[ "$output" == *'--recursive'* ]]
    [[ "$output" == *'--decrypt'* ]]
}

@test "encrypt: --help shows usage" {
    run "$CRYPT" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'Usage:'* ]]
}

@test "encrypt: no arguments returns exit code 1" {
    run "$CRYPT"
    [[ "$status" -eq 1 ]]
}

@test "encrypt: invalid option returns exit code 1" {
    run "$CRYPT" -z
    [[ "$status" -eq 1 ]]
}

@test "encrypt: regular file" {
    local testfile="$TEST_DIR/testfile.txt"
    local original_content="test content"
    echo "$original_content" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    [[ ! -e "$testfile" ]]

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    [[ -n "$hidden_file" && -f "$hidden_file" ]]

    local concealed_content
    concealed_content="$(cat "$hidden_file")"
    [[ "$concealed_content" != "$original_content" ]]
    [[ "$concealed_content" == U2FsdGVk* ]]
}

@test "encrypt: directory" {
    local testdir="$TEST_DIR/testdir"
    mkdir "$testdir"

    "$CRYPT" --password=testpassword "$testdir" >/dev/null 2>&1

    [[ ! -e "$testdir" ]]

    local hidden_dir
    hidden_dir="$(find_encrypted_dir "$TEST_DIR")"
    [[ -n "$hidden_dir" && -d "$hidden_dir" ]]
}

@test "encrypt: multiple items" {
    local file1="$TEST_DIR/file1.txt"
    local file2="$TEST_DIR/file2.txt"
    echo "content1" > "$file1"
    echo "content2" > "$file2"

    "$CRYPT" --password=testpassword "$file1" "$file2" >/dev/null 2>&1

    local encrypted_count
    encrypted_count=$(find "$TEST_DIR" -maxdepth 1 -type f | wc -l)
    [[ "$encrypted_count" -eq 2 ]]

    while IFS= read -r encrypted_file; do
        local content
        content="$(cat "$encrypted_file")"
        [[ "$content" == U2FsdGVk* ]]
    done < <(find "$TEST_DIR" -maxdepth 1 -type f)
}

@test "encrypt: -v shows verbose output" {
    local testfile="$TEST_DIR/verbosetest.txt"
    echo "test" > "$testfile"

    run "$CRYPT" -v --password=testpassword "$testfile"
    [[ "$output" == *'Encrypted:'* ]]
}

@test "encrypt: --verbose shows verbose output" {
    local testfile="$TEST_DIR/verbosetest2.txt"
    echo "test" > "$testfile"

    run "$CRYPT" --verbose --password=testpassword "$testfile"
    [[ "$output" == *'Encrypted:'* ]]
}

@test "encrypt: custom password" {
    local testfile="$TEST_DIR/passwordtest.txt"
    local original_content="secret data"
    echo "$original_content" > "$testfile"

    run "$CRYPT" --password=mysecretpass "$testfile"
    [[ "$status" -eq 0 ]]

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    [[ -n "$hidden_file" && -f "$hidden_file" ]]

    local concealed_content
    concealed_content="$(cat "$hidden_file" 2>/dev/null || echo "")"
    [[ "$concealed_content" == U2FsdGVk* ]]

    local decrypted
    decrypted="$(openssl enc -aes-256-cbc -d -pbkdf2 -base64 -pass pass:mysecretpass -in "$hidden_file" 2>/dev/null || echo "")"
    [[ "$decrypted" == "$original_content" ]]
}

@test "encrypt: nonexistent file returns exit code 1" {
    run "$CRYPT" "/nonexistent/file/path"
    [[ "$status" -eq 1 ]]
}

@test "encrypt: creates unique filenames" {
    local testfile="$TEST_DIR/conflict.txt"
    echo "original" > "$testfile"

    run "$CRYPT" --password=testpassword "$testfile"
    [[ "$status" -eq 0 ]]
    [[ ! -f "$TEST_DIR/conflict.txt" ]]

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    [[ -n "$hidden_file" && -f "$hidden_file" ]]
}

@test "encrypt: double dash separates options from arguments" {
    local dashfile="$TEST_DIR/-file-with-dash.txt"
    echo "test" > "$dashfile"

    "$CRYPT" --password=testpassword -- "$dashfile" >/dev/null 2>&1

    [[ ! -e "$dashfile" ]]

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    [[ -n "$hidden_file" && -f "$hidden_file" ]]
}

@test "encrypt: file with spaces in name" {
    local spacefile="$TEST_DIR/file with spaces.txt"
    echo "test" > "$spacefile"

    "$CRYPT" --password=testpassword "$spacefile" >/dev/null 2>&1

    [[ ! -e "$spacefile" ]]

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    [[ -n "$hidden_file" && -f "$hidden_file" ]]
}

@test "encrypt: mixed success and failure returns exit code 1" {
    local goodfile="$TEST_DIR/good.txt"
    echo "good" > "$goodfile"

    run "$CRYPT" --password=testpassword "$goodfile" "/nonexistent"
    [[ "$status" -eq 1 ]]

    local hidden_file
    hidden_file="$(find_encrypted_file "$TEST_DIR")"
    [[ -n "$hidden_file" && -f "$hidden_file" ]]
}

@test "encrypt: recursive directory with contents" {
    local testdir="$TEST_DIR/mydir"
    mkdir -p "$testdir/subdir"
    echo "file1 content" > "$testdir/file1.txt"
    echo "file2 content" > "$testdir/subdir/file2.txt"

    "$CRYPT" --password=testpassword -R "$testdir" >/dev/null 2>&1

    [[ ! -e "$testdir" ]]

    local hidden_dir
    hidden_dir="$(find_encrypted_dir "$TEST_DIR")"
    [[ -n "$hidden_dir" && -d "$hidden_dir" ]]

    local encrypted_subdir
    encrypted_subdir="$(find "$hidden_dir" -maxdepth 1 -type d ! -path "$hidden_dir" | head -1)"
    [[ -n "$encrypted_subdir" && -d "$encrypted_subdir" ]]

    local encrypted_file1
    encrypted_file1="$(find "$hidden_dir" -maxdepth 1 -type f | head -1)"
    [[ -n "$encrypted_file1" && -f "$encrypted_file1" ]]

    local file1_content
    file1_content="$(cat "$encrypted_file1")"
    [[ "$file1_content" == U2FsdGVk* ]]
}

@test "encrypt: recursive with verbose output" {
    local testdir="$TEST_DIR/verbosedir"
    mkdir "$testdir"
    echo "content" > "$testdir/innerfile.txt"

    run "$CRYPT" --password=testpassword -R -v "$testdir"
    [[ "$output" == *'Encrypted:'* ]]
    [[ "$output" == *'Encrypted file:'* ]]
}

@test "encrypt: dry-run does not modify files" {
    local testfile="$TEST_DIR/dryrun.txt"
    local original_content="dry run content"
    echo "$original_content" > "$testfile"

    run "$CRYPT" --password=testpassword -n "$testfile"
    [[ -f "$testfile" ]]
    [[ "$output" == *'Would encrypt:'* ]]

    local content
    content="$(cat "$testfile")"
    [[ "$content" == "$original_content" ]]
}

@test "encrypt: dry-run recursive does not modify files" {
    local testdir="$TEST_DIR/dryrundir"
    mkdir -p "$testdir/subdir"
    echo "file1" > "$testdir/file1.txt"
    echo "file2" > "$testdir/subdir/file2.txt"

    run "$CRYPT" --password=testpassword -n -R "$testdir"
    [[ -d "$testdir" ]]
    [[ -f "$testdir/file1.txt" ]]
    [[ -f "$testdir/subdir/file2.txt" ]]
    [[ "$output" == *'Would encrypt:'* ]]
}

@test "encrypt: short password warning aborts with n" {
    local testfile="$TEST_DIR/shortpw.txt"
    echo "test" > "$testfile"

    run bash -c "echo 'n' | '$CRYPT' -p 'abc' '$testfile' 2>/dev/null"
    [[ "$status" -eq 1 ]]
    [[ -f "$testfile" ]]
}

@test "encrypt: short password accepted with y" {
    local testfile="$TEST_DIR/shortpw2.txt"
    echo "test" > "$testfile"

    run bash -c "echo 'y' | '$CRYPT' -p 'abc' '$testfile' 2>/dev/null"
    [[ "$status" -eq 0 ]]
    [[ ! -f "$testfile" ]]
}

# ============================================================
# Decrypt mode tests
# ============================================================

@test "decrypt: no arguments returns exit code 1" {
    run "$CRYPT" -d
    [[ "$status" -eq 1 ]]
}

@test "decrypt: invalid option returns exit code 1" {
    run "$CRYPT" -d -z
    [[ "$status" -eq 1 ]]
}

@test "decrypt: encrypted file (round-trip)" {
    local testfile="$TEST_DIR/testfile.txt"
    local original_content="test content"
    echo "$original_content" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    "$CRYPT" -d --password=testpassword "$encrypted_file" >/dev/null 2>&1

    [[ ! -e "$encrypted_file" ]]
    [[ -f "$TEST_DIR/testfile.txt" ]]

    local revealed_content
    revealed_content="$(cat "$TEST_DIR/testfile.txt")"
    [[ "$revealed_content" == "$original_content" ]]
}

@test "decrypt: encrypted directory (round-trip)" {
    local testdir="$TEST_DIR/testdir"
    mkdir "$testdir"

    "$CRYPT" --password=testpassword "$testdir" >/dev/null 2>&1

    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    "$CRYPT" -d --password=testpassword "$encrypted_dir" >/dev/null 2>&1

    [[ ! -e "$encrypted_dir" ]]
    [[ -d "$TEST_DIR/testdir" ]]
}

@test "decrypt: multiple items (round-trip)" {
    local file1="$TEST_DIR/file1.txt"
    local file2="$TEST_DIR/file2.txt"
    echo "content1" > "$file1"
    echo "content2" > "$file2"

    "$CRYPT" --password=testpassword "$file1" "$file2" >/dev/null 2>&1

    local encrypted_files
    encrypted_files=$(find "$TEST_DIR" -maxdepth 1 -type f)
    for ef in $encrypted_files; do
        "$CRYPT" -d --password=testpassword "$ef" >/dev/null 2>&1
    done

    [[ -f "$TEST_DIR/file1.txt" ]]
    [[ -f "$TEST_DIR/file2.txt" ]]

    local revealed1 revealed2
    revealed1="$(cat "$TEST_DIR/file1.txt")"
    revealed2="$(cat "$TEST_DIR/file2.txt")"
    [[ "$revealed1" == "content1" ]]
    [[ "$revealed2" == "content2" ]]
}

@test "decrypt: -v shows verbose output (round-trip)" {
    local testfile="$TEST_DIR/verbosetest.txt"
    echo "test" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    run "$CRYPT" -d -v --password=testpassword "$encrypted_file"
    [[ "$output" == *'Decrypted:'* ]]
}

@test "decrypt: --verbose shows verbose output (round-trip)" {
    local testfile="$TEST_DIR/verbosetest2.txt"
    echo "test" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    run "$CRYPT" -d --verbose --password=testpassword "$encrypted_file"
    [[ "$output" == *'Decrypted:'* ]]
}

@test "decrypt: custom password (round-trip)" {
    local testfile="$TEST_DIR/passwordtest.txt"
    local original_content="secret data"
    echo "$original_content" > "$testfile"

    "$CRYPT" --password=mysecretpass "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    run "$CRYPT" -d --password=mysecretpass "$encrypted_file"
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_DIR/passwordtest.txt" ]]

    local revealed_content
    revealed_content="$(cat "$TEST_DIR/passwordtest.txt" 2>/dev/null || echo "")"
    [[ "$revealed_content" == "$original_content" ]]
}

@test "decrypt: nonexistent file returns exit code 1" {
    run "$CRYPT" -d "/nonexistent/file/path"
    [[ "$status" -eq 1 ]]
}

@test "decrypt: target already exists returns exit code 1 (round-trip)" {
    local testfile="$TEST_DIR/conflict.txt"
    echo "original" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    echo "existing" > "$TEST_DIR/conflict.txt"

    run "$CRYPT" -d --password=testpassword "$encrypted_file"
    [[ "$status" -eq 1 ]]
    [[ -f "$encrypted_file" ]]
}

@test "decrypt: double dash separates options from arguments (round-trip)" {
    local testfile="$TEST_DIR/hidden-file.txt"
    echo "test" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    "$CRYPT" -d --password=testpassword -- "$encrypted_file" >/dev/null 2>&1

    [[ ! -e "$encrypted_file" ]]
    [[ -f "$TEST_DIR/hidden-file.txt" ]]
}

@test "decrypt: file with spaces in name (round-trip)" {
    local testfile="$TEST_DIR/file with spaces.txt"
    echo "test" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    "$CRYPT" -d --password=testpassword "$encrypted_file" >/dev/null 2>&1

    [[ ! -e "$encrypted_file" ]]
    [[ -f "$TEST_DIR/file with spaces.txt" ]]
}

@test "decrypt: mixed success and failure returns exit code 1 (round-trip)" {
    local testfile="$TEST_DIR/good.txt"
    echo "good" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    run "$CRYPT" -d --password=testpassword "$encrypted_file" "/nonexistent"
    [[ "$status" -eq 1 ]]
    [[ -f "$TEST_DIR/good.txt" ]]
}

@test "decrypt: recursive directory with contents (round-trip)" {
    local testdir="$TEST_DIR/mydir"
    mkdir -p "$testdir/subdir"
    echo "file1 content" > "$testdir/file1.txt"
    echo "file2 content" > "$testdir/subdir/file2.txt"

    "$CRYPT" --password=testpassword -R "$testdir" >/dev/null 2>&1

    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    "$CRYPT" -d --password=testpassword -R "$encrypted_dir" >/dev/null 2>&1

    [[ ! -e "$encrypted_dir" ]]
    [[ -d "$TEST_DIR/mydir" ]]
    [[ -d "$TEST_DIR/mydir/subdir" ]]
    [[ -f "$TEST_DIR/mydir/file1.txt" ]]
    [[ -f "$TEST_DIR/mydir/subdir/file2.txt" ]]

    local file1_content file2_content
    file1_content="$(cat "$TEST_DIR/mydir/file1.txt")"
    file2_content="$(cat "$TEST_DIR/mydir/subdir/file2.txt")"
    [[ "$file1_content" == "file1 content" ]]
    [[ "$file2_content" == "file2 content" ]]
}

@test "decrypt: recursive with verbose output (round-trip)" {
    local testdir="$TEST_DIR/verbosedir"
    mkdir "$testdir"
    echo "content" > "$testdir/innerfile.txt"

    "$CRYPT" --password=testpassword -R "$testdir" >/dev/null 2>&1

    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    run "$CRYPT" -d --password=testpassword -R -v "$encrypted_dir"
    [[ "$output" == *'Decrypted:'* ]]
    [[ "$output" == *'Decrypted file:'* ]]
}

@test "decrypt: dry-run does not modify files (round-trip)" {
    local testfile="$TEST_DIR/dryrun.txt"
    echo "dry run content" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"
    local encrypted_content
    encrypted_content="$(cat "$encrypted_file")"

    run "$CRYPT" -d --password=testpassword -n "$encrypted_file"
    [[ -f "$encrypted_file" ]]
    [[ "$output" == *'Would decrypt:'* ]]

    local content
    content="$(cat "$encrypted_file")"
    [[ "$content" == "$encrypted_content" ]]
}

@test "decrypt: dry-run recursive does not modify files (round-trip)" {
    local testdir="$TEST_DIR/dryrundir"
    mkdir -p "$testdir/subdir"
    echo "file1" > "$testdir/file1.txt"
    echo "file2" > "$testdir/subdir/file2.txt"

    "$CRYPT" --password=testpassword -R "$testdir" >/dev/null 2>&1

    local encrypted_dir
    encrypted_dir="$(find_encrypted_dir "$TEST_DIR")"

    run "$CRYPT" -d --password=testpassword -n -R "$encrypted_dir"
    [[ -d "$encrypted_dir" ]]
    [[ "$output" == *'Would decrypt:'* ]]
}

@test "decrypt: short password warning aborts with n (round-trip)" {
    local testfile="$TEST_DIR/shortpw.txt"
    echo "test" > "$testfile"

    "$CRYPT" --password=testpassword "$testfile" >/dev/null 2>&1

    local encrypted_file
    encrypted_file="$(find_encrypted_file "$TEST_DIR")"

    run bash -c "echo 'n' | '$CRYPT' -d -p 'abc' '$encrypted_file' 2>/dev/null"
    [[ "$status" -eq 1 ]]
    [[ -f "$encrypted_file" ]]
}
