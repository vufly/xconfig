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
if ($Host.Name -eq 'ConsoleHost' -and $ExecutionContext.SessionState.LanguageMode -eq 'FullLanguage') {
    try {
        Set-PSReadLineOption -PredictionSource History
    } catch {}
}

# --- PSFzf ---
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
$commandOverride = [ScriptBlock]{ param($Location) Write-Host $Location }
Set-PsFzfOption -AltCCommand $commandOverride
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
Set-PsFzfOption -TabExpansion

# --- Utilities and aliases ---
Import-Module git-aliases -DisableNameChecking

function Get-GitAliasCommand {
    $exclude = @(
        'Get-Git-CurrentBranch',
        'Get-Git-MainBranch',
        'Get-Git-Aliases'
    )

    Get-Command -Module git-aliases -CommandType Function |
        Where-Object { $_.Name -notin $exclude } |
        Sort-Object Name |
        ForEach-Object {
            [PSCustomObject]@{
                Name       = $_.Name
                Definition = ($_.Definition -replace '\s+', ' ').Trim()
            }
        }
}

function ilias {
    $selected = Get-GitAliasCommand |
        ForEach-Object { "$($_.Name)`t$($_.Definition)" } |
        fzf --height 40% --prompt 'alias> '

    if (-not $selected) { return }

    $name = ($selected -split "`t", 2)[0]
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$name ")
}

Set-PSReadLineKeyHandler -Chord 'Alt+a' -ScriptBlock { ilias }

function theme {
    & "$HOME/scripts/set-theme.ps1" @args
}

$global:BW_SESSION_FILE = Join-Path ([System.IO.Path]::GetTempPath()) "bw-session.txt"

function bwu {
    $session = bw unlock --raw
    if ($LASTEXITCODE -ne 0) { return }
    Set-Content -Path $global:BW_SESSION_FILE -Value $session -NoNewline
    $env:BW_SESSION = $session
}

function bwload {
    if (Test-Path $global:BW_SESSION_FILE) {
        $env:BW_SESSION = Get-Content $global:BW_SESSION_FILE -Raw
    }
}

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

# --- tmux aliases ---
function t {
    & tmux $args
}

function ta {
    & tmux a -t $args
}

function tls {
    & tmux ls $args
}

function tn {
    & tmux new -t $args
}

function tk {
    & tmux kill-session -t $args
}

function tka {
    tmux list-sessions -F "#{session_name}" | Where-Object { $_ } | ForEach-Object {
        & tmux kill-session -t $_
    }
}

function trs {
    & tmux source-file "$HOME/.tmux.conf"
}

# --- zellij aliases ---
function z {
    & zellij $args
}

function za {
    & zellij attach $args --force-run-commands
}

function zls {
    & zellij ls $args
}

function zn {
    & zellij -s $args
}

function zk {
    & zellij kill-session $args
}

function zka {
    & zellij kill-all-sessions
}

# --- git aliases ---
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
$LSColorsPath = Join-Path $HOME ".config/LS_COLORS"
if (Test-Path $LSColorsPath) {
    $env:LS_COLORS = (Get-Content -Raw $LSColorsPath).Trim()
}

# --- Force UTF-8 Encoding ---
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# --- Oh My Posh initialization ---
# oh-my-posh init pwsh --config "~/.theme.omp.toml" | Invoke-Expression

# --- Cailoxo prompt initialization ---
$CailoxoPromptPath = Join-Path $HOME ".config/powershell/prompt.txt"
if (Test-Path $CailoxoPromptPath) {
    Get-Content $CailoxoPromptPath -Raw | Invoke-Expression
}

# --- Zoxide integration ---
# Initialize zoxide hooks for PowerShell
(& { (zoxide init powershell --cmd cd | Out-String) }) | Invoke-Expression

# Wrap the existing prompt safely (Cailoxo owns the prompt)
if (Test-Path Function:\prompt) {
    if (Test-Path Function:\_cailoxo_prompt) {
        Remove-Item Function:\_cailoxo_prompt -Force
    }
    Rename-Item Function:\prompt _cailoxo_prompt
}

function global:prompt {
    bwload
    # Let zoxide learn current directory
    & zoxide add "$(Get-Location)" | Out-Null

    # Then call the Cailoxo prompt
    _cailoxo_prompt
}
