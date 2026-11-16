# Design System — ReadBeat

## Intent
- **Product**: Personal ebook + audio library with reliable multi-device resume.
- **Audience**: Solo readers who switch phones/tablets and refuse to lose their place.
- **Vibe**: Cool bright white desk by day; dark mode washes ocean blue into forest green — frosted glass panels, deeper green accents, warm orange sparks.
- **Signature**: **Resume Pulse** — a glass card with a forest→bright→orange progress edge that always answers “where was I?”
- **Ritual**: Glance home → tap Resume → continue at the exact beat/page.
- **Auth**: Optional. Local library (ebooks + audio + progress) works without an account; sign-in is only asked when the user wants cross-device sync.

## Typography
- **Display**: Fraunces (soft bookish contrast, not newspaper layout)
- **Body / UI**: Manrope (clear, modern, non-default Inter stack)
- Scale (approx): display 32/40, title 22/28, body 16/24, caption 13/18

## Spacing & radius
- Base grid: **8**
- Radius: sm 8 · md 12 · lg 20 · **controls (buttons / inputs): full pill (999)** · floating nav / mini-player: full pill (999)
- Control height: buttons **36**, text buttons **32**, inputs dense (~36 visual)

## Color roles (semantic)

Deep forest seed + orange accent. Surfaces use **glassmorphism** (blur + translucency), not neon.

| Role | Light | Dark | Notes |
|------|-------|------|-------|
| bg | #F7FAFC | #08141C | Cool bright white / mid ocean–forest blend |
| atmosphere-from | #F7FAFC | #071525 | Scaffold start (cool white / dark ocean blue) |
| atmosphere-to | #F2F7F5 | #071A12 | Scaffold end (cool mist / dark forest green) |
| surface | #F1F5F7 | #0E1719 | Content panels |
| surface-elevated | #FFFFFF | #152022 | Opaque sheets when glass isn’t used |
| glass-fill | white @ 58% | white @ 8% | Frosted panel fill |
| glass-border | white @ 78% | white @ 16% | Highlight edge |
| text-primary | #07110C | #F4FBF7 | Ink |
| text-secondary | #5A6562 | #9AADA3 | Meta |
| text-inverse | #FFFFFF | #07110C | On primary fills |
| border | #D7E0E3 | #243038 | Hairlines |
| primary | #045C38 | #1A8F5C | Darker forest seed / CTA fill |
| primary-bright | #0A7A4A | #2AA86C | Gradient end (not neon) |
| primary-muted | #E6F1EC | #123226 | Soft brand wash |
| accent | #FF6B00 | #FF6B00 | Orange highlight |
| success | #0B6B3F | #2AA86C | Sync ok |
| warning | #B45309 | #FBBF24 | Pending sync |
| danger | #B91C1C | #FF6B6B | Destructive |
| focus-ring | #045C38 | #1A8F5C | Visible focus |

## Gradients (purposeful)
- **Atmosphere (light)**: cool bright white → soft cool mist
- **Atmosphere (dark)**: dark ocean blue `#071525` → dark forest green `#071A12`, 7-stop smooth diagonal lerp
- **Brand fill** (primary CTAs): primary → primary-bright (135°)
- **Resume Pulse edge**: primary → primary-bright → accent tip
- Do **not** use purple/indigo gradients or neon acid greens

## Glassmorphism
- Blur sigma ≈ **22** (`BackdropFilter`)
- Soft lift shadow under panels; no colored glow
- Used on: floating bottom nav, Continue / progress tiles, mini-player

## Elevation / shadows
- Light: soft cool shadow `0 10 24 rgba(7,17,12,0.10)`
- Dark: soft black lift `0 10 20 rgba(0,0,0,0.40)` + glass border only

## Motion
- Fast UI: 180ms · Resume pulse: 420ms ease-out
- Honor reduced motion (static pulse marker)

## Components (rules of thumb)
- **No hero cards** for decoration; cards only when they hold an action (open / resume).
- Primary CTA = Resume (ebook or audio) — brand fill gradient + soft forest shadow.
- Mini-player floats as a matching glass pill above the nav when audio is active.
- **Import status**: thin progress hairline under the system status bar + glass pill banner (file name + N of M) while importing; snackbar confirms when done.
- **Open with / Share**: system registers ReadBeat for EPUB, PDF, MP3, M4A — opening or sharing a file auto-imports it (status banner + snackbar).
- **Feature covers**: import extracts cover art when present (EPUB OPF cover, PDF first page, MP3/M4A embedded art). If missing, ReadBeat paints a brand default cover (forest/ocean gradient + monogram) so every shelf item has art.
- **Remove imports**: Library long-press enters multi-select (circular marks; the pressed title is already checked). Delete from the selection bar. Detail still has “Remove from library”. Deletes media file, cover, and progress on device.
- Bottom nav is floating glass + fully rounded, **icon-only**, with a sliding brand-gradient indicator (tooltips keep labels for a11y).
- **Icons**: Font Awesome via `AppIcon` / `AppIcons` — **solid full plain only** (no dual-tone / outline layers). Prefer rounded solid glyphs. No Material Icons in product UI.
- Library lists are dense shelves, not dashboards. A list ↔ 3-col grid toggle (persisted) sits beside the filters; grid matches Home shelf covers. Both views show the resume Beat trail + percent.
- Home **Also in progress** and **Your shelf** are a single 1×3 cover row. Your shelf shows the three most recently opened titles; **See all** always opens Library.
- Segmented filters: no selected checkmark icons.
- **Search** is local (title / author / format). Empty match copy, not a blank shelf.
- **Favorites** use the orange accent spark only when active.
- **Listening queues** are audio-only CRUD lists — not discovery playlists.
- **Settings** groups sync, storage, appearance, privacy, account. Recap consent is off by default.
- **Onboarding** is a four-page desk tour; Skip is always available.

## Anti-patterns
- Purple-on-white / indigo gradients
- Warm cream + terracotta + default serif AI cluster
- Broadsheet dense columns / zero-radius newspaper chrome
- Neon / acid glow / emoji-as-brand / pill forests on every chip
- Copying source-app layouts / gamification chrome — palette only

## Stack binding notes
- Flutter: `ColorScheme` light + dark via `ReadBeatTheme`, `ThemeMode.system` default
- Glass helpers + gradients on `ThemeExtension<ReadBeatColors>` + `GlassPanel`
- Tokens live in `lib/app/theme.dart` and mirror this table
