# Shader Lab

`ShaderLab` is a copyable SwiftUI starter app for tuning a visual effect on iPhone, iPad, and Mac Catalyst.

## Start a new lab

1. Copy the entire `ShaderLab` directory and rename the directory, Xcode project, target, scheme, app type, and bundle identifier.
2. Add shader inputs to `ShaderSettings` in `ShaderLabDocument.swift`.
3. Add matching controls in `ShaderControlsView` in `ContentView.swift`. `LabSlider` supports linear and logarithmic scales, and `BezierCurveEditor` produces portable `Float` lookup tables for GPU upload.
4. Replace the body of `ShaderPreviewView(settings:)` with the SwiftUI shader, `MTKView`, or renderer being explored.

The preview renderer receives only `ShaderSettings`. Backgrounds and other lab-only choices remain in `PreviewSettings`, and exported JSON keeps the two groups separate.

## Included lab tools

- Linear and zero-aware logarithmic sliders with reset buttons.
- A clock-hand angle control with direct degree entry using mathematical angles: 0° points right and positive values rotate counterclockwise.
- A two-to-four-stop gradient editor with draggable stops, hex entry, and interpolated insertion.
- A reusable function Bézier editor with arbitrary point counts, per-point mirrored-handle linking, optional per-axis anchor bounds, numeric editing, pan and zoom, tangent endpoint extension, and shader-ready value and derivative lookup-table sampling.
- Solid, checkerboard, and selectable image backgrounds. Image assets appear in a thumbnail grid and are registered in `BackgroundImageAsset`. Checkerboard and image placement support click-drag and two-finger trackpad panning, trackpad pinch, keyboard nudging, and inspector scaling.
- Local autosave, reset, JSON import/export, and JSON clipboard copying.

`schemaVersion` is currently `1`. If the settings shape changes after JSON files have been shared, add an explicit decoding migration before incrementing it.

## Formatting

The template includes the same universal SwiftFormat 0.53.9 executable used by nearby projects. The accompanying `.swift-version` pins formatting behavior to Swift 6.2.4.

Run it from the project root:

```sh
./swiftformat .
```

With direnv enabled, allow the included `.envrc` once and use the project-local shortcut:

```sh
direnv allow
swf
```
