#!/bin/bash
# Sign and optionally notarize a macOS RustDesk client for end-user distribution.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  macos-sign-notarize.sh sign <app-bundle> <p12-file> <p12-password>
  macos-sign-notarize.sh notarize <dmg-file> <api-key-json-file>

Environment:
  RCODESIGN_BIN  Path to rcodesign (default: rcodesign in PATH)
EOF
}

RCODESIGN_BIN="${RCODESIGN_BIN:-rcodesign}"
ACTION="${1:-}"
shift || { usage; exit 1; }

sign_app() {
  local app_path="$1"
  local p12_file="$2"
  local p12_password="$3"

  if [[ ! -d "$app_path" ]]; then
    echo "App bundle not found: $app_path"
    exit 1
  fi
  if [[ ! -f "$p12_file" ]]; then
    echo "Certificate file not found: $p12_file"
    exit 1
  fi

  echo "Signing app bundle: $app_path"
  "$RCODESIGN_BIN" sign \
    --p12-file "$p12_file" \
    --p12-password "$p12_password" \
    --code-signature-flags runtime \
    "$app_path"

  echo "Verifying signature..."
  "$RCODESIGN_BIN" verify "$app_path" --verbose
  codesign --verify --deep --strict --verbose=2 "$app_path"
  spctl -a -vv "$app_path" 2>&1 || true
  echo "App signed successfully."
}

notarize_dmg() {
  local dmg_path="$1"
  local api_key_file="$2"

  if [[ ! -f "$dmg_path" ]]; then
    echo "DMG not found: $dmg_path"
    exit 1
  fi
  if [[ ! -f "$api_key_file" ]]; then
    echo "App Store Connect API key file not found: $api_key_file"
    exit 1
  fi

  echo "Submitting DMG for notarization: $dmg_path"
  "$RCODESIGN_BIN" notary-submit \
    --api-key-file "$api_key_file" \
    --wait \
    --staple \
    "$dmg_path"

  echo "Verifying stapled ticket..."
  "$RCODESIGN_BIN" verify "$dmg_path" --verbose
  spctl -a -vv -t open --context context:primary-signature "$dmg_path" 2>&1 || true
  echo "DMG notarized and stapled successfully."
}

install_rcodesign() {
  if command -v "$RCODESIGN_BIN" >/dev/null 2>&1; then
    return
  fi
  echo "Installing rcodesign..."
  local tmp
  tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  curl -fsSL -o apple-codesign.tar.gz \
    "https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F0.29.0/apple-codesign-0.29.0-macos-universal.tar.gz"
  tar -zxf apple-codesign.tar.gz
  install -m 0755 apple-codesign-0.29.0-macos-universal/rcodesign /usr/local/bin/rcodesign
  popd >/dev/null
  RCODESIGN_BIN=/usr/local/bin/rcodesign
}

case "$ACTION" in
  sign)
    install_rcodesign
    sign_app "$1" "$2" "$3"
    ;;
  notarize)
    install_rcodesign
    notarize_dmg "$1" "$2"
    ;;
  *)
    usage
    exit 1
    ;;
esac
