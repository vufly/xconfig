#!/usr/bin/env pwsh

# Implementation contract: ~/o24/scripts/README.md

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($args.Count -eq 0) {
    $layoutName = "portal_main"
}
elseif ($args.Count -eq 1 -and $args[0] -eq "--task") {
    $layoutName = "portal_task"
}
else {
    throw "Usage: zportal [--task]"
}

$layoutPath = Join-Path $HOME "o24\zellij\$layoutName.kdl"
if (-not (Test-Path -LiteralPath $layoutPath -PathType Leaf)) {
    throw "zportal: layout not found: $layoutPath"
}

$layout = Get-Content -LiteralPath $layoutPath -Raw
if (-not $layout.Contains("__ZPORTAL_CWD__")) {
    throw "zportal: cwd placeholder missing from $layoutPath"
}

$cwd = (Get-Location).Path
$escapedCwd = $cwd.Replace("\", "\\").Replace('"', '\"').Replace("`n", "\n").Replace("`r", "\r").Replace("`t", "\t")
$layout = $layout.Replace("__ZPORTAL_CWD__", $escapedCwd)

& zellij action override-layout --apply-only-to-active-tab --layout-string $layout
exit $LASTEXITCODE
