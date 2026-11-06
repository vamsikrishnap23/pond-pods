# AirPods model icons

One folder per model. The folder name is the model name the daemon reports (`model_name` in
`~/.local/state/librepods/status.json`), lowercased with every run of other characters turned into `-`:

| Model name       | Folder           |
|------------------|------------------|
| AirPods Pro 2    | `airpods-pro-2`  |
| AirPods Pro 3    | `airpods-pro-3`  |
| AirPods 4        | `airpods-4`      |

## Adding a model

1. Create `assets/models/<model-slug>/`.
2. Add three SVGs with exactly these names:
   - `pod-left.svg`
   - `pod-right.svg`
   - `case.svg`
3. Add an `ATTRIBUTION.md` in the folder naming the author, source and licence of the icons.

That is all. `airpods/PartIcon.qml` picks the folder from the model name, so no code changes are needed.
A model with no folder shows the `airpods-pro-2` icons, and Qt logs a "Cannot open" warning for it.

## Icon requirements

- Square `viewBox`, with the artwork centred in it, so left, right and case sit evenly in the ring.
- White artwork on a transparent background. The shell tints it with the theme's text colour.
- Strokes heavy enough to stay readable at about 17px. The sidebar draws these inside a small ring.
- `fill="none"` and `stroke` paths are fine, but not `currentColor`, which Qt cannot resolve.

AirPods Max has no pods or case, so it uses Pond's headphone icon and needs no folder.
