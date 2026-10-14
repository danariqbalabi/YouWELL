param([switch]$BuildWeb)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
. "$PSScriptRoot\flutter-path.ps1"
$flutter = Resolve-YouWellFlutter -ProjectRoot $projectRoot
& $flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $flutter analyze --no-pub
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $flutter test --no-pub
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($BuildWeb) {
  foreach ($target in @('admin', 'mobile')) {
    $phoneWeb = if ($target -eq 'mobile') { 'true' } else { 'false' }
    & $flutter build web --release --no-pub --no-web-resources-cdn `
      "--output=build/$target-web" "--dart-define=MOBILE_WEB=$phoneWeb" `
      --dart-define=MOBILE_PREVIEW=false `
      --dart-define-from-file=config/env/production.example.json
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}
