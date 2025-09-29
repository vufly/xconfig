# function Invoke-Starship-PreCommand {
#   $title = "PS "
#   $title += Split-Path -Leaf $pwd
#   $host.ui.RawUI.WindowTitle = $title
# }
# Invoke-Expression (&starship init powershell)

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History
Import-Module git-aliases -DisableNameChecking
Import-Module -Name Terminal-Icons

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

mise activate pwsh | Out-String | Invoke-Expression
Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })

[Console]::OutputEncoding = [Text.Encoding]::UTF8
oh-my-posh init pwsh --config "~/.theme.omp.toml" | Invoke-Expression
