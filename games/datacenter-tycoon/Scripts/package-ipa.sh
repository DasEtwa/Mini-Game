#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcodebuild -project RackAndRich.xcodeproj -scheme RackAndRich -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -archivePath build/RackAndRich.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive > build/archive.log 2>&1 || { tail -100 build/archive.log; exit 1; }
mkdir -p build/ipa/Payload
cp -R build/RackAndRich.xcarchive/Products/Applications/RackAndRich.app build/ipa/Payload/
(cd build/ipa && zip -qry ../RackAndRich.ipa Payload)
python3 Scripts/validate-ipa.py build/RackAndRich.ipa
shasum -a 256 build/RackAndRich.ipa > build/RackAndRich.ipa.sha256
