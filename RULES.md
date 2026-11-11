# Project rules

- **Required design standard:** Make the best practical effort to match macOS 27 Golden Gate 1:1 in both light and dark themes. [STYLE-GUIDE.md](STYLE-GUIDE.md) is mandatory for all visual and interaction-design changes, including changes to settings, menus, the dock, launcher, widgets, and window treatments.
- Before implementing a visual change, consult an actual reference for the corresponding macOS surface and record the reference used. Before considering it finished, compare screenshots of the result against that reference in both appearances where applicable, follow the acceptance checklist in the style guide, and report any unverified or intentionally different behavior. If a screenshot or comparison is not possible, state that explicitly; do not claim visual acceptance.
- When user feedback rejects a design, treat that as an acceptance failure: investigate the reference and revise the implementation rather than merely relabeling it as macOS-like. The user's explicit preferences and requested exceptions take precedence over the reference.
- Treat both Golden Gate appearances as a pair. Keep their shared controls, dock, launcher and desktop widgets functional.
- Edit the source in this repository, not packaged files under `/usr/share/omarchy`.
- The user's `~/.config/omarchy` theme, plugin and hook paths point into this repository. Changes can affect the live desktop; preserve user preferences and do not replace unrelated configuration.
- Preserve the user's wallpaper, dock pins, window transparency and current theme when testing. Theme reapplication can cycle the current wallpaper; save and restore it explicitly.
- Do not overwrite or remove existing configuration, user changes, or files without understanding their ownership and asking where necessary.
- Test shared scripts with `python3 -m unittest discover -s tests -v`. After Hyprland changes run `hyprctl reload` and check `hyprctl configerrors`.
- Omarchy's plugin watcher does not recursively follow symlinked plugin directories. After editing a plugin, run `omarchy-shell shell rescanPlugins` or `omarchy restart shell`, and check the shell log for errors.
- Aim for 1:1 visual fidelity, but do not claim pixel-perfect fidelity or native macOS behavior without evidence. Menus operate Linux actions; do not add fake or misleading controls to imitate unsupported features.
- `~/.config/hypr/hyprland.lua` contains an additional theme-specific floating-workspace transparency block; see `docs/deployment.md` before changing or reinstalling it.
