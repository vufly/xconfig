# function Invoke-Starship-PreCommand {
#   $title = "PS "
#   $title += Split-Path -Leaf $pwd
#   $host.ui.RawUI.WindowTitle = $title
# }
# Invoke-Expression (&starship init powershell)

# --- Chocolatey tab completion ---
# $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
# if (Test-Path($ChocolateyProfile)) {
#   Import-Module "$ChocolateyProfile"
# }
function choco {
    if (-not (Get-Module -Name chocolateyProfile -ListAvailable)) {
        $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
        if (Test-Path $ChocolateyProfile) {
            Import-Module $ChocolateyProfile
        }
    }
    Microsoft.PowerShell.Core\Invoke-Expression ("choco " + ($args -join ' '))
}

# --- PSReadLine setup ---
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History

# --- Utilities and aliases ---
Import-Module git-aliases -DisableNameChecking

# Remove built-in alias
if (Get-Alias ls -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -ErrorAction SilentlyContinue
}

# Detect if eza is installed
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ls {
        eza
    }

    function lsi {
        eza --icons
    }
}
else {
    # Fall back to default Get-ChildItem
    Set-Alias ls Get-ChildItem
}

function gitzip {
    $name = Split-Path -Leaf (Get-Location)
    git archive HEAD -o "$name.zip"
}

function gitsf {
    git submodule update --init --recursive
}

function gitsp {
    git submodule foreach --recursive "git pull origin master"
}

# --- Mise runtime ---
mise activate pwsh | Out-String | Invoke-Expression

# --- Force UTF-8 Encoding ---
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# --- Oh My Posh initialization ---
oh-my-posh init pwsh --config "~/.theme.omp.toml" | Invoke-Expression

# --- Zoxide integration ---
# Initialize zoxide hooks for PowerShell
(& { (zoxide init powershell --cmd cd | Out-String) }) | Invoke-Expression

# Wrap the existing prompt safely (Oh My Posh owns the prompt)
if (-not (Test-Path Function:\_original_prompt)) {
    Rename-Item Function:\prompt _original_prompt
}

function global:prompt {
    # Let zoxide learn current directory
    & zoxide add "$(Get-Location)" | Out-Null

    # Then call the original Oh My Posh prompt
    _original_prompt
}
