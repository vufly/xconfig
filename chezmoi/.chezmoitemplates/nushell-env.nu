# env.nu
#
# Installed by:
# version = "0.112.2"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.
let mise_path = $nu.default-config-dir | path join mise.nu
^mise activate nu | save $mise_path --force

zoxide init nushell --cmd cd | save -f ~/.zoxide.nu

# Generate before config.nu is parsed; mise activation is loaded there.
let atuin_path = $nu.default-config-dir | path join atuin.nu
# Keep Up Arrow for shell history and Ctrl+R for Atuin.
^mise exec -- atuin init nu --disable-up-arrow | save --force $atuin_path
