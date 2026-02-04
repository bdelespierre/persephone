#!/usr/bin/env bats

load test_helper

@test "command_exists returns true for bash" {
    command_exists bash
}

@test "command_exists returns false for nonexistent command" {
    run command_exists nonexistent_command_xyz
    [[ "$status" -ne 0 ]]
}

@test "file_readable returns true for readable file" {
    file_readable "$PROJECT_ROOT/lib/persephone/utils.bash"
}

@test "file_readable returns false for nonexistent file" {
    run file_readable /nonexistent/file
    [[ "$status" -ne 0 ]]
}

@test "warn_short_password rejects short password when user answers n" {
    run bash -c "source '$PROJECT_ROOT/lib/persephone/utils.bash'; echo 'n' | warn_short_password 'abc' 8 2>/dev/null"
    [[ "$status" -eq 1 ]]
}

@test "warn_short_password accepts short password when user answers y" {
    run bash -c "source '$PROJECT_ROOT/lib/persephone/utils.bash'; echo 'y' | warn_short_password 'abc' 8 2>/dev/null"
    [[ "$status" -eq 0 ]]
}

@test "warn_short_password passes without prompt for long password" {
    run warn_short_password "longpassword" 8
    [[ "$status" -eq 0 ]]
}
