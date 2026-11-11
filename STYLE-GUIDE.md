# Golden Gate design and acceptance guide

This guide is mandatory under [RULES.md](RULES.md). Its goal is the closest practical 1:1 reproduction of macOS 27 Golden Gate, not merely a generic rounded or translucent Linux theme. Apply it to both appearances and all themed surfaces, while preserving working Omarchy features and the user's explicit choices.

## Reference first

1. Find a real macOS 27 screenshot or Apple documentation for the **specific surface** being changed. Prefer the same appearance, page, and window state. If an exact Golden Gate reference is unavailable, use the closest macOS reference and say so.
2. Note the reference URL, what it shows, and any differences required by Linux or the user's request. Compare the full composition as well as individual details; do not infer an exact design from the word “macOS.”
3. Use these starting points, then seek a more specific reference where needed:
   - [512 Pixels: macOS 27 Golden Gate screenshot library](https://512pixels.net/projects/aqua-screenshot-library/macos-27-golden-gate/) — System Settings, menus, desktop, Dock, and apps.
   - [Apple: light and dark appearance](https://support.apple.com/guide/mac-help/use-a-light-or-dark-appearance-mchl52e1c2d2/mac) — appearance choices and behavior.
   - [Apple: Desktop & Dock settings](https://support.apple.com/guide/mac-help/mchlp1119/mac) — control labels and behavior.

References guide the design; do not copy copyrighted assets or proprietary fonts without the right to use them. Prefer available system fonts, locally created artwork, and properly attributed assets.

## Visual design

- **Overall:** Match the reference's proportions, alignment, density, hierarchy, layering, spacing, and screen placement before polishing individual controls. Avoid unrelated decorative flourishes and arbitrary accent colors.
- **Light and dark:** Adapt every relevant surface, separator, icon, control, hover/selection state, and text color to its appearance. Preserve contrast and readability over each supported wallpaper; translucency must not make content illegible.
- **Materials:** Follow the reference's restrained Liquid Glass treatment, blur, opacity, subtle highlights, shadows, and rounded geometry. A dark surface should not acquire a bright outline by default. Respect the user's transparency and border settings rather than overriding them for appearance.
- **Typography and icons:** Match macOS's compact, proportional system typography and icon scale as closely as available fonts and assets permit. Do not use a terminal-style monospace font for general interface text unless the reference calls for it. Keep labels legible and prevent clipping.
- **Menu bar and menus:** Match the reference's bar height, item spacing, alignment, menu shape, separators, selection colors, and visual hierarchy. Maintain contrast against the desktop and keep all existing useful bar widgets, including Agents, accessible.
- **Settings:** Use the reference's sidebar, traffic-light placement, navigation, grouped rows, appearance previews, and native-looking controls. Controls should reflect their actual state; supported options should be easy to find without imitating unsupported options.
- **Dock and launcher:** Match the reference's positioning, icon sizing and spacing, surface shape, search placement, and selection treatment. Preserve app launching, searching, pinning, dragging, position, size, visibility, and the user's outline preference.
- **Windows and widgets:** Match the reference's corner treatment, borders, widget proportions, and light/dark colors as far as the compositor and apps allow. Do not change unrelated applications or global settings without the user's authorization.

## Behavior and honest differences

- All visible controls must perform the action described and reflect the real state. Do not add inert or misleading macOS controls solely to fill space.
- Linux menus, applications, compositor behavior, and available system services are not macOS. When a native action has no equivalent, omit it, provide a clearly named working alternative, or explain the limitation; do not silently break an existing action.
- Keep keyboard, pointer, scrolling, accessibility, and existing user workflows usable. User-specified settings override resemblance to the reference.
- Do not replace, remove, or silently hide useful existing widgets or capabilities to achieve a closer screenshot.

## Required acceptance checklist

For each visual or interaction-design change:

1. Identify the specific macOS reference and compare the implementation against it, including proportions, color, typography, spacing, corners, borders, translucency, and selected/hover states relevant to the change.
2. Capture and inspect the result in **both light and dark**, when the change affects both. Also check a representative background and a realistic window size; check the affected states and controls, not only the default view.
3. Exercise the changed controls and the existing workflows they touch. Run the repository tests and applicable shell/Hyprland checks specified by [RULES.md](RULES.md). Preserve and restore the user's theme, wallpaper, transparency, and dock settings during testing.
4. Report the reference, what was verified, and any material deviations or checks that could not be performed. A screenshot or passing test is evidence of what was checked, not proof of pixel-perfect fidelity or user approval.
5. If the user rejects visual acceptance, treat the work as unfinished and revise against the reference.
