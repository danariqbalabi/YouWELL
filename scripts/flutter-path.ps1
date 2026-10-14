function Resolve-YouWellFlutter {
  param([string]$ProjectRoot)
  $command = Get-Command flutter -ErrorAction SilentlyContinue
  $flutterPath = if ($command) { $command.Source } else {
    Join-Path $ProjectRoot '.tools\flutter\bin\flutter.bat'
  }
  if (-not (Test-Path -LiteralPath $flutterPath)) {
    throw 'Flutter belum tersedia. Install Flutter atau gunakan SDK di .tools/flutter.'
  }
  # Native asset hooks in Dart on Windows can misquote a spaced SDK path.
  # Use its existing 8.3 alias, without moving the SDK or changing PATH.
  if ($flutterPath.Contains(' ')) {
    $fileSystem = New-Object -ComObject Scripting.FileSystemObject
    $flutterPath = $fileSystem.GetFile($flutterPath).ShortPath
    if ($flutterPath.Contains(' ')) {
      throw 'SDK Flutter untuk native tests perlu path tanpa spasi pada volume ini.'
    }
  }
  return $flutterPath
}
