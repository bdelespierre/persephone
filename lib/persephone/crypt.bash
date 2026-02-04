#!/usr/bin/env bash
#
# crypt.bash - Encryption/decryption functions for persephone
#

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! declare -F log_info &>/dev/null; then
    source "$LIB_DIR/utils.bash"
fi

# Encrypt a filename using AES-256-CBC (URL-safe base64 output)
encrypt_name() {
    local name="$1"
    local password="$2"
    # Encrypt with AES-256-CBC, output as base64, then make URL-safe
    printf '%s' "$name" | openssl enc -aes-256-cbc -salt -pbkdf2 -base64 -pass pass:"$password" | tr '+/' '-_' | tr -d '=' | tr -d '\n'
}

encrypt_file() {
    local file="$1"
    local tmpfile

    tmpfile="$(mktemp)"
    if openssl enc -aes-256-cbc -salt -pbkdf2 -base64 -pass pass:"$PASSWORD" -in "$file" -out "$tmpfile"; then
        mv "$tmpfile" "$file"
        return 0
    else
        rm -f "$tmpfile"
        return 1
    fi
}

encrypt_item() {
    local item="$1"
    local dir basename newname newpath
    local result=0

    # Check if item exists
    if [[ ! -e "$item" ]]; then
        log_error "No such file or directory: $item"
        return 1
    fi

    # Get directory and basename
    dir="$(dirname "$item")"
    basename="$(basename "$item")"

    # If recursive and it's a directory, process contents first
    if [[ "$RECURSIVE" == true && -d "$item" ]]; then
        local entry
        while IFS= read -r -d '' entry; do
            if ! encrypt_item "$entry"; then
                result=1
            fi
        done < <(find "$item" -maxdepth 1 -mindepth 1 -print0)
    fi

    # Create new encrypted name
    newname="$(encrypt_name "$basename" "$PASSWORD")"
    newpath="$dir/$newname"

    # Dry-run mode: just show what would happen
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would encrypt: $item -> $newpath"
        return $result
    fi

    # Check if target already exists
    if [[ -e "$newpath" ]]; then
        log_error "Target already exists: $newpath"
        return 1
    fi

    # Encrypt file contents if it's a regular file
    if [[ -f "$item" ]]; then
        if ! encrypt_file "$item"; then
            log_error "Failed to encrypt file: $item"
            return 1
        fi
        log_verbose "Encrypted file: $item"
    fi

    # Perform the rename
    if ! mv "$item" "$newpath"; then
        log_error "Failed to encrypt: $item"
        return 1
    fi

    log_verbose "Encrypted: $item -> $newpath"
    return $result
}

# Decrypt a filename using AES-256-CBC
decrypt_name() {
    local encoded="$1"
    local password="$2"
    # Add back padding if needed, convert from URL-safe, then decrypt
    local padding=$(( (4 - ${#encoded} % 4) % 4 ))
    local padded="$encoded$(printf '%*s' "$padding" '' | tr ' ' '=')"
    # Convert from URL-safe base64 and add newline for openssl
    printf '%s\n' "$padded" | tr '_' '/' | tr '\-' '+' | openssl enc -aes-256-cbc -d -pbkdf2 -base64 -pass pass:"$password"
}

decrypt_file() {
    local file="$1"
    local tmpfile

    tmpfile="$(mktemp)"
    if openssl enc -aes-256-cbc -d -pbkdf2 -base64 -pass pass:"$PASSWORD" -in "$file" -out "$tmpfile"; then
        mv "$tmpfile" "$file"
        return 0
    else
        rm -f "$tmpfile"
        return 1
    fi
}

decrypt_item() {
    local item="$1"
    local dir basename newname newpath
    local result=0

    # Check if item exists
    if [[ ! -e "$item" ]]; then
        log_error "No such file or directory: $item"
        return 1
    fi

    # Get directory and basename
    dir="$(dirname "$item")"
    basename="$(basename "$item")"

    # Don't process . or ..
    if [[ "$basename" == "." || "$basename" == ".." ]]; then
        log_warn "Cannot decrypt special directory: $item"
        return 0
    fi

    # Create new decrypted name
    newname="$(decrypt_name "$basename" "$PASSWORD")"
    newpath="$dir/$newname"

    # Dry-run mode: just show what would happen
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would decrypt: $item -> $newpath"
        # If recursive and it's a directory, still show contents in dry-run
        if [[ "$RECURSIVE" == true && -d "$item" ]]; then
            local entry
            while IFS= read -r -d '' entry; do
                if ! decrypt_item "$entry"; then
                    result=1
                fi
            done < <(find "$item" -maxdepth 1 -mindepth 1 -print0)
        fi
        return $result
    fi

    # Check if target already exists
    if [[ -e "$newpath" ]]; then
        log_error "Target already exists: $newpath"
        return 1
    fi

    # Perform the rename
    if ! mv "$item" "$newpath"; then
        log_error "Failed to decrypt: $item"
        return 1
    fi

    log_verbose "Decrypted: $item -> $newpath"

    # Decrypt file contents if it's a regular file
    if [[ -f "$newpath" ]]; then
        if ! decrypt_file "$newpath"; then
            log_error "Failed to decrypt file: $newpath"
            return 1
        fi
        log_verbose "Decrypted file: $newpath"
    fi

    # If recursive and it's a directory, process contents after decrypting
    if [[ "$RECURSIVE" == true && -d "$newpath" ]]; then
        local entry
        while IFS= read -r -d '' entry; do
            if ! decrypt_item "$entry"; then
                result=1
            fi
        done < <(find "$newpath" -maxdepth 1 -mindepth 1 -print0)
    fi

    return $result
}
