# How to publish Privacy & Terms without your own domain

Apple requires **public HTTPS links** that open in Safari. You do **not** need to buy a domain first.

## Option A — Notion (easiest, ~15 minutes)

1. Create a free account at [notion.so](https://www.notion.so).
2. Create a new page titled **Upzo Privacy Policy**.
3. Copy the text from `legal/PRIVACY_POLICY.md` into the page (remove `#` markdown headers or use Notion headings).
4. Click **Share → Publish → Publish to web**.
5. Copy the public URL (looks like `https://yourname.notion.site/...`).
6. Repeat for **Terms of Service** from `legal/TERMS_OF_SERVICE.md`.
7. Repeat for **Upzo Support** (content in prior App Store draft or your Notion support page).
8. Paste URLs into `timer/SettingsLinks.swift`:
   - `privacyPolicyURLString`
   - `termsOfServiceURLString`
   - `supportPageURLString`
9. Use **Privacy Policy URL** and **Support URL** in App Store Connect → App Information.

## Option B — GitHub Pages (free, stable URLs)

1. Create a GitHub account.
2. New repository: `wake-up-plus-legal` (public).
3. Add files `privacy.md` and `terms.md` (content from this folder).
4. Settings → Pages → Source: **main branch** → Save.
5. URLs will be:
   - `https://YOUR_USERNAME.github.io/wake-up-plus-legal/privacy`
   - `https://YOUR_USERNAME.github.io/wake-up-plus-legal/terms`

## Option C — Google Sites (free)

1. [sites.google.com](https://sites.google.com) → new site.
2. Paste policy text on two pages.
3. Publish → copy public links.

## After publishing

- Open each URL in Safari (incognito) to confirm it loads.
- Support email: `amaykorade5@gmail.com` (set in `SettingsLinks.swift` and legal docs).
- Update developer name in policies if you use a company name instead of individual.

## App Store Connect

- **Privacy Policy URL** (required): `https://steadfast-agate-517.notion.site/Privacy-Policy-36a70f01c48a800b9679f59999dae61c`
- **Support URL** (required): `https://steadfast-agate-517.notion.site/UPZO-SUPPORT-36b70f01c48a80808358cd3e7022fa9a`
- **Terms of Use (EULA)** — required for auto-renewable subscriptions (Guideline 3.1.2(c)):
  - If **Apple’s standard EULA** is enabled (recommended): paste the footer from `legal/APP_STORE_DESCRIPTION_LEGAL_FOOTER.txt` at the **end of the App Description**. It includes Apple’s EULA URL plus your subscription terms link.
  - If you use a **custom EULA** instead: paste `legal/TERMS_OF_SERVICE.md` into App Store Connect → License Agreement (EULA).
- In-app: paywall and Settings already link Privacy Policy and Terms of Use.
