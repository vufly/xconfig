param(
    [string]$Machine = $env:COMPUTERNAME
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Join-Path $repoRoot "chezmoi"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "init-chezmoi.ps1 must run from an elevated PowerShell session."
    exit 1
}

function Update-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Add-UserPathEntry {
    param([Parameter(Mandatory)][string]$Path)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($userPath -split ";" | Where-Object { $_ })
    if ($entries -notcontains $Path) {
        $newPath = (@($entries) + $Path) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }
    Update-ProcessPath
}

function Install-ChocolateyPackage {
    param([Parameter(Mandatory)][string]$Name)

    & choco.exe install $Name --yes --no-progress
    if ($LASTEXITCODE -notin 0, 1641, 3010) {
        throw "$Name installation failed with exit code $LASTEXITCODE."
    }
}

if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((Invoke-WebRequest -UseBasicParsing "https://community.chocolatey.org/install.ps1").Content)
    Update-ProcessPath
}

if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    throw "Chocolatey was installed but is not available in PATH. Start a new PowerShell session and rerun this script."
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Host "Installing chezmoi through Chocolatey..."
    Install-ChocolateyPackage chezmoi
    Update-ProcessPath
}

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    Write-Host "Installing mise through Chocolatey..."
    Install-ChocolateyPackage mise
    Update-ProcessPath
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    throw "chezmoi was installed but is not available in PATH. Start a new PowerShell session and rerun this script."
}
if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    throw "mise was installed but is not available in PATH. Start a new PowerShell session and rerun this script."
}

Write-Host "Updating mise..."
mise self-update --yes
if ($LASTEXITCODE -ne 0) { throw "mise self-update failed." }

$miseShims = Join-Path $env:USERPROFILE "AppData\Local\mise\shims"
Add-UserPathEntry $miseShims

if ($Machine -notmatch '^[A-Za-z0-9._-]+$') {
    throw "Machine ID may contain only letters, numbers, dot, underscore, and hyphen."
}

$overrideData = @{ machine = $Machine } | ConvertTo-Json -Compress
chezmoi --source $sourceDir execute-template --override-data $overrideData '{{ includeTemplate ".chezmoitemplates/xpack-records" . }}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Package declaration failed to render for machine '$Machine'."
}

$configDir = Join-Path $HOME ".config\chezmoi"
$configFile = Join-Path $configDir "chezmoi.yaml"
New-Item -ItemType Directory -Path $configDir -Force | Out-Null

$yamlSourceDir = $sourceDir.Replace("\", "/").Replace("'", "''")
$yamlMachine = $Machine.Replace("'", "''")
@"
sourceDir: '$yamlSourceDir'
data:
  machine: '$yamlMachine'
"@ | Set-Content -LiteralPath $configFile -Encoding utf8

Write-Host "Applying chezmoi configuration for machine $Machine..."
chezmoi apply
if ($LASTEXITCODE -ne 0) { throw "chezmoi apply failed." }

Write-Host "Configuration applied. Run '& `"$HOME/scripts/xpack.ps1`" status', then '& `"$HOME/scripts/xpack.ps1`" sync'."
