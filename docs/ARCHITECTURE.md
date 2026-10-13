# App foundation (Phase 3)

Branch `feature/clay-ui`. Screens are rebuilt in Phase 4; this is the foundation they stand on.

## Layout

```
lib/
  app/        app.dart (providers, MaterialApp.router), app_config.dart (ENV + flags),
              app_services.dart (wiring for legacy singletons), session_controller.dart,
              router/ (go_router, redirect rules, static route names),
              menu/ (student menu model), shell/ (student and role shells, drawer, bottom bar)
  core/
    design/   tokens/ (palette, metrics, ClayTokens), theme/ (ClayTheme), components/ (Clay*), icons.dart
    a11y/     settings model, store, sync (local + remote), controller, panel, host, TTS
    network/  ApiClient + interceptors, token refresher
    auth/     TokenStore, UserProfileStore, RememberedLogin, LegacyMigration, SessionCleaner
    webview/  SsoWebViewScreen, WebviewPolicy, SsoTokenService, WebEngine
  features/   existing screens, unchanged apart from the plumbing listed below
```

- State: `provider` with `ChangeNotifier` (`SessionController`, `A11yController`). Repositories are plain classes.
- Routing: `go_router` with one `StatefulShellRoute` for the student, shells for parent and teacher.
  Older screens still use `Navigator.push` inside it; login and logout go through `SessionController`.
- Network: one `ApiClient` builds every Dio. Interceptor order: connectivity, auth header (our host only),
  401 handling (refresh or end session), 429 backoff, friendly errors, debug-only log.

## Design tokens (from the web Clay layer)

| Role | Light | Dark | High contrast |
|---|---|---|---|
| primary (`--blue`, Safaricom green) | #49AA44 | #49AA44 | #5CE65C |
| primaryDeep (AA text, focus) | #1D611A | #8FDB8A | #7DFF7D |
| primarySurface | #DBF1DA | #1E3A24 | #0A2E0A |
| onPrimary | #0F250E | #0F250E | #000000 |
| page / card | #F2F8F1 / #FFFFFF | #0D1A0F / #15281A | #000000 |
| ink | #0F250E | #EAF5E8 | #FFFFFF |
| danger / dangerDeep | #EB5757 / #B61616 | #EB5757 / #FFA3A3 | #FF6B6B / #FF9E9E |

Colour-blind palette (light only): Okabe-Ito #0072B2 family. Msafara blue (#03AEEF family) is kept for the Msafara area.
Radii 14/22/30/pill, spacing 4/8/12/16/24/32/48, touch 48, clay shadow = drop + inner light + inner shade.
Fonts: Fredoka (headings), Nunito (body), OpenDyslexic 3 (accessibility), all SIL OFL, licences in `assets/fonts/licenses`.
Icons: `lucide_icons_flutter` (docs/decisions/0001-icons.md).

## Components

ClayCard, ClayButton (primary, secondary, ghost, disabled, loading), ClayIconButton, ClayChip, ClayBadge,
ClayAvatar, ClayProgressBar and ClayProgressRing, ClayTabBar, ClayEmptyState, ClaySheet, ClayListTile,
ClayAppBar, ClayTextField, ClaySkeleton, plus ClaySurface (inset shadow painter), ClayPressable (focus ring,
pressed state, reduced-motion aware tap animation) and the app bottom bar.

## Accessibility settings (same keys and meaning as the web `AccessibilitySettings`)

| Setting | Effect in the app |
|---|---|
| text_size 0-3 | 100/115/130/150 percent on top of the OS scale, capped at 2.0 |
| line_spacing, letter_spacing 0-2 | text height and letter/word spacing |
| dyslexia_font | OpenDyslexic for headings and body |
| theme | light, dark, high contrast |
| colour_blind | Okabe-Ito palette, striped progress, outlined badges |
| reduce_motion | no tap animation, static skeleton and spinner; the OS "remove animations" setting also counts |
| mute_sounds | `A11yController.soundsAllowed` |
| simple_view | `SimpleView.of(context)` for screens to read |
| read_speed, read_lang | flutter_tts rate and voice (en-KE, sw-KE, then fallbacks), on device only |

Stored locally; synced with `GET/PUT /api/app/v1/me/accessibility` when `A11Y_REMOTE_SYNC` is on.

## What changed in existing code

Removed: saved passwords (student and parent), PII in SharedPreferences, the login force retry, the bearer header
sent to webviews, calls to the deprecated password-taking webview-token endpoint, `WebViewContentScreen`,
`AuthGate`, `font_awesome_flutter`, `print()` calls, response-body logging, `book_title`/`book_author`/`book_grade`
analytics parameters, all 98 `flutter analyze` findings that existed before.

Migrated on first launch (`LegacyMigration`): tokens to one `access_token` key; the Student ID only if Remember me
was on; display name and avatar URL to secure storage.

Not done in Phase 3: native screens (Phase 4), merging the two duplicate profile screens, removing the old
`AppColors`/`Elimu*` widgets, parent and teacher data endpoints (server side).
