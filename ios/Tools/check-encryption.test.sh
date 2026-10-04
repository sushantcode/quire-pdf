#!/usr/bin/env bash
# What `check-encryption.sh` says, against a copy of the code with encryption
# planted in it.
#
# A check that has never failed is not known to work, and this one guards a
# statement that ships to a regulator. Each case copies the real declaration
# and sources into a throwaway tree, adds one line, and asks the check about
# it: the encryption it must catch, and the system protection it must not.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
script="$here/check-encryption.sh"
failures=0

# A tree shaped like the repository, holding what the check reads.
new_tree() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/ios" "$dir/QuireKit"
  cp "$repo/ios/project.yml" "$dir/ios/"
  cp -R "$repo/ios/QuirePDF" "$dir/ios/"
  cp -R "$repo/QuireKit/Sources" "$dir/QuireKit/"
  echo "$dir"
}

expect() {  # tree, "pass" or "fail", what
  local status=pass
  "$script" "$1" >/dev/null 2>&1 || status=fail
  if [[ "$status" != "$2" ]]; then
    echo "  ✘ $3: expected the check to $2, it did not" >&2
    failures=$((failures + 1))
  else
    echo "  ✔ $3"
  fi
  rm -rf "$1"
}

plant() {  # tree, path inside it, line
  echo "$3" >> "$1/$2"
}

tree="$(new_tree)"
expect "$tree" pass "the code as it is passes"

for line in \
  'let key = SymmetricKey(size: .bits256)' \
  'let box = try AES.GCM.seal(data, using: key)' \
  'import CommonCrypto' \
  'let options: [PDFDocumentWriteOption: Any] = [.userPasswordOption: password]' \
  'let options: [PDFDocumentWriteOption: Any] = [.ownerPasswordOption: password]' \
  'let info = [kCGPDFContextUserPassword: password] as CFDictionary' \
  'document.unlock(withPassword: password)'
do
  tree="$(new_tree)"
  plant "$tree" QuireKit/Sources/QuireKit/PDFComposer.swift "$line"
  expect "$tree" fail "catches: $line"
done

tree="$(new_tree)"
plant "$tree" ios/QuirePDF/Support/ScreenState.swift 'let sealed = try ChaChaPoly.seal(data, using: key)'
expect "$tree" fail "scans the app's own sources as well as QuireKit's"

for line in \
  'try data.write(to: url, options: [.atomic, .completeFileProtection])' \
  'let digest = SHA256.hash(data: data)' \
  'let bytes = SystemRandomNumberGenerator()'
do
  tree="$(new_tree)"
  plant "$tree" QuireKit/Sources/QuireKit/PDFComposer.swift "$line"
  expect "$tree" pass "allows: $line"
done

tree="$(new_tree)"
sed -i '' '/ITSAppUsesNonExemptEncryption/d' "$tree/ios/project.yml"
plant "$tree" QuireKit/Sources/QuireKit/PDFComposer.swift 'import CommonCrypto'
expect "$tree" pass "stands aside when nothing is declared"

if (( failures > 0 )); then
  echo "$failures encryption-check case(s) failed" >&2
  exit 1
fi
echo "encryption check: all cases pass"
