# Sign in with Apple — setup & how to never break it again

## Files in this repo

There is **one** entitlements file:

| File | Purpose |
|------|---------|
| `timer/timer.entitlements` | The signing entitlements for **all** SDKs (device + simulator). Must contain `com.apple.developer.applesignin`. |

`AppSigning.entitlements`, `timer-simulator.entitlements`, and `timer.applesignin.entitlements` were removed — they were causing confusion.

## Why the capability card keeps appearing in Signing & Capabilities

That is **correct behavior**. Xcode mirrors the entitlements file as a card in the Signing & Capabilities tab.

- Entitlement is in the file → **card appears** (correct, leave it alone).
- You delete the card → Xcode **empties the entitlements file** → build signs without Sign in with Apple → error 1000 / -7026 on the iPhone.

**Rule: never delete the Sign in with Apple card. Never add it via `+ Capability` either.** Both modify the file. Leave the card alone and treat the entitlements file as the source of truth.

## One-time portal setup

1. [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) → `com.amay.timer` → enable **Sign in with Apple** → **Save**.
2. Xcode → **Settings → Accounts** → your Apple ID → **Download Manual Profiles**.

## Build & run

1. Xcode → **Product → Clean Build Folder** (⇧⌘K).
2. **Delete the app** on your iPhone (long press → Remove App).
3. Run destination = **physical iPhone** (Sign in with Apple does not work on Simulator).
4. **Run** (⌘R).

## Verify (optional)

```bash
bash Scripts/verify-apple-signin-entitlement.sh
```

Must print: `OK: Sign in with Apple entitlement is embedded.`

## If the file gets emptied again

Restore it manually:

```bash
cat > "timer/timer.entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
EOF
```
