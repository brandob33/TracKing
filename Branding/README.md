# TracKing logo: Crowned Oval

The 400m oval with a crown on the top bend. Every file comes as an SVG (`svg/`) and a 1024×1024 PNG (`png/`).

| File | Use |
| --- | --- |
| `tracking-main` | Main logo and the iOS app icon (track red, crown gold, green infield) |
| `tracking-uci-blue` | UCI blue background, white track, gold crown |
| `tracking-uci-navy` | UCI dark blue background, gold track and crown |
| `tracking-uci-gold` | UCI gold background, blue track and crown |
| `tracking-bw-black` | White logo on black |
| `tracking-bw-white` | Black logo on white |
| `tracking-bw-outline` | Black outline (hollow infield) on white |
| `tracking-bw-outline-inverse` | White outline (hollow infield) on black |
| `tracking-mark-*` | Transparent background versions (main colors, UCI, black, white) for putting on other backgrounds |

Colors: track red `#B83A25`, crown gold `#F4B400`, infield green `#2E7D4F`, UCI blue `#0064A4`, UCI gold `#FFD200`, UCI dark blue `#1B3D6D`.

The app icon lives in `TracKing/Assets.xcassets/AppIcon.appiconset` (a single 1024px image; Xcode generates the smaller sizes).

## Explorations

`explorations/` holds other directions that are not in use yet: Crown Band, Stadium View, Monoline, Crest, Crowned Hurdle and Lane Crown.

## App colors

The app's colors live in one file, `Shared/Theme.swift`, and are currently a UC Irvine theme (UCI blue `#0064A4`, UCI gold `#FFD200`, UCI dark blue `#1B3D6D`). Change the values there to re-theme the whole app and the lock-screen rest timer. GO stays green and rest stays orange on purpose, so the timing states are easy to tell apart at a glance.
