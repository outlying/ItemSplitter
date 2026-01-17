# Changelog

## 0.3.0
### Added
- Initial WoW Classic support with legacy bag/index fallbacks and container item info compatibility.
- `Interface-Classic` tag in the addon manifest.

### Changed
- Stack split override now supports legacy `OpenStackSplitFrame` call signature.
- Safer frame/API checks for Classic clients (nil-guarded UI access).

## 0.2.1
### Added
- Info window with addon details, shown via a help button on the split dialog title bar.

## 0.2.0
### Added
- Merchant split dialog adapts to Buy/Sell actions and hides auto-split in that context.

### Changed
- Auto-split keeps results within the bank scope for personal bank views (including Baganator).
- Split quantity now clamps to a minimum of 1.

## 0.1.13
- Previous release.
