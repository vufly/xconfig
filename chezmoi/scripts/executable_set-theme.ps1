#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("dark", "light")]
    [string]$Theme
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$managedConfigHome = if ($env:XDG_CONFIG_HOME) {
    $env:XDG_CONFIG_HOME
}
else {
    Join-Path $HOME ".config"
}

switch ($Theme) {
    "dark" {
        $batThemeName = "bearded-theme-monokai-stone"
        $deltaModeKey = "dark"
        $deltaThemeName = "bearded-theme-monokai-stone"
    }
    "light" {
        $batThemeName = "bearded-theme-milkshake-vanilla"
        $deltaModeKey = "light"
        $deltaThemeName = "bearded-theme-milkshake-vanilla"
    }
}

$themeComment = "# This line is updated manually by ~/scripts/set-theme.sh."
$deltaComment = "  # These values are updated manually by ~/scripts/set-theme.sh."

function Get-UniquePaths {
    param(
        [string[]]$Paths
    )

    $seen = @{}
    foreach ($path in $Paths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        $fullPath = [System.IO.Path]::GetFullPath($path)
        if ($seen.ContainsKey($fullPath)) {
            continue
        }

        $seen[$fullPath] = $true
        $fullPath
    }
}

function Write-Lines {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $encoding)
}

function Update-BatConfig {
    param(
        [string]$Path,
        [string]$ThemeName
    )

    $existingLines = if (Test-Path -LiteralPath $Path) {
        [string[]](Get-Content -LiteralPath $Path)
    }
    else {
        @()
    }

    $updatedLines = New-Object System.Collections.Generic.List[string]
    $foundTheme = $false

    foreach ($line in $existingLines) {
        if ($line -like "--theme=*") {
            $updatedLines.Add('--theme="' + $ThemeName + '"')
            $foundTheme = $true
            continue
        }

        $updatedLines.Add($line)
    }

    if (-not $foundTheme) {
        $updatedLines.Add('--theme="' + $ThemeName + '"')
    }

    Write-Lines -Path $Path -Lines $updatedLines.ToArray()
}

function Update-HelixConfig {
    param(
        [string]$Path,
        [string]$ThemeName
    )

    $existingLines = if (Test-Path -LiteralPath $Path) {
        [string[]](Get-Content -LiteralPath $Path)
    }
    else {
        @()
    }

    $updatedLines = New-Object System.Collections.Generic.List[string]
    $foundTheme = $false

    foreach ($line in $existingLines) {
        if ($line -match '^theme\s*=') {
            $updatedLines.Add('theme = "' + $ThemeName + '"')
            $foundTheme = $true
            continue
        }

        $updatedLines.Add($line)
    }

    if (-not $foundTheme) {
        if ($updatedLines.Count -gt 0) {
            $updatedLines.Add("")
        }
        $updatedLines.Add("# --- THEME ---")
        $updatedLines.Add($themeComment)
        $updatedLines.Add('theme = "' + $ThemeName + '"')
    }

    Write-Lines -Path $Path -Lines $updatedLines.ToArray()
}

function Update-GitConfig {
    param(
        [string]$Path,
        [string]$ModeKey,
        [string]$ThemeName
    )

    $existingLines = if (Test-Path -LiteralPath $Path) {
        [string[]](Get-Content -LiteralPath $Path)
    }
    else {
        @()
    }

    $updatedLines = New-Object System.Collections.Generic.List[string]
    $foundDelta = $false
    $inDelta = $false

    foreach ($line in $existingLines) {
        if ($line -eq "[delta]") {
            $foundDelta = $true
            $inDelta = $true
            $updatedLines.Add($line)
            $updatedLines.Add($deltaComment)
            $updatedLines.Add("  $ModeKey = true")
            $updatedLines.Add('  syntax-theme = "' + $ThemeName + '"')
            continue
        }

        if ($line -match '^\[.*\]$') {
            $inDelta = $false
        }

        if ($inDelta) {
            $trimmedLine = $line.TrimStart()
            if (
                $trimmedLine -match '^(dark|light)\s*=' -or
                $trimmedLine -match '^syntax-theme\s*=' -or
                $trimmedLine -eq '# These values are updated manually by ~/scripts/set-theme.sh.'
            ) {
                continue
            }
        }

        $updatedLines.Add($line)
    }

    if (-not $foundDelta) {
        if ($updatedLines.Count -gt 0) {
            $updatedLines.Add("")
        }
        $updatedLines.Add("[delta]")
        $updatedLines.Add($deltaComment)
        $updatedLines.Add("  $ModeKey = true")
        $updatedLines.Add('  syntax-theme = "' + $ThemeName + '"')
    }

    Write-Lines -Path $Path -Lines $updatedLines.ToArray()
}

$batConfigPaths = Get-UniquePaths @(
    if ($env:BAT_CONFIG_PATH) { $env:BAT_CONFIG_PATH }
    Join-Path $managedConfigHome "bat/config"
    if ($env:APPDATA) { Join-Path $env:APPDATA "bat/config" }
)

foreach ($path in $batConfigPaths) {
    Update-BatConfig -Path $path -ThemeName $batThemeName
}

$helixConfigPaths = Get-UniquePaths @(
    if ($env:APPDATA) { Join-Path $env:APPDATA "helix/config.toml" }
    if (-not $env:APPDATA) { Join-Path $managedConfigHome "helix/config.toml" }
)

foreach ($path in $helixConfigPaths) {
    Update-HelixConfig -Path $path -ThemeName $batThemeName
}

Update-GitConfig -Path (Join-Path $HOME ".gitconfig") -ModeKey $deltaModeKey -ThemeName $deltaThemeName
