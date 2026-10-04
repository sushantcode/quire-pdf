#!/usr/bin/env bash
# The export-compliance declaration, checked against the code that has to keep it.
#
# `ITSAppUsesNonExemptEncryption: false` in `ios/project.yml` is a statement
# about this app to a regulator, shipped inside every build, and it is what
# App Store Connect reads instead of asking about encryption on each upload.
# It is true today because the app's only cryptography is the operating
# system's own: Data Protection on the merged files it writes
# (`.completeFileProtection`), and whatever PDFKit does to read a file.
#
# Nothing about adding real encryption would make that sentence change. The
# likeliest way for it to arrive here is a feature, not a library: "protect
# the merged PDF with a password" is a few lines of PDFKit or Core Graphics
# that compile, pass every test, and ship a declaration that has silently
# become false. So besides the usual cryptography APIs, this looks for the
# options that write an encrypted PDF or unlock one.
#
# It scans everything the iOS app ships: its own sources and QuireKit's.
#
# Deliberately lexical and deliberately narrow. It flags the symbols that mean
# *encrypting something*, not the ones that mean hashing, random bytes or the
# system's file protection, and it says what to do rather than only that
# something is wrong. A guard that fired on `SHA256` or `.completeFileProtection`
# would fire on every build and be turned off within a week.
#
#   ios/Tools/check-encryption.sh [repository root]
set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$root"

declared="$(awk -F: '/^[[:space:]]*ITSAppUsesNonExemptEncryption[[:space:]]*:/ {
  gsub(/[[:space:]]/, "", $2); print $2; exit }' ios/project.yml)"

if [ "$declared" != "false" ]; then
  echo "ITSAppUsesNonExemptEncryption is '${declared:-unset}', so this check does not apply."
  echo "Whoever set it that way owns the answer App Store Connect asks for."
  exit 0
fi

# Encrypting, decrypting or signing with a key of the app's own, rather than
# the storage protection the system provides. `CommonCrypto` is listed as an
# import because it is the C library people reach for when CryptoKit will not
# do what they want, and reaching for it is itself the signal.
crypto='SymmetricKey|SealedBox|ChaChaPoly|AES\.|import CommonCrypto|CCCrypt|SecKeyCreateEncryptedData|SecKeyCreateDecryptedData|SecKeyCreateSignature|P256\.Signing|Curve25519'

# Writing a password-protected PDF, or opening one. PDFKit's write options and
# Core Graphics' context keys encrypt the file; `unlock(withPassword:)` decrypts
# one. The app rejects locked PDFs today, which is why none of these appear.
pdf='userPasswordOption|ownerPasswordOption|PDFDocumentWriteOption\.(user|owner)Password|kCGPDFContext(User|Owner)Password|kCGPDFContextEncryptionKeyLength|unlock\(withPassword'

found="$(grep -rnE "$crypto|$pdf" ios/QuirePDF QuireKit/Sources --include='*.swift' 2>/dev/null || true)"

if [ -n "$found" ]; then
  echo "The iOS build declares ITSAppUsesNonExemptEncryption = false, meaning this" >&2
  echo "app uses no encryption beyond the operating system's own. That is no longer" >&2
  echo "obviously true:" >&2
  echo >&2
  sed 's/^/  /' <<<"$found" >&2
  echo >&2
  echo "Decide which it is, then do one of:" >&2
  echo "  - keep the declaration, if this is still hashing, authentication or the" >&2
  echo "    system's own cryptography, and narrow this check so it no longer matches" >&2
  echo "  - remove ITSAppUsesNonExemptEncryption from ios/project.yml and answer" >&2
  echo "    App Store Connect's encryption question per upload instead. Password-" >&2
  echo "    protecting PDFs is encryption, whatever library does it." >&2
  echo >&2
  echo "It is a statement to a regulator that ships inside the build, so it is" >&2
  echo "worth the minute this takes." >&2
  exit 1
fi

echo "export-compliance declaration matches the code"
