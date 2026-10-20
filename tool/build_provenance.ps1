param([string]$LibraryDirectory = "$PSScriptRoot/../android/app/src/main/jniLibs/arm64-v8a")
$ErrorActionPreference = 'Stop'
$rootPath = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$files = if (Test-Path -LiteralPath $LibraryDirectory) {
    @(Get-ChildItem -LiteralPath $LibraryDirectory -Filter '*.so' -File)
} else { @() }
$result = [ordered]@{
    appCommit = (git -C $rootPath rev-parse HEAD)
    flutter = (flutter --version --machine | ConvertFrom-Json)
    java = (& java -version 2>&1 | Out-String).Trim()
    llamaManifest = (Get-Content -LiteralPath "$rootPath/assets/bin/llama_server_manifest.json" -Raw | ConvertFrom-Json)
    libraries = @($files | ForEach-Object {
        @{ name = $_.Name; bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
}
$result | ConvertTo-Json -Depth 10
if ($files.Count -eq 0) { Write-Warning 'No llama native bundle. A Flutter APK alone does not verify local inference.' }

