#!/usr/bin/env bash
# Archive ScanMe for App Store. Requires macOS + Xcode + signing team in Xcode.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS IPA needs a Mac with Xcode. This host is $(uname -s)."
  echo "Open this repo on a Mac, then run: bash tool/build_ios_release.sh"
  exit 1
fi

cd "$(dirname "$0")/.."

flutter pub get
flutter build ipa --release \
  --export-options-plist=ios/ExportOptions.plist

echo
echo "IPA: build/ios/ipa/"
echo "Upload with Transporter or: xcrun altool / notary — prefer Xcode Organizer or Transporter."
