# ActionGesture

[简体中文](README_ZH.md)

ActionGesture adds single-press, double-press, and long-press assignments to the iPhone Action Button.

It uses Apple's original Action Button settings page and native action list, including Nothing. System actions such as Flashlight, Silent Mode, Camera, and Shortcuts continue to work as usual.

## Features

- Separate actions for single press, double press, and long press
- Optional orientation-based assignments
- Supports screen up, screen down, upright, upside down, left landscape, and right landscape
- Up to 18 assignments when orientation mode is enabled
- Unset orientations follow the upright action for the same gesture
- Disabling orientation mode does not remove saved assignments
- English, Simplified Chinese, Traditional Chinese, Vietnamese, and Arabic localizations

## Usage

After installation, open:

```text
Settings > Action Button
```

Use the menus in the top-right corner to choose the gesture and orientation you want to edit, then select an action from the native list below.

## Packages

Running `releases.sh` creates three packages in `packages/`:

| File | Jailbreak environment |
| --- | --- |
| `ActionGesture_0.0-3-arm.deb` | rootful |
| `ActionGesture_0.0-3-arm64.deb` | rootless |
| `ActionGesture_0.0-3-arm64e.deb` | RootHide |

Requires an iPhone with an Action Button running iOS 17 or later.

## Building

Build all three packages:

```sh
./releases.sh
```

Build a single package:

```sh
# rootful
make package FINALPACKAGE=1

# rootless
make package SCHEME=rootless FINALPACKAGE=1

# RootHide
make package SCHEME=roothide FINALPACKAGE=1
```
