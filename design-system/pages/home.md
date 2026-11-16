# Home — ReadBeat (“Desk Shelf”)

## Job
Open the app → instantly continue the right ebook or track. Secondary: glance the shelf, import, sync only if wanted.

## Ritual (one sentence)
Glance the **Continue** module → tap Resume → you’re back at the exact page or beat.

## What we studied (keep / refuse)

| Reference | Visible pattern | Keep for ReadBeat | Refuse |
|-----------|-----------------|-------------------|--------|
| Spotify Home / Jump back in | Large recent media + one-tap resume; mini-player dock | Dual “in progress” rail + mini-player when audio plays | Black void, green brand, endless discovery carousels |
| Apple Books | Current read up top; format switch ebook/audio; library shelves | Dominant Continue + format-aware shelf | Bookstore/discovery-first home |
| Libby | Clear ebook vs audio; “current” always reachable | Format labels + high-contrast play vs open | Rental/library-card chrome |
| Oku | Serif greeting + hero current book | Literary display type for brand/greeting | Goals/stats dashboard on home |
| Imprint “Jump Back In” | Progress on resume tiles | Progress edge on actionable tiles only | Daily promo banners / course collage |
| TIDAL | Bold Home title + floating nav | Calm bottom nav | Empty-center spinner as default |

Ebook apps worth knowing: **Apple Books**, **Libby**, **Kindle**, **Oku**, **Everand**, **Readwise Reader**, **Moon+ Reader**.

## Composition (first viewport)

```
┌─────────────────────────────┐
│ ReadBeat          🔍  👤    │  brand = hero signal
│ Good afternoon              │
│                             │
│ ┌─▐ Continue ─────────────┐ │  Resume Pulse edge
│ │ [cover] Quiet Shelf     │ │
│ │ Ch.12 · p.214           │ │
│ │ ▬▬▬▬▬▬▬▬░░░░  65%       │ │
│ │ [ Resume reading ]      │ │  only primary CTA
│ └─────────────────────────┘ │
│                             │
│ Also in progress  →         │  one row × three covers (See all if more)
│ [cover] [cover] [cover]     │
└─────────────────────────────┘
  …scroll…
│ Your shelf                    See all
│ [cover] [cover] [cover]   ← 3 most recently opened; See all → Library
│
│ ▐ mini-player (audio only)      ❚❚ │
│ Home  Library  Import  Settings    │
```

## Signature
**Resume Pulse** — glass Continue card with 4px forest→bright→orange edge; progress trail; optional micro pulse (420ms) on appear. Answers “where was I?” without stickers/badges.

## States
- **Empty**: Continue becomes “Import your first ebook or track” with one Import CTA
- **Guest**: quiet line under header — “On this device · Sign in to sync” (text button, not a sales card)
- **Signed in**: same slot becomes “Synced” / “Sync now”
- **Audio active**: mini-player docks above nav
- **Offline**: shelf fully usable; sync chip shows offline

## Nav IA
`Home` (this screen) · `Library` (filters/search dense) · `Import` · `Settings`

## Anti-patterns (this screen)
No Wrapped stats, no hero marketing collage, no pill chip forests, no purple gradients, no forced login gate.

## Tokens
MASTER only — Fraunces display, Manrope UI, deeper forest primary, orange accent, glass panels, atmosphere gradient.
