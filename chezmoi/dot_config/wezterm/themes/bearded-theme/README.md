# Bearded Theme for WezTerm

This directory contains WezTerm color schemes converted from the Bearded Theme VS Code extension.

## Available Themes

All 75 Bearded Theme variants are available as WezTerm TOML color schemes:

- **Monokai Variants**: Bearded Theme Monokai Metallian, Bearded Theme Monokai Terra, Bearded Theme Monokai Stone, Bearded Theme Monokai Black, Bearded Theme Monokai Reversed
- **Solarized Variants**: Bearded Theme Solarized Dark, Bearded Theme Solarized Light, Bearded Theme Solarized Reversed  
- **Arc Variants**: Bearded Theme Arc Blueberry, Bearded Theme Arc Eggplant, Bearded Theme Arc Eol Storm, Bearded Theme Arc Reversed
- **Oceanic Variants**: Bearded Theme Oceanic, Bearded Theme Oceanic Reversed
- **Black & Color Variants**: Bearded Theme Black Amethyst, Bearded Theme Black Diamond, Bearded Theme Black Emerald, Bearded Theme Black Gold, Bearded Theme Black Ruby (with soft versions)
- **Milkshake Variants**: Bearded Theme Milkshake Vanilla, Bearded Theme Milkshake Blueberry, Bearded Theme Milkshake Mango, Bearded Theme Milkshake Mint, Bearded Theme Milkshake Raspberry
- **High Contrast Variants**: Bearded Theme Hc Ebony, Bearded Theme Hc Midnight Void, Bearded Theme Hc Wonderland Wood, etc.
- **Vivid Variants**: Bearded Theme Vivid Black, Bearded Theme Vivid Light, Bearded Theme Vivid Purple
- **Stained Variants**: Bearded Theme Stained Blue, Bearded Theme Stained Purple
- **And many more!**

## Installation

### Option 1: Individual Theme

1. Copy your desired theme file to your WezTerm configuration directory
2. Add to your `~/.wezterm.lua`:

```lua
local wezterm = require 'wezterm'
local config = {}

config.color_scheme = 'Bearded Theme Monokai Metallian'  -- Use the theme name from metadata

return config
```

### Option 2: All Themes

1. Copy the entire `wezterm-themes` directory to your WezTerm configuration location
2. Add the themes directory to your config:

```lua
local wezterm = require 'wezterm'
local config = {}

-- Add the bearded themes directory
config.color_scheme_dirs = { '/path/to/wezterm-themes' }

-- Set your desired theme
config.color_scheme = 'Bearded Theme Monokai Metallian'

return config
```

## Theme Features

Each WezTerm theme includes:

- **ANSI Colors**: Full 16-color palette with normal and bright variants
- **Cursor Colors**: Custom cursor background, border, and foreground colors
- **Selection Colors**: Highlighted text selection colors
- **Tab Bar**: Complete tab bar styling including:
  - Active/inactive tab colors
  - Hover states
  - New tab styling
  - Tab bar background
- **UI Elements**: Scrollbar, split panes, and other UI colors

## Color Mapping

The conversion maps VS Code theme colors to WezTerm equivalents:

- `terminal.foreground` → `foreground`
- `terminal.background` → `background` 
- `terminalCursor.foreground` → `cursor_bg`
- `editor.selectionBackground` → `selection_bg`
- `tab.activeBackground` → `colors.tab_bar.active_tab.bg_color`
- And many more...

## Building Themes

To rebuild the WezTerm themes from the source VS Code themes:

```bash
npm run build:wezterm
```

This will regenerate all `.toml` files in this directory from the latest VS Code theme definitions.

## Credits

- **Author**: BeardedBear
- **Source**: https://github.com/BeardedBear/bearded-theme
- **Original**: VS Code Bearded Theme extension

Enjoy your beautifully themed WezTerm! 🧔‍♂️
