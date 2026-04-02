# Scrub Sniffer WoW Addon

## Overview
Lightweight WoW retail addon that generates a Scrub Sniffer lookup URL for a player and copies it to the clipboard. One click in group finder, paste in browser, done.

## Target URL Format
```
https://scrub-sniffer.vercel.app/?character={name}&realm={realm}&region={region}
```
The web app will need a small update to read these query params and auto-run the lookup on page load.

## Addon Files
- `ScrubSniffer.toc` — addon metadata
- `ScrubSniffer.lua` — all logic (small enough for a single file)

## Features

### 1. Group Finder Integration
- Hook into the LFG applicant list (Premade Groups / Mythic+ finder)
- When viewing an applicant, add a button or right-click menu option: **"Scrub Sniff"**
- Use `C_LFGList.GetApplicantMemberInfo()` to get character name and realm
- Generate the lookup URL and copy to clipboard

### 2. Right-Click Unit Menu (Stretch Goal)
- Add a "Scrub Sniff" entry to the right-click player menu (party, raid, target frames)
- Use `UnitName("target")` / `GetUnitName()` + `GetRealmName()` for the name/realm
- Same URL generation and clipboard copy

### 3. Clipboard Copy
WoW has no direct clipboard API. Standard workaround:
- Create a hidden `EditBox`
- Set its text to the URL
- Call `HighlightText()` and `SetFocus()`
- Bind `Ctrl+C` or auto-select so the player just hits `Ctrl+V` in browser
- Alternatively: use a popup frame with the URL pre-selected so the user can `Ctrl+C` manually

Print a chat message confirming the copy: `[Scrub Sniffer] Link ready — paste in your browser!`

### 4. Slash Command Fallback
- `/sniff PlayerName-Realm` — manual lookup, generates URL and copies to clipboard
- `/sniff` with no args — looks up current target

## Key WoW API Functions
- `C_LFGList.GetApplicantMemberInfo(applicantID, memberIndex)` — returns name, class, level, etc.
- `C_LFGList.GetApplicantInfo(applicantID)` — application status/metadata
- `UnitFullName(unit)` — returns name, realm for a unit
- `GetNormalizedRealmName()` — player's own realm (fallback when realm is nil = same server)
- `UnitMenu` / `UnitPopupButtons` — for right-click menu hooks (API changed in recent expansions, verify current approach)

## Web App Changes Needed
In `public/index.html` (or a small JS snippet):
- On page load, check for `?character=X&realm=Y&region=Z` query params
- If present, auto-populate the input fields and trigger the lookup
- This makes the addon-generated URLs work as one-click lookups

## Notes
- Region can default to `us` and be configurable via a saved variable or slash command (`/sniff region eu`)
- Keep it minimal — no Ace3, no libs, no settings UI. Just a .toc and a .lua.
- The addon install path will be: `World of Warcraft/_retail_/Interface/AddOns/ScrubSniffer/`
