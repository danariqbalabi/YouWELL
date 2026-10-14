param(
  [ValidateSet('admin', 'mobile', 'preview')]
  [string]$Target = 'admin',
  [ValidateRange(1, 65535)]
  [int]$Port = 8081,
  [string]$HostName = '127.0.0.1'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
. "$PSScriptRoot\flutter-path.ps1"
$flutter = Resolve-YouWellFlutter -ProjectRoot $projectRoot
$environmentFile = if ($env:YOUWELL_ENV_FILE) { $env:YOUWELL_ENV_FILE } else { 'config/env/development.json' }
if (-not (Test-Path -LiteralPath $environmentFile)) { $environmentFile = 'config/env/development.example.json' }

& $flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$arguments = @('run', '-d', 'web-server', '--web-hostname', $HostName,
  '--web-port', "$Port", "--dart-define-from-file=$environmentFile")
switch ($Target) {
  'admin' { $arguments += @('--dart-define=MOBILE_WEB=false', '--dart-define=MOBILE_PREVIEW=false') }
  'mobile' { $arguments += @('--dart-define=MOBILE_WEB=true', '--dart-define=MOBILE_PREVIEW=false') }
  'preview' { $arguments += @('--dart-define=MOBILE_WEB=false', '--dart-define=MOBILE_PREVIEW=true') }
}
Write-Host "YouWELL $Target di http://${HostName}:$Port"
& $flutter @arguments
exit $LASTEXITCODE
