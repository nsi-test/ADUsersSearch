using module ".\ADUsersSearchAssemblies.psm1"

using module ".\ADUSIconB64.psm1"

using module ".\ADUsersSearchForm.psm1"

Set-Variable -Name ADUSVersion -Value "1.1.0" -Option ReadOnly -Force -Scope global

$appForm = [ADSearchForm]::New()

[System.Windows.Forms.Application]::Run($appForm)
