# Compose-to-SwiftUI Mapping Reference

## Source-of-truth order

1. Explicit user-approved design reference and acceptance requirements.
2. Android theme/component declarations and Compose layout code.
3. Android runtime screenshot or emulator capture.
4. iOS system conventions, only where the first three do not specify a visual outcome.

Code establishes intent and repeatable numbers; a target-device capture establishes rendering.

## Mapping rules

| Compose evidence | SwiftUI starting point | Require a visual check for |
|---|---|---|
| `Modifier.padding`, `size`, `height`, `width`, `offset` in `dp` | Same numeric value in pt as an initial baseline | Safe area, font metrics, dynamic type, and parent geometry |
| `Arrangement.spacedBy`, `Spacer`, `weight` | `spacing`, `Spacer`, `frame(maxWidth:)`, layout priority | Compression, wrapping, and trailing alignment |
| `MaterialTheme.colorScheme` | Semantic `AppColor`/asset token | Light/dark values and disabled/selected states |
| `MaterialTheme.typography`, `TextStyle` | Semantic `AppTypography` token | Font family, weight, line height, baseline, and truncation |
| `RoundedCornerShape`, border, elevation | `clipShape`, `overlay`, `shadow` | Radius, stroke, shadow blur/offset/opacity |
| Compose `testTag` / semantics | `accessibilityIdentifier` on visible element | A small visual inside a larger touch target |
| `AnimatedVisibility`, sheet, selection state | Explicit SwiftUI state and transition | Cross-state layout shift and overlay anchoring |

## Do not use one-to-one conversion for

- `sp` to point size: map the typography role, then measure line height and hierarchy.
- Material buttons, text fields, tabs, lists, and sheets: implement the required visual metrics
  explicitly; platform defaults are intentionally different.
- Android window insets to iOS safe areas: preserve the composition, not the API call.
- Android vector drawables to SF Symbols: use an SF Symbol only if silhouette and visual weight
  match; otherwise retain/provide the intended asset.

## Recommended design anchors

Prioritize anchors that detect systematic “too large” drift:

- title text container height and baseline-adjacent vertical gaps;
- search field, card, chip, row, avatar, tab, and bottom-navigation visible bounds;
- leading/trailing content margins and card internal padding;
- title-to-subtitle and section-to-section spacing;
- selected/unselected tab indicator position and height;
- sheet top edge and first visible row position.

Use an absolute pt tolerance only when reference and runtime use the same logical viewport. When
the viewport differs, anchor size and relative spacing to a common container or explicitly record
the normalization calculation before comparing coordinates.
