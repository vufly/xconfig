$ErrorActionPreference = "Stop"

$source = Join-Path $PSScriptRoot "../chezmoi"

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -cne $Expected) {
        throw "${Message}: expected '$Expected', got '$Actual'"
    }
}

# Render and parse the real Windows script, then load its definitions without dispatching a command.
$rendered = (& chezmoi --source $source --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file "$source/scripts/executable_xpack.ps1.tmpl") -join "`n"
Assert-Equal $LASTEXITCODE 0 "Windows render"
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($rendered, [ref]$tokens, [ref]$errors)
Assert-Equal $errors.Count 0 "PowerShell syntax"
$dispatch = $ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq '$command' }
. ([scriptblock]::Create($rendered.Substring(0, $dispatch.Extent.StartOffset)))

$spotify = @($packages | Where-Object Name -eq "spotify")
Assert-Equal $spotify.Count 1 "Windows Spotify count"
$spotify = $spotify[0]
Assert-Equal $spotify.Driver "winget" "Spotify driver"
Assert-Equal $spotify.Id "9NCBCSZSJRSB" "Spotify Store ID"
Assert-Equal $spotify.Source "msstore" "Spotify source"
Assert-Equal $spotify.Scope "" "Store package has no forced scope"

# Capture all manager calls: these tests never invoke a real package manager.
$script:calls = [System.Collections.Generic.List[object]]::new()
$script:queryExitCode = 0
function winget {
    $script:calls.Add(@($args))
    $global:LASTEXITCODE = $script:queryExitCode
}
function Invoke-NativeHostProcess([string]$FilePath, [string[]]$Arguments) {
    Assert-Equal $FilePath "winget" "Manager executable"
    $script:calls.Add($Arguments)
    return 0
}

Assert-Equal (Test-Package $spotify) $true "Store presence query"
Assert-Equal ($script:calls[0] -join ' ') "list --id 9NCBCSZSJRSB --exact --source msstore --accept-source-agreements --disable-interactivity" "Store query arguments"
Assert-Equal (Test-Package $spotify) $true "Cached Store presence"
Assert-Equal $script:calls.Count 1 "Presence query cache"
Install-Package $spotify
Upgrade-Package $spotify
Uninstall-Package $spotify
foreach ($index in 1..3) {
    $action = @("install", "upgrade", "uninstall")[$index - 1]
    $arguments = $script:calls[$index]
    Assert-Equal $arguments[0] $action "Lifecycle action"
    Assert-Equal $arguments[[array]::IndexOf($arguments, "--source") + 1] "msstore" "Lifecycle source"
    Assert-Equal ($arguments -contains "--scope") $false "No Store scope argument"
}
Assert-Equal (Test-Package $spotify) $false "Uninstall updates presence cache"
Assert-Equal $script:calls.Count 4 "Uninstall cache avoids query"

$wingetPackageStatus.Clear()
$script:queryExitCode = $wingetPackageNotFound
Assert-Equal (Test-Package $spotify) $false "Missing Store package"
$wingetPackageStatus.Clear()
$script:queryExitCode = 1
$queryFailed = $false
try { Test-Package $spotify | Out-Null } catch { $queryFailed = $true }
Assert-Equal $queryFailed $true "Query errors do not imply missing package"
$script:queryExitCode = 0

# Legacy state must retain its identity and default to the community source.
$legacy = [pscustomobject]@{ Driver = "winget"; Id = "Example.App"; Kind = ""; Scope = "" }
$explicit = $legacy.PSObject.Copy()
$explicit | Add-Member Source "winget"
Assert-Equal (Get-PackageKey $legacy) "winget|Example.App||" "Legacy ownership key"
Assert-Equal (Get-PackageKey $explicit) (Get-PackageKey $legacy) "Default-source compatibility"
$explicit.Source = "msstore"
Assert-Equal ((Get-PackageKey $explicit) -eq (Get-PackageKey $legacy)) $false "Ownership separates sources"
Assert-Equal ((Get-PackageKeyWithoutScope $explicit) -eq (Get-PackageKeyWithoutScope $legacy)) $false "Scope migration separates sources"

# Source and scope must also isolate presence caches for identical IDs.
$wingetPackageStatus.Clear()
$script:calls.Clear()
$legacy.Scope = "machine"
$explicit.Scope = "machine"
Test-Package $legacy | Out-Null
Test-Package $explicit | Out-Null
Assert-Equal $script:calls.Count 2 "Independent source caches"
Assert-Equal ($script:calls[0] -join ' ') "list --id Example.App --exact --source winget --accept-source-agreements --disable-interactivity --scope machine" "Legacy scoped query"
Assert-Equal ($script:calls[1] -join ' ') "list --id Example.App --exact --source msstore --accept-source-agreements --disable-interactivity --scope machine" "Source-aware scoped query"
Install-Package $legacy
Assert-Equal $script:calls[2][5] "winget" "Legacy install source"

# Platform composition must still include Spotify exactly once, except under WSL.
foreach ($platform in @(
    @{ os = "windows"; kernel = @{ osrelease = "" }; expected = 1 },
    @{ os = "darwin"; kernel = @{ osrelease = "" }; expected = 1 },
    @{ os = "linux"; kernel = @{ osrelease = "6.1" }; expected = 1 },
    @{ os = "linux"; kernel = @{ osrelease = "6.1-microsoft-standard-WSL2" }; expected = 0 }
)) {
    $override = @{ chezmoi = @{ os = $platform.os; kernel = $platform.kernel } } | ConvertTo-Json -Compress
    $composition = & chezmoi --source $source --override-data $override execute-template '{{ includeTemplate ".chezmoitemplates/packages.yaml" . | fromYaml | toJson }}'
    Assert-Equal $LASTEXITCODE 0 "$($platform.os) composition render"
    $names = @($composition | ConvertFrom-Json | ForEach-Object {
        if ($_ -is [string]) { $_ } else { $_.PSObject.Properties.Name }
    })
    Assert-Equal @($names | Where-Object { $_ -eq "spotify" }).Count $platform.expected "$($platform.os) Spotify count"
    Assert-Equal @($names | Group-Object | Where-Object Count -gt 1).Count 0 "No duplicate declarations"
}

$macRecords = & chezmoi --source $source --override-data '{"chezmoi":{"os":"darwin"}}' execute-template '{{ includeTemplate ".chezmoitemplates/xpack-records" . }}'
Assert-Equal $LASTEXITCODE 0 "macOS records render"
Assert-Equal ($macRecords | Where-Object { $_ -like 'spotify|*' }) "spotify|brew|brew|spotify|cask|manager||||" "macOS Spotify mapping"

Write-Host "xpack source, lifecycle, ownership, syntax, and platform checks passed."
