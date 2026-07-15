$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$action = if ($args.Count -gt 0) { $args[0] } else { "" }
$packageId = "9PLM9XGG6VKS"
$notFound = -1978335212
$noUpgrade = -1978335189
$commonArguments = @(
    "--id", $packageId,
    "--exact",
    "--source", "msstore",
    "--accept-source-agreements",
    "--disable-interactivity"
)

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("winget is required to manage ChatGPT.")
    exit 1
}

switch ($action) {
    "check" {
        & winget list @commonArguments | Out-Null
        if ($LASTEXITCODE -eq 0) { exit 0 }
        if ($LASTEXITCODE -eq $notFound) { exit 10 }
        [Console]::Error.WriteLine("Could not query the ChatGPT installation.")
        exit 1
    }
    "install" {
        & winget install @commonArguments --accept-package-agreements | Out-Host
        exit $LASTEXITCODE
    }
    "upgrade" {
        & winget upgrade @commonArguments --accept-package-agreements | Out-Host
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $noUpgrade) { exit 0 }
        exit $LASTEXITCODE
    }
    "uninstall" {
        & winget uninstall @commonArguments | Out-Host
        exit $LASTEXITCODE
    }
    default {
        [Console]::Error.WriteLine("Usage: $($MyInvocation.MyCommand.Name) check|install|upgrade|uninstall")
        exit 2
    }
}
