# ReadBeat release checklist (S12)

## Product gates
- [ ] Fresh install: splash → onboarding → desk home
- [ ] Skip onboarding; desk still works without an account
- [ ] Import EPUB, PDF, MP3, M4A; covers appear; Open with / Share still imports
- [ ] Resume Pulse on home opens the correct ebook page / audio position
- [ ] Audio: play, pause, lock screen, interruption, progress ~5s + on pause
- [ ] Favorite toggle on library + detail; Favs filter updates immediately
- [ ] Local search: title, author, format; clear control; empty match copy
- [ ] Listening queues: create, rename, add/remove/reorder audio, play queue
- [ ] Settings: theme, storage snapshot, recap consent off by default, delete account
- [ ] Sign in → progress / favorites / queues sync; sign out keeps local library

## Offline / errors
- [ ] Airplane mode: import, read, listen, favorite, queue still work
- [ ] Signed-in offline: glass banner “Offline. Resume stays… sync waits.”
- [ ] Settings Sync now while offline does not crash; outbox pending count updates when back online
- [ ] Missing audio file shows a clear snackbar, not a red screen

## Android QA
- [ ] POST_NOTIFICATIONS: allow from onboarding and from Settings
- [ ] Background audio + notification shade controls
- [ ] Open with EPUB/PDF/MP3/M4A from Files
- [ ] OAuth callback still returns to the app
- [ ] Release APK / AAB: `flutter build appbundle`

## iOS QA
- [ ] Background audio (`UIBackgroundModes` audio)
- [ ] Notification permission copy appears if prompted
- [ ] Open in ReadBeat from Files / Share Sheet
- [ ] OAuth callback scheme
- [ ] Release IPA via Xcode / `flutter build ipa`

## Appwrite (signed-in sync)
Collections on database `readbeat` (document permissions: user owner read/update/delete):

| Table | Fields |
|-------|--------|
| `progress` | userId, mediaId, workId, mediaType, position, duration, percent, chapterOrPage, cfi, title, deviceId, updatedAt |
| `media_catalog` | userId, workId, title, author, mediaType, format, exactHash, softKey, durationSeconds, updatedAt, source |
| `favorites` | userId, workId, isFavorite, updatedAt |
| `playlists` | userId, title, createdAt, updatedAt, tracksJson |

- [ ] Indexes: `userId` on all four; unique `(userId, workId)` on progress / catalog / favorites

## Perf / hardening
- [ ] `flutter test` green
- [ ] `flutter analyze` clean on `lib/` and `test/`
- [ ] Large PDF + long MP3: resume still instant; no UI jank on shelf scroll
- [ ] Reduced motion: splash / resume pulse stay static

## Store metadata
- [ ] Version bump in `pubspec.yaml`
- [ ] Privacy: local-first; sync is optional; recap AI does not send content unless consented (and recap is not live)
- [ ] Screenshots: light + dark desk home, reader/player, settings
