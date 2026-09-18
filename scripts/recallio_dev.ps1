param(
  [ValidateSet('clean', 'pub-get', 'analyze', 'test', 'build-windows-debug', 'build-windows-release', 'build-android-debug', 'build-android-release', 'run-windows', 'doctor')]
  [string] $Task = 'doctor'
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$WorkspaceRoot = Split-Path -Parent $ProjectRoot
$FlutterRoot = Join-Path $WorkspaceRoot 'tools\flutter'
$Flutter = Join-Path $FlutterRoot 'bin\flutter.bat'
$DartBin = Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin'
$PubCache = Join-Path $WorkspaceRoot 'tools\pub-cache'
$TempDir = Join-Path $WorkspaceRoot 'tmp'
$GradleUserHome = Join-Path $WorkspaceRoot 'tools\gradle-home'

if (-not (Test-Path -LiteralPath $Flutter)) {
  throw "Flutter SDK not found: $Flutter"
}

New-Item -ItemType Directory -Force -Path $PubCache, $TempDir, $GradleUserHome | Out-Null

$env:PUB_CACHE = $PubCache
$env:TEMP = $TempDir
$env:TMP = $TempDir
$env:GRADLE_USER_HOME = $GradleUserHome
$env:VSLANG = '1033'
$env:DOTNET_CLI_UI_LANGUAGE = 'en'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp.com 65001 | Out-Null
$CleanPath = @(
  (Join-Path $FlutterRoot 'bin'),
  $DartBin,
  'E:\git\Git\cmd',
  'C:\WINDOWS\system32',
  'C:\WINDOWS',
  'C:\WINDOWS\System32\Wbem',
  'C:\WINDOWS\System32\WindowsPowerShell\v1.0\',
  'C:\Program Files (x86)\Microsoft Visual Studio\Installer'
) -join ';'
[Environment]::SetEnvironmentVariable('PATH', $null, 'Process')
[Environment]::SetEnvironmentVariable('Path', $CleanPath, 'Process')
$env:Path = $CleanPath

Set-Location -LiteralPath $ProjectRoot

switch ($Task) {
  'clean' {
    & $Flutter clean
  }
  'pub-get' {
    & $Flutter pub get --offline
    if ($LASTEXITCODE -ne 0) {
      & $Flutter pub get
    }
  }
  'analyze' {
    & $Flutter analyze
  }
  'test' {
    & $Flutter test
  }
  'build-windows-debug' {
    & $Flutter build windows --debug
  }
  'build-windows-release' {
    & $Flutter build windows --release
  }
  'build-android-debug' {
    & $Flutter build apk --debug
  }
  'build-android-release' {
    & $Flutter build apk --release --split-per-abi
  }
  'run-windows' {
    & $Flutter run -d windows
  }
  'doctor' {
    Write-Host "Project: $ProjectRoot"
    Write-Host "Flutter: $Flutter"
    Write-Host "PUB_CACHE: $env:PUB_CACHE"
    Write-Host "TEMP: $env:TEMP"
    Write-Host "GRADLE_USER_HOME: $env:GRADLE_USER_HOME"
    Write-Host "PATH length: $($env:PATH.Length)"
    & $Flutter --version
  }
}

exit $LASTEXITCODE
