# 321 Vegan — Flutter app

## What this is

321 Vegan is a free, open-source Flutter app (French-only UI) that lets users scan
product barcodes and check whether a product is vegan-friendly: additive analysis,
cosmetics, boycott data, a "vegandex", B12 reminders, and a contributor-only
product validator. Backend is a separate repo (`321vegan-api`); this repo is the
client only. License: AGPLv3 (client code only).

This `CLAUDE.md` lives in `flutter_app/` (the actual Dart/Flutter project root —
the git repo root one level up also holds non-code docs like `README.md` and
`CONTRIBUTING.md`, which are not app source).

We are mid-way through a full visual redesign driven by a Figma file ("the
Figma redesign" is referenced throughout the code). Some screens/widgets have
been migrated to the new design system below; others still use ad-hoc
`TextStyle`/`Colors.grey[...]`/`BorderRadius` from before the redesign. **When
you touch a file that still has pre-redesign styling, prefer replacing it with
the shared design-system pieces below over leaving it as ad-hoc code or adding
more ad-hoc code next to it.**

## The prime directive: reuse and replace, don't hand-roll

Before writing any new UI code:

1. **Look in `lib/widgets/shared/` first.** If a card, button, text field, info
   box, bottom sheet, empty state, or similar already exists, use it instead of
   building a new `Container`/`ElevatedButton`/etc. from scratch.
2. **Look in `lib/themes/` for colors, text styles, spacing, and shapes** before
   writing a literal `Color(0x...)`, a hand-rolled `TextStyle`, or
   `BorderRadius.circular(...)`. See the Design System section below.
3. **If an existing shared widget is *almost* right, extend it** (add an
   optional parameter) rather than forking a copy or building a parallel
   one-off next to it.
4. **If you're editing a screen that has pre-redesign, ad-hoc styling nearby
   and it's in scope of your change, replace it with the shared equivalent.**
   Don't leave a file half-migrated if you're already touching that region.
5. Only add a genuinely new shared widget/style/color to
   `lib/widgets/shared/` or `lib/themes/` when nothing existing covers it —
   and add it there (not inline in a page) so the next person reuses it too.

This has been flagged before as a recurring correction: don't hand-roll
`TextStyle`s or boxes when `AppTextStyles`/`widgets/shared/` already covers it.

## Design system

Source of truth is a Figma file. Design tokens live in `lib/themes/`; reusable
UI pieces live in `lib/widgets/shared/`. Numeric values you find in Figma specs
(radii, padding, gaps, font sizes) are multiplied **×3** in the code before
going through ScreenUtil (`designSize: Size(1170, 2532)` in `main.dart`, 3× an
iPhone's 390pt logical width) — e.g. a 20pt Figma radius becomes `60.r`, a
16pt gap becomes `48.w`/`48.h`. Keep that convention when adding new values.

### Tokens (`lib/themes/`)

- **`app_colors.dart`** — fixed brand colors from Figma that sit outside the
  seasonal-theme system (only the seasonal themes swap the primary green /
  background — see below). Key ones: `kAccentYellow` (secondary CTA color),
  `kSecondaryTag` / `kPrimaryTag` (pale tag backgrounds), `kTextPrimary`
  (near-black title text), `kBorderDefault` (1px hairline on white cards),
  `kSemanticError` / `kSemanticSuccess`. **Use `kSemanticError`/
  `kSemanticSuccess` instead of `Colors.red*`/`Colors.green*`**, and
  `kTextPrimary`/`kBorderDefault` instead of ad-hoc greys/blacks.
- **`app_text_styles.dart`** (`AppTextStyles`) — every text style from Figma's
  "Styles de texte" panel. Headings are Baloo 2 SemiBold, named by their
  Figma point size (`baloo17`, `baloo22`, `baloo26`, `baloo36`) so a size in a
  Figma frame maps directly to a getter — don't guess a semantic name.
  Body text is Karla (the app's default `fontFamily`), exposed as
  `body{Style}{Size}` getters (e.g. `bodyRegular15`, `bodyMedium13`,
  `bodyBold11`). Add a new getter here first if a Figma frame needs a
  size/weight combo that isn't covered yet — don't inline a one-off style.
- **`app_shapes.dart`** — squircle helpers (`squircleRadius`,
  `squircleBorder`, `squircleBorderOnly`). **All rounded corners in the app
  must be squircles, not plain circular arcs** — Figma's "corner smoothing"
  is 0.6 and every card/button/field/sheet uses it. Use `squircleBorder(...)`
  anywhere a `ShapeBorder` is expected (`Card.shape`, `Dialog.shape`,
  `InkWell.customBorder`, `ShapeDecoration.shape`) instead of
  `BoxDecoration(borderRadius: BorderRadius.circular(...))`.
- **`app_spacing.dart`** (`AppSpacing`) — vertical rhythm getters
  (`section`, `afterTitle`, `item`) so every redesigned screen spaces its
  blocks identically. Use these instead of ad-hoc `SizedBox(height: ...)`
  between sections.
- **`{season}_theme.dart` + `default_theme.dart`** — seasonal theme
  definitions (`SeasonalTheme` model: primary/secondary/accent color, wave
  color, background gradient, particle effects, seasonal icon/asset). The
  active seasonal theme is a `ThemeExtension` read via
  `Theme.of(context).extension<SeasonalTheme>()`; `AppBackground` and
  `stat_card.dart`'s seasonal illustration lookup are examples of components
  that adapt to it. New seasonal-aware UI should read the extension the same
  way rather than hardcoding a season check.

### Shared widgets (`lib/widgets/shared/`)

Check this directory before building UI from primitives. Notable ones:

- `AppCard` — white "surface card": `kBorderDefault` border, squircle
  corners (20pt default radius, override per spec), soft shadow.
- `AppButton` — Figma pill/stadium button; supports filled or
  outlined (`borderColor`), optional leading icon, and an `isLoading` state
  that swaps the label for a spinner without resizing.
- `AppTextField` — single-line input with squircle border that highlights
  `kAccentYellow` on focus; use `AppTextStyles` for its text, not inline.
- `InfoBox` — pale-yellow disclaimer/warning box (EAN-8 warnings, stat
  sheets, sources notes) with a circular symbol badge or icon asset.
- `AppBackground` — wraps a page's `Scaffold` subtree to paint the app's
  background gradient (or the active seasonal gradient + drifting particles).
  Wrap a whole page in this rather than setting `scaffoldBackgroundColor`.
- `AppBottomNav`, `bottom_sheet_shell.dart`, `empty_state_view.dart`,
  `search_empty_state.dart`, `form_error_banner.dart`, `link_row.dart`,
  `photo_picker_box.dart`, `shine_wrapper.dart`, `social_feedback_buttons.dart`,
  `update_dialog.dart`, `vegan_since_date_modal.dart` — one job each; skim
  the file before reimplementing similar behavior elsewhere.

Feature-specific widget folders (`widgets/auth/`, `widgets/b12/`,
`widgets/badges/`, `widgets/homepage/`, `widgets/map/`, `widgets/scaner/`,
`widgets/settings/`, `widgets/theme/`, `widgets/vegandex/`) hold widgets tied
to one feature — still prefer composing them from `widgets/shared/` +
`themes/` rather than duplicating primitives locally.

## Project structure

```
lib/
  main.dart          # app entry, ScreenUtilInit, ThemeData, startup init sequence
  pages/
    app_pages/        # authenticated app screens (Scan, Profile, Partners, dashboard, settings)
    first_launch/     # onboarding/intro flow
  widgets/
    shared/           # design-system widgets — check first, see above
    <feature>/         # feature-scoped widgets (auth, b12, badges, homepage, map, scaner, settings, theme, vegandex)
  themes/             # design tokens — colors, text styles, spacing, shapes, seasonal themes
  models/             # plain Dart data models (product, scan_result, user, subscription, badge, ...)
  services/           # static-class services: API access, auth, notifications, sync, caching
  helpers/            # small stateless helpers (db, preferences, first-launch, theme loading)
  assets/             # images, avatars, badges, seasonal theme art
```

State management is plain `StatefulWidget`/`setState` plus static service
classes and `SharedPreferences` — there is no Provider/Riverpod/Bloc in this
codebase. Don't introduce one for a single feature; follow the existing
pattern (a `services/*.dart` static class + local widget state).

Network: `dio` (+ `dio_cookie_manager`) via `services/dio_client.dart` and
`services/api_service.dart`. Local persistence: `sqflite` (via
`helpers/database_helper.dart`) for product databases, `shared_preferences`
for settings/flags.

## Conventions

- Corners: always squircles (`squircleBorder`/`squircleRadius`), never plain
  `BorderRadius.circular`.
- Colors: pull from `app_colors.dart` / the active `SeasonalTheme`, not
  literal hex or `Colors.red`/`Colors.green` for semantic states.
  `kSemanticError`/`kSemanticSuccess` specifically replace ad-hoc red/green.
- Text: pull from `AppTextStyles`, not inline `TextStyle(...)`, unless
  truly one-off and not part of the Figma type scale.
- Sizing/spacing: everything from Figma goes through ScreenUtil (`.w`, `.h`,
  `.r`, `.sp`) at the ×3 conversion described above — don't hardcode raw
  logical pixels for values that came from a Figma frame.
- iOS bundle id `com.example.veganApp` is the real, live production App
  Store identifier for this app — despite looking like a placeholder, never
  suggest renaming it.
- French only: all user-facing strings are French; there is no i18n
  abstraction to route around for UI copy.

## Before calling UI work done

For any visible UI change, run the app (or at minimum reason through) the
golden path and adjacent states (loading, empty, error, seasonal theme
variants if relevant) rather than only checking that it compiles. Flutter's
analyzer/tests catch correctness, not whether the change actually looks right
against the Figma spec.
