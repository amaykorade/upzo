#!/bin/bash
# Run after building: ./Scripts/verify-apple-signin-entitlement.sh
set -euo pipefail

APP_DEVICE=$(find ~/Library/Developer/Xcode/DerivedData -name "timer.app" -path "*Debug*iphoneos*" 2>/dev/null | grep -v "Index.noindex" | head -1)
APP_SIM=$(find ~/Library/Developer/Xcode/DerivedData -name "timer.app" -path "*Debug*iphonesimulator*" 2>/dev/null | grep -v "Index.noindex" | head -1)

check_app() {
  local APP="$1"
  local LABEL="$2"
  echo ""
  echo "=== ${LABEL} ==="
  echo "Path: ${APP}"

  if [[ -f "${APP}/embedded.mobileprovision" ]]; then
    if security cms -D -i "${APP}/embedded.mobileprovision" 2>/dev/null | grep -q "com.apple.developer.applesignin"; then
      echo "Provisioning profile: includes Sign in with Apple"
    else
      echo "Provisioning profile: MISSING Sign in with Apple"
    fi
  else
    echo "Provisioning profile: not embedded (normal for Simulator-only builds)"
  fi

  echo "Code signature entitlements:"
  codesign -d --entitlements :- "${APP}" 2>/dev/null || true

  if codesign -d --entitlements :- "${APP}" 2>/dev/null | grep -q "com.apple.developer.applesignin"; then
    echo "OK: Sign in with Apple entitlement is embedded."
    return 0
  fi
  echo "MISSING: com.apple.developer.applesignin is NOT in the signed app."
  return 1
}

if [[ -n "${APP_DEVICE}" ]]; then
  check_app "${APP_DEVICE}" "iPhone (device) build" && exit 0
fi

if [[ -n "${APP_SIM}" ]]; then
  check_app "${APP_SIM}" "Simulator build"
  echo ""
  echo "Simulator builds often show MISSING even when setup is correct."
  echo "Build and run on a physical iPhone (select your iPhone as destination, then Cmd+R)."
  echo "Then run this script again after building for device."
  exit 1
fi

echo "Build the timer scheme first."
echo "For Sign in with Apple: select your iPhone as the run destination, then Cmd+R."
exit 1
