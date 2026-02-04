# persephone.sh

A Bash-based file encryption tool that encrypts both file contents and filenames using AES-256-CBC encryption.

## Table of Contents

- [Installation](#installation)
- [Uninstallation](#uninstallation)
- [Usage](#usage)
- [Options Reference](#options-reference)
- [Encryption Details](#encryption-details)
- [Security Considerations](#security-considerations)
- [Limitations](#limitations)
- [Running Tests](#running-tests)
- [License](#license)

## Installation

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/bdelespierre/persephone/master/install.sh | bash
```

This installs to `~/.local` by default. To install to a different location:
```bash
curl -fsSL https://raw.githubusercontent.com/bdelespierre/persephone/master/install.sh | PREFIX=/usr/local bash
```

### From source

1. Clone the repository:
   ```bash
   git clone https://github.com/bdelespierre/persephone.git
   cd persephone
   ```

2. Install using make (installs to `~/.local/bin` by default):
   ```bash
   make install
   ```

   Or install to a custom location:
   ```bash
   sudo make install PREFIX=/usr/local
   ```

3. Ensure OpenSSL is installed (required for encryption):
   ```bash
   openssl version
   ```

## Uninstallation

```bash
make uninstall
```

Or if installed with a custom prefix:
```bash
sudo make uninstall PREFIX=/usr/local
```

## Usage

### Encrypting Files

```bash
# Encrypt a single file (prompts for password twice)
crypt file.txt

# Encrypt multiple files
crypt file1.txt file2.txt

# Encrypt with password provided (skips confirmation)
crypt -p "mypassword" file.txt

# Encrypt a directory recursively
crypt -R my_folder/

# Dry-run to see what would be encrypted
crypt -n file.txt

# Verbose mode
crypt -v file.txt
```

### Decrypting Files

```bash
# Decrypt an encrypted file
crypt -d encrypted_file

# Decrypt multiple files
crypt -d encrypted1 encrypted2

# Decrypt with password provided
crypt -d -p "mypassword" encrypted_file

# Decrypt a directory recursively
crypt -d -R encrypted_folder/

# Dry-run to see what would be decrypted
crypt -d -n encrypted_file

# Verbose mode
crypt -d -v encrypted_file
```

## Options Reference

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-d, --decrypt` | Decrypt mode (default is encrypt) |
| `-v, --verbose` | Enable verbose output |
| `-R, --recursive` | Recursively process directory contents |
| `-p, --password=PASS` | Password for encryption/decryption (prompted if not provided) |
| `-n, --dry-run` | Show what would be done without making changes |

## Encryption Details

- **Algorithm**: AES-256-CBC (Advanced Encryption Standard with 256-bit key, Cipher Block Chaining mode)
- **Key Derivation**: PBKDF2 (Password-Based Key Derivation Function 2)
- **Filename Encoding**: URL-safe Base64 (replaces `+/` with `-_`, removes padding)
- **Salt**: Random salt is generated for each encryption operation

## Security Considerations

- **Password Strength**: The tool warns if passwords are less than 8 characters. Use strong, unique passwords.
- **Password Confirmation**: When encrypting interactively, the password is prompted twice to prevent typos.
- **No Recovery**: There is no password recovery mechanism. If you forget your password, encrypted files cannot be recovered.
- **Memory**: Passwords are handled in memory during execution. Consider clearing bash history if using `-p` flag.
- **Temporary Files**: The tool uses temporary files during encryption/decryption, which are cleaned up on success or failure.

## Limitations

- Encrypted filenames can become very long, potentially exceeding filesystem limits
- Symbolic links are not specially handled (they are treated as regular files/directories)
- The tool requires OpenSSL to be installed
- Large files are loaded entirely into memory during encryption/decryption
- Password provided via `-p` flag may be visible in process listings

## Running Tests

```bash
make test
```

Or run individual test suites:
```bash
bats tests/test_crypt.bats
bats tests/test_utils.bats
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
