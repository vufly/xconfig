#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sourceDir = Join-Path $HOME ".agents\skills"
$targetLink = Join-Path $HOME ".gemini\config\skills"

if (-not (Test-Path $sourceDir)) {
    New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
}

$targetParent = Split-Path -Parent $targetLink
if (-not (Test-Path $targetParent)) {
    New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
}

if (Test-Path $targetLink) {
    $item = Get-Item $targetLink -Force
    if ($item.LinkType -in @("SymbolicLink", "Junction")) {
        $targetVal = $item.Target
        if ($targetVal -and ($targetVal -eq $sourceDir -or $targetVal -contains $sourceDir)) {
            Write-Host "Skills link is already up to date: $targetLink -> $sourceDir"
            exit 0
        }
        Remove-Item $targetLink -Force
    } else {
        $timestamp = (Get-Date).ToString("yyyyMMddHHmmss")
        $backupDir = "${targetLink}.bak.${timestamp}"
        Write-Warning "Existing directory found; moving to $backupDir"
        Move-Item $targetLink $backupDir
    }
}

try {
    New-Item -ItemType SymbolicLink -Path $targetLink -Target $sourceDir -Force | Out-Null
    Write-Host "Linked (SymbolicLink): $targetLink -> $sourceDir"
} catch {
    New-Item -ItemType Junction -Path $targetLink -Target $sourceDir -Force | Out-Null
    Write-Host "Linked (Junction): $targetLink -> $sourceDir"
}
