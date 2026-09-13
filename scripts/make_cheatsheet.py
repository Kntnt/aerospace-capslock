"""Rebuild the one-page English reference; validate it against the bundled bindings."""
from pathlib import Path
import tomllib

from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Table, TableStyle, Paragraph
from reportlab.lib.styles import ParagraphStyle
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/cheatsheet.pdf"
bindings = tomllib.loads((ROOT / "aerospace.toml").read_text())["mode"]["main"]["binding"]

ghostty_settings = (ROOT / "ghostty.conf").read_text()
assert "keybind = super+t=new_window" in ghostty_settings

def expect(key, command):
    assert bindings[key].startswith(command + ";"), (key, bindings[key])


for direction, navigation_key in [("left", "home"), ("right", "end"), ("up", "pageUp"), ("down", "pageDown")]:
    expect("ctrl-alt-cmd-" + direction, "focus " + direction)
    expect("ctrl-alt-cmd-shift-" + direction, "move " + direction)
    expect("ctrl-alt-cmd-" + navigation_key, "join-with " + direction)
    expect("ctrl-alt-cmd-shift-" + navigation_key, "swap " + direction)

layout_rows = [
    ("Ctrl+Opt+Cmd + L", "Switch tiles / accordion in the current group", "ctrl-alt-cmd-l", "layout tiles accordion"),
    ("Ctrl+Opt+Cmd + R", "Rotate the group: horizontal / vertical", "ctrl-alt-cmd-r", "layout horizontal vertical"),
    ("Ctrl+Opt+Cmd + F", "Fill the workspace / restore", "ctrl-alt-cmd-f", "fullscreen"),
    ("Ctrl+Opt+Cmd + Shift + F", "Float this window / return it to tiling", "ctrl-alt-cmd-shift-f", "layout floating tiling"),
    ("Ctrl+Opt+Cmd + N", "Normalize window sizes", "ctrl-alt-cmd-n", "balance-sizes"),
    ("Ctrl+Opt+Cmd + Tab", "Previous workspace and back", "ctrl-alt-cmd-tab", "workspace-back-and-forth"),
    ("Ctrl+Opt+Cmd + Backspace", "Remove ALL grouping on this workspace", "ctrl-alt-cmd-backspace", "flatten-workspace-tree"),
    ("Ctrl+Opt+Cmd + comma (,)", "Give the window less space", "ctrl-alt-cmd-comma", "resize smart -50"),
    ("Ctrl+Opt+Cmd + period (.)", "Give the window more space", "ctrl-alt-cmd-period", "resize smart +50"),
]
for _, _, key, command in layout_rows:
    expect(key, command)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
pdfmetrics.registerFont(TTFont("Body", "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"))
pdfmetrics.registerFont(TTFont("Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
width, height = A4
margin = 36
usable = width - 2 * margin
canvas = Canvas(str(OUTPUT), pagesize=A4)
canvas.setTitle("AeroSpace Harmony - Cheat sheet")
canvas.setAuthor("Kntnt")
y = height - margin


def line(text, size=11, font="Body", gap=16):
    global y
    canvas.setFont(font, size)
    canvas.drawString(margin, y - size, text)
    y -= gap


def heading(text):
    global y
    y -= 7
    line(text, 12, "Bold", 20)


def table(rows, widths, header=True):
    global y
    style = ParagraphStyle("Cell", fontName="Body", fontSize=10.5, leading=13)
    bold = ParagraphStyle("Head", parent=style, fontName="Bold")
    data = [[Paragraph(cell, bold if header and i == 0 else style) for cell in row] for i, row in enumerate(rows)]
    t = Table(data, colWidths=widths)
    rules = [
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LINEBELOW", (0, 0), (-1, -1), 0.35, colors.HexColor("#cccccc")),
    ]
    if header:
        rules.append(("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#eeeeee")))
    t.setStyle(TableStyle(rules))
    _, th = t.wrap(usable, 800)
    t.drawOn(canvas, margin, y - th)
    y -= th


line("AeroSpace Harmony", 25, "Bold", 32)
line("Hold Control + Option + Command. Add Shift to bring/move a window.", 10.5, "Bold", 19)
line("Optional: map Caps Lock to these three modifiers, with Shift left out.", 10.5, gap=20)
table([["Ctrl+Opt+Cmd + Escape", "Pause / resume tiling"]], [200, usable - 200], False)

heading("Apps and workspaces")
rows = [["Key", "Ctrl+Opt+Cmd + key", "Ctrl+Opt+Cmd + Shift + key"]]
for letter, app in [("B", "Default browser"), ("C", "Claude"), ("E", "Sublime Text"), ("G", "ChatGPT"), ("M", "Typora"), ("S", "Spotify"), ("T", "Ghostty")]:
    assert f"launch {letter.lower()} " in bindings[f"ctrl-alt-cmd-shift-{letter.lower()}"]
    expect(f"ctrl-alt-cmd-{letter.lower()}", f"workspace {letter}")
    rows.append([letter, "Show workspace " + letter, app + " in " + letter])
for number in "0123456789":
    expect("ctrl-alt-cmd-shift-" + number, "move-node-to-workspace --focus-follows-window " + number)
    expect("ctrl-alt-cmd-" + number, "workspace " + number)
rows.append(["0-9", "Show workspace 0-9", "Move this window there and follow"])
table(rows, [57, 196, usable - 253])
y -= 5
line("Add Shift to open/activate the app. Focus and the pointer follow.", 10, gap=14)

heading("Arrows: ← ↓ ↑ →")
table([
    ["Shortcut", "Action in the arrow’s direction"],
    ["Ctrl+Opt+Cmd + arrow", "Move focus"],
    ["Ctrl+Opt+Cmd + Shift + arrow", "Move the window / move it out of a group"],
    ["Ctrl+Opt+Cmd + Fn + arrow", "Group with the neighboring node"],
    ["Ctrl+Opt+Cmd + Shift + Fn + arrow", "Swap places with the neighboring window"],
], [218, usable - 218])

heading("Layout and switching")
table([["Shortcut", "Action"]] + [[a, b] for a, b, _, _ in layout_rows], [218, usable - 218])
heading("Ghostty: separate windows (Command shortcuts)")
table([
    ["Cmd + N / Cmd + T", "New terminal window"],
    ["Cmd + Shift + comma", "Reload Ghostty configuration"],
], [218, usable - 218], False)

y -= 7
line("Fn + ← / → / ↑ / ↓ sends Home / End / Page Up / Page Down on Mac keyboards.", 9.7, gap=14)
line("Accordion: Left/Right in a horizontal group; Up/Down in a vertical group.", 9.7, gap=14)
line("Pause reveals hidden workspace windows. No windows are closed.", 9.7, gap=14)
assert y >= 28, y
canvas.showPage()
canvas.save()
reader = PdfReader(OUTPUT)
assert len(reader.pages) == 1
text = reader.pages[0].extract_text()
for phrase in ["Ctrl+Opt+Cmd + Shift + Fn + arrow", "Ctrl+Opt+Cmd + comma (,)", "Ctrl+Opt+Cmd + period (.)", "Ctrl+Opt+Cmd + Escape", "Cmd + N / Cmd + T", "Cmd + Shift + comma"]:
    assert phrase in text
print(OUTPUT)
print("One A4 page. Text and shortcuts checked against the configuration.")
