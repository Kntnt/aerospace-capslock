# AeroSpace with Control-Option-Command

**Keep Option for typing. Give window management its own shortcuts.**

[AeroSpace](https://github.com/nikitabobko/AeroSpace) makes it possible to arrange your Mac's windows from the keyboard. Its default Option-based shortcuts can get in the way of typing symbols and special characters. This configuration uses **Control-Option-Command** together, leaving Option and Option-Shift available for typing.

**Control-Option-Command navigates; add Shift to bring or move a window.** Use letters and digits to visit workspaces, and arrows to move focus. Add Shift to launch or activate an app, move a window to a workspace, or rearrange it. No Vim shortcuts to learn, and no service mode to enter before grouping windows.

Every shortcut below can be used by holding the physical **Control, Option, and Command** keys. For a much easier reach, we recommend mapping **Caps Lock** to those three modifiers with [Hyperkey](https://hyperkey.app/) or another keyboard remapper. That is an optional convenience: **Control-Option-Command + B** becomes **Caps + B**, with exactly the same AeroSpace configuration. Keep Shift separate.

**[Download the one-page printable cheat sheet](docs/cheatsheet.pdf)** · [Configuration](aerospace.toml) · [Helper source](src/aerospace-shortcuts.swift)

## A few shortcuts to start with

- **Control-Option-Command + B** shows workspace B. **Control-Option-Command + Shift + B** opens or activates your browser, brings its selected window to B, and follows it.
- **Control-Option-Command + 2** shows workspace 2. **Control-Option-Command + Shift + 2** moves the current window there and follows it.
- **Control-Option-Command + arrow** changes focus. **Control-Option-Command + Shift + arrow** moves the window.
- **Control-Option-Command + L** switches between tiles and accordion.
- **Control-Option-Command + Escape** pauses tiling. Press it again to resume.

Focus and the pointer follow your navigation. Empty workspaces move the pointer to the monitor instead. Once these actions feel familiar, add grouping, swapping, and resizing from the cheat sheet.

## Set it up

This setup was checked with **AeroSpace 0.21.3-Beta** on macOS. It uses a QWERTY key mapping with letters, digits, punctuation, arrows, and navigation keys.

### 1. Install AeroSpace

If you use Homebrew:

```sh
brew install --cask nikitabobko/tap/aerospace
```

You can also follow the [AeroSpace installation guide](https://nikitabobko.github.io/AeroSpace/guide#installation). The helper needs the AeroSpace CLI; the build needs Apple's Command Line Tools. If those tools are missing, run `xcode-select --install` and finish Apple's installer before continuing.

In **System Settings → Privacy & Security → Accessibility**, allow AeroSpace to control windows. If AeroSpace is missing, click **+** and select `/Applications/AeroSpace.app`. Apple's [Accessibility permissions guide](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac) explains this panel.

### 2. Install the configuration and helper

Quit AeroSpace first if it is running, then:

```sh
git clone https://github.com/Kntnt/aerospace-capslock.git
cd aerospace-capslock
./install.sh --dry-run
./install.sh
```

The installer builds the Swift helper and installs:

- `~/.aerospace.toml`
- `~/.config/aerospace/bin/aerospace-shortcuts`

It backs up replaced files under `~/.config/aerospace/backups/`. It stops if your configuration is a symlink or an alternate AeroSpace config exists, so you can update your dotfiles deliberately.

Start AeroSpace from Applications. The helper starts with it, and the Control-Option-Command shortcuts are ready to use. Automatic startup is off in the supplied config; set `start-at-login = true` if you want AeroSpace to start when you sign in. After changing the helper, quit and reopen AeroSpace.

### 3. Optional: make Caps Lock your shortcut key

Holding one key is more comfortable than holding three. We recommend [Hyperkey](https://hyperkey.app/) for a simple Caps Lock setup. Install it from its website or with Homebrew:

```sh
brew install --cask hyperkey
```

Open Hyperkey and configure it as follows:

1. Select **Caps Lock** as the key to remap to Hyperkey.
2. **Turn off “Include shift in hyper key”.** Caps should send **⌃⌥⌘**: Control, Option, and Command.
3. Grant the permissions Hyperkey requests. Enable its login option if you want this mapping after signing in.

With this mapping, **Control-Option-Command + B** is **Caps + B**, and **Control-Option-Command + Shift + B** is **Caps + Shift + B**. Leaving Shift out of the mapping keeps the navigation and action layers distinct.

You can use another remapper, such as [Karabiner-Elements](https://karabiner-elements.pqrs.org/). Configure Caps Lock to hold **Control + Option + Command**, release them when Caps is released, and allow a separately held Shift key through. Karabiner supports [output modifiers](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/modifiers/) for this kind of mapping. The AeroSpace bindings need no changes when you switch remappers.

AppleScript can [simulate keystrokes and automate app interfaces](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/AutomatetheUserInterface.html). A custom Caps Lock remapper also needs to handle physical key presses and releases continuously. For that press-and-hold behavior, use a keyboard remapper; an ordinary AppleScript action is not a drop-in replacement for Hyperkey.

The installer does not change your Caps Lock mapping. The printable cheat sheet uses **Ctrl+Opt+Cmd** as a compact spelling of Control-Option-Command; you can substitute Caps wherever that prefix appears after configuring a remapper.

## Apps and workspaces

**Control-Option-Command + letter** shows the matching workspace and moves the pointer there. **Control-Option-Command + Shift + letter** launches or activates the app, moves its selected window to that workspace, and follows it with focus and the pointer. Visiting a workspace leaves the windows where they are.

| Key | Remember it as | App / workspace |
| --- | --- | --- |
| B | Browser | Your default browser → B |
| C | Claude | Claude → C |
| E | Editor | Sublime Text → E |
| G | GPT | ChatGPT → G |
| M | Markdown | Typora → M |
| S | Spotify | Spotify → S |
| T | Terminal | Ghostty → T |

The browser follows your macOS default; Firefox was used in the original setup. The other apps are explicit choices, expected in `/Applications`. To substitute your own editor, terminal, or other apps, edit the names in `appTarget` in [the helper source](src/aerospace-shortcuts.swift), then run the installer again. You only need the apps whose shortcuts you use.

**Control-Option-Command + 0–9** shows the numbered workspace and moves the pointer there. **Control-Option-Command + Shift + 0–9** moves the current window there and follows it. **Control-Option-Command + Tab** switches back and forth between the two most recent workspaces.

### Ghostty: use separate windows

Ghostty's native macOS tabs can be treated as separate windows by AeroSpace. This can leave empty space in the layout or make the terminal shrink when you switch tabs. Manually enlarging it may only last until AeroSpace reapplies the layout. The problem is [reported with Ghostty 1.3.1](https://github.com/nikitabobko/AeroSpace/discussions/2071) and tracked in AeroSpace's [native tabs issue](https://github.com/nikitabobko/AeroSpace/issues/68).

The recommended workaround for this setup is to use separate Ghostty windows and let AeroSpace arrange them. **Cmd + N** opens a window. To make the familiar **Cmd + T** do the same, add the setting from [ghostty.conf](ghostty.conf) to your existing `~/.config/ghostty/config`:

```ini
keybind = super+t=new_window
```

Press **Cmd + Shift + comma** in Ghostty to reload its configuration. This is a Ghostty setting; `install.sh` does not install it or replace your terminal configuration.

This remaps Cmd + T; the menu and tab bar can still create native tabs. Use **New Window** when opening sessions from a menu. The printable cheat sheet includes these Ghostty shortcuts in a separate section using Command directly.

For existing tabs, pause AeroSpace with **Control-Option-Command + Escape**, select a tab, and choose **Window → Move Tab to New Window**, or drag the tab out of the window. Repeat until each session has its own window, then resume AeroSpace. These are the standard [macOS tab controls](https://support.apple.com/en-gb/guide/mac-help/mchla4695cce/mac).

Use **Control-Option-Command + L** to switch the terminal windows between tiles and accordion, and **Control-Option-Command + arrows** to change focus. Each window can now be moved to its own workspace without splitting up a native tab group. If a window is still floating after the migration, focus it and use **Control-Option-Command + Shift + F** to return it to tiling.

## Arrange windows with arrows

| Shortcut | Action in the arrow's direction |
| --- | --- |
| Control-Option-Command + arrow | Focus a window |
| Control-Option-Command + Shift + arrow | Move the window, including out of its group |
| Control-Option-Command + Fn + arrow | Group with the neighboring node |
| Control-Option-Command + Shift + Fn + arrow | Swap places with the neighboring window |

For example, focus a tile and press **Control-Option-Command + Fn + Right** to group it with its neighbor on the right. Use **Control-Option-Command + L** to change that group's layout, and **Control-Option-Command + R** to change its orientation. Move a window out with **Control-Option-Command + Shift + arrow** in the appropriate direction. **Control-Option-Command + Backspace** removes *all* grouping on the workspace without closing windows.

The Fn combinations use the [Mac navigation keys](https://support.apple.com/en-us/102650): Fn + Left/Right/Up/Down becomes Home/End/Page Up/Page Down. Those are the keys AeroSpace actually binds. On a keyboard with dedicated navigation keys, use Control-Option-Command with those keys directly. Fn behavior depends on your keyboard; verify that it sends these navigation keys.

In a horizontal accordion, use Left/Right to move within the group; in a vertical accordion, use Up/Down.

## Layout and sizing

| Shortcut | Action |
| --- | --- |
| Control-Option-Command + L | Switch tiles / accordion in the current group |
| Control-Option-Command + R | Rotate the group: horizontal / vertical |
| Control-Option-Command + F | Fill the workspace / restore |
| Control-Option-Command + Shift + F | Float the current window / return it to tiling |
| Control-Option-Command + N | Balance window sizes |
| Control-Option-Command + comma (,) | Give the window less space |
| Control-Option-Command + period (.) | Give the window more space |
| Control-Option-Command + Backspace | Remove all grouping on this workspace |

The adjacent comma and period keys give resizing a simple direction: **left shrinks, right grows**. Layout shortcuts act directly; their Shift variants provide an alternative action in the same area, such as fullscreen versus floating for F.

## Pause tiling and return to a regular desktop

Press **Control-Option-Command + Escape** when you want to arrange windows freely with the mouse. This calls AeroSpace's [`enable toggle`](https://nikitabobko.github.io/AeroSpace/commands#enable): it pauses window management and reveals windows from hidden AeroSpace workspaces. Nothing is closed. Press the same shortcut again to resume tiling.

This is a pause of AeroSpace, not a conversion of its workspaces into native macOS Spaces. Its other shortcuts are inactive while paused.

The pause shortcut belongs to the small native helper, because AeroSpace releases its own shortcuts when disabled. The helper stays active during a pause and exits when AeroSpace quits. It does not install a separate login service.

If the pause shortcut does not respond, try the physical Control-Option-Command + Escape combination. If that works but Caps + Escape does not, check your remapper and make sure Shift is excluded. If neither works, quit and reopen AeroSpace so its helper can register the shortcut again. Errors are written to `~/Library/Logs/AeroSpace-shortcuts.log`. You can also resume from a terminal:

```sh
aerospace enable on
```

These modifier combinations leave common shortcuts available, but another app can still claim the same combination. If one shortcut fails, check for a conflicting global shortcut.

## Build and check

```sh
./build.sh
python3 tests/test_launch.py
```

The three launch tests use a fake browser and command-line tools to check window selection and movement without opening apps or rearranging your windows. The configuration was validated with AeroSpace 0.21.3-Beta. Fn combinations depend on your keyboard. An optional Caps mapping depends on your remapper.

To rebuild the English A4 cheat sheet on macOS, use Python 3.11 or later with ReportLab and pypdf. With [uv](https://docs.astral.sh/uv/):

```sh
uv run --with reportlab --with pypdf python scripts/make_cheatsheet.py
```

The generator checks the documented shortcuts against this repository's configuration and writes `docs/cheatsheet.pdf`.

## License

[MIT](LICENSE). AeroSpace and Hyperkey are separate projects with their own licenses.
