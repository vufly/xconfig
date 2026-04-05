-- Example WezTerm configuration using Bearded Theme
-- Place this file in ~/.wezterm.lua or your WezTerm config directory

local wezterm = require 'wezterm'
local config = {}

-- Add the bearded themes directory (adjust path as needed)
config.color_scheme_dirs = { '/path/to/bearded-theme/wezterm-themes' }

-- Set your desired theme - choose from any of the 75 available themes:
-- "Bearded Theme Vanilla", "Bearded Theme Monokai Metallian", "Bearded Theme Solarized Dark", "Bearded Theme Arc Blueberry",
-- "Bearded Theme Oceanic", "Bearded Theme Black Amethyst", "Bearded Theme Vivid Purple", etc.
config.color_scheme = 'Bearded Theme Monokai Metallian'

-- Optional: Configure tab bar style
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false

-- Optional: Configure window appearance
config.window_background_opacity = 1.0
config.window_padding = {
  left = 10,
  right = 10,
  top = 10,
  bottom = 10,
}

return config
