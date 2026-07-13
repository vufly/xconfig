{{- if eq .chezmoi.os "windows" -}}
# mise config hash: {{ includeTemplate ".chezmoitemplates/mise-config.toml" . | sha256sum }}

$ErrorActionPreference = "Stop"
$prefix = "$([char]27)[1;34m[chezmoi]$([char]27)[0m"
$mise = "$([char]27)[35mmise$([char]27)[0m"

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
  Write-Host "$prefix $mise config changed, but $mise is not installed; skipping."
  exit 0
}

Set-Location $HOME
Write-Host "$prefix $mise config changed; updating tools in $HOME."
Write-Host "$prefix Running $mise upgrade..."
mise upgrade
if ($LASTEXITCODE -ne 0) {
  throw "mise upgrade failed with exit code $LASTEXITCODE"
}
Write-Host "$prefix Running $mise prune --yes..."
mise prune --yes
if ($LASTEXITCODE -ne 0) {
  throw "mise prune failed with exit code $LASTEXITCODE"
}
Write-Host "$prefix $mise update completed."
{{- end -}}
