# Slug

macOS menu bar utility that watches your Screenshots folder and instantly renames every new screenshot using AI vision.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What it does

macOS names screenshots `Screenshot 2026-03-18 at 9.41.23 AM.png` — completely useless when you're searching for something weeks later. Slug fixes that automatically.

The moment a new screenshot lands in your folder, Slug sends it to Gemini Vision AI and renames it to something meaningful — instantly, silently, in the background.

- Watches your Screenshots folder with zero CPU overhead
- Renames files instantly using AI vision (Gemini 2.5 Flash)
- Generates short, slug-friendly names like `figma-login-error.png` or `stripe-invoice-march.png`
- Lives in your menu bar — no Dock icon, no UI to manage
- Shows your 8 most recent renames at a glance
- Launches at login, stays out of your way

---

## Requirements

- macOS 13.0 (Ventura) or later
- [Homebrew](https://brew.sh)
- A free [Gemini API key](https://aistudio.google.com/apikey) — no credit card required

---

## Installation

```bash
brew tap winner14/slug
brew install --cask slug
```

### First launch

Since Slug is not yet notarized, macOS will show a security warning on first launch.

To open it:
1. Go to **System Settings → Privacy & Security**
2. Scroll down to find **"slug was blocked"**
3. Click **Open Anyway**
4. Enter your password

This is a one-time step.

### Setup

1. Click the Slug icon in your menu bar
2. Click **Settings**
3. Paste your Gemini API key — get one free at [aistudio.google.com](https://aistudio.google.com/apikey)
4. Click **Test** to confirm the key works
5. Set your Screenshots folder if needed (default: `~/Desktop`)
6. Toggle Slug **on**

Take a screenshot (⌘⇧4) — it will be renamed within a second.

---

## How to use

1. Click the Slug icon in your menu bar
2. The toggle at the top turns renaming on or off
3. The **Recent** list shows your last 8 renames
4. Click **Settings** to change your API key or watched folder
5. Click **Quit** to stop Slug completely

To pause renaming temporarily, toggle the switch off. Slug will keep watching but won't rename until you turn it back on.

---

## Example renames

| Before | After |
|---|---|
| `Screenshot 2026-03-18 at 9.41.23 AM.png` | `figma-login-error.png` |
| `Screenshot 2026-03-18 at 11.02.47 AM.png` | `stripe-invoice-march.png` |
| `Screenshot 2026-03-19 at 2.14.09 PM.png` | `github-pr-review-comments.png` |
| `Screenshot 2026-03-19 at 4.55.31 PM.png` | `slack-standup-thread.png` |
| `Screenshot 2026-03-20 at 8.30.12 AM.png` | `xcode-build-failure.png` |

---

## Uninstall

```bash
brew uninstall --cask slug
```

Your screenshots folder and existing files are left untouched.

---

## Troubleshooting

### Screenshot was not renamed
A few things to check:

1. Make sure the toggle is **on** in the menu bar
2. Confirm your Gemini API key is saved — open Settings and click **Test**
3. Check that Slug is watching the right folder — macOS saves screenshots to `~/Desktop` by default unless you've changed it in Screenshot app settings

To check where your screenshots go: open the Screenshot app (⌘⇧5) → Options → Save to.

### "Slug can't be opened because Apple cannot verify it"
See the **First launch** section above — go to **System Settings → Privacy & Security → Open Anyway**.

### API key test fails
- Make sure you created your key at [aistudio.google.com](https://aistudio.google.com/apikey) and not Google Cloud Console
- Keys created in Google Cloud Console start with 0 quota — AI Studio keys come with a free tier pre-configured
- Check that your Mac has an active internet connection

### Slug renames a screenshot to something wrong
Gemini Vision reads the visible content of the screenshot to generate the name. Very sparse screenshots (blank pages, solid colors) may get a generic name. This will improve as the AI model improves.

### Slug stopped renaming after working fine
Your Gemini API free tier may have hit its daily limit (1,500 requests/day on the free tier). Usage resets every 24 hours. You can check your usage at [ai.dev/rate-limit](https://ai.dev/rate-limit).

---

## How it works

Slug uses two things:

**FSEventStream** watches your Screenshots folder at the OS level — zero polling, zero CPU usage at idle. The moment macOS writes a new file matching the default screenshot naming pattern (`Screenshot *.png`), Slug is notified within milliseconds.

**Gemini Vision AI** receives the screenshot as a base64-encoded image and returns a short, descriptive, slug-friendly filename. The image is resized before sending to keep API usage low. The response is sanitized to ensure it's a valid filename before the rename happens.

Your API key is stored in **macOS Keychain** — never in plain text or UserDefaults.

---

## Tech stack

- Swift + SwiftUI
- FSEventStream (folder watching)
- Gemini 2.5 Flash Vision API (AI naming)
- macOS Keychain (API key storage)
- ServiceManagement (launch at login)

---

## Roadmap

- [ ] Auto-organize into subfolders by app or category
- [ ] Undo last rename from the menu bar
- [ ] Custom naming rules and prefix templates
- [ ] App Store distribution with notarization
- [ ] Support for JPEG and other screenshot formats

---

## License

MIT
