# 0001 Icon package

Status: accepted (2026-10-13)

Choice: `lucide_icons_flutter` ^3.1.25 (ISC licence, same icon set as the web sidebar).

Why:
- The web student account uses Lucide icons (`resources/student-dashboard/lucide.php`).
- Checked pub.dev on 2026-10-13: `lucide_icons_flutter` 3.1.25 was published 2026-10-12 (actively released).
  `lucide_icons` 0.257.0 was last published 2023-06-29 (stale), so it was rejected.
- It is a community port, not published by the Lucide team. Risk is mitigated by wrapping every icon in
  `lib/core/design/icons.dart` (`ClayIcons`); screens never import the package directly. Swapping the
  package, or vendoring the SVGs, is a one-file change.

Replacing `font_awesome_flutter`: only 14 usages exist (`models/menu_item.dart`, `features/home/menu_screen.dart`).
They move to `ClayIcons` with the navigation shell commit, and the dependency is then removed.
The rest of the app uses Material `Icons.*` and migrates screen by screen in Phase 4.
