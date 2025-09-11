# Ensure Chocolatey is available
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found. Please install Chocolatey first: https://chocolatey.org/install"
    exit 1
}

# Ensure chezmoi is installed
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Host "chezmoi not found, installing via Chocolatey..."
    choco install chezmoi -y
} else {
    Write-Host "chezmoi is already installed."
}

# Define chezmoi config dir + file (standard location)
$chezmoiConfigDir = Join-Path $HOME ".config\chezmoi"
$chezmoiConfigFile = Join-Path $chezmoiConfigDir "chezmoi.yaml"

# Ensure config directory exists
if (-not (Test-Path $chezmoiConfigDir)) {
    New-Item -ItemType Directory -Path $chezmoiConfigDir -Force | Out-Null
    Write-Host "Created $chezmoiConfigDir"
}

# Define repo source dir
$repoPath = Join-Path $HOME "xconfig\chezmoi"

# Write chezmoi.yaml config
$yamlContent = @"
sourceDir: $repoPath
"@
Set-Content -Path $chezmoiConfigFile -Value $yamlContent -Encoding UTF8
Write-Host "Wrote chezmoi config to $chezmoiConfigFile"

# Apply chezmoi configs
chezmoi apply

Write-Host "chezmoi initialized and applied with source at $repoPath"
