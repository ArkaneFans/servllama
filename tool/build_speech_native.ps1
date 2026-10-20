param(
    [string]$AndroidSdk = $env:ANDROID_HOME,
    [string]$NdkVersion = "27.0.12077973",
    [string]$CmakeVersion = "3.22.1",
    [int]$Jobs = 6
)
$ErrorActionPreference = "Stop"
if (!$AndroidSdk) { $AndroidSdk = $env:ANDROID_SDK_ROOT }
if (!$AndroidSdk) { throw "Pass -AndroidSdk with your Android SDK path." }
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$source = Join-Path $projectRoot "native-cache/CrispASR"
$build = Join-Path $projectRoot "native-cache/build-crisp-android"
$pin = "2165cb64633cc8fed8e04c6002332809860b245e"
function Check-Exit([string]$Operation) {
    if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE" }
}
if (!(Test-Path -LiteralPath (Join-Path $source ".git"))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $source) | Out-Null
    git clone --no-checkout https://github.com/CrispStrobe/CrispASR.git $source
    Check-Exit "Clone CrispASR"
    git -C $source checkout --detach $pin
    Check-Exit "Checkout CrispASR"
}
$head = git -C $source rev-parse HEAD
if ($head -ne $pin) { throw "CrispASR cache must be at $pin. Found $head" }
git -C $source submodule update --init ggml third_party/c2pa-audio
Check-Exit "Fetch pinned submodules"
$patch = Join-Path $projectRoot "native/speech/upstream-paths.patch"
git -C $source apply --ignore-space-change --check $patch 2>$null
if ($LASTEXITCODE -eq 0) {
    git -C $source apply --ignore-space-change $patch
    Check-Exit "Apply downstream CMake path patch"
} else {
    git -C $source apply --ignore-space-change --reverse --check $patch 2>$null
    Check-Exit "Verify existing downstream patch"
}
$ndk = Join-Path $AndroidSdk "ndk/$NdkVersion"
$cmake = Join-Path $AndroidSdk "cmake/$CmakeVersion/bin/cmake.exe"
$ninja = Join-Path $AndroidSdk "cmake/$CmakeVersion/bin/ninja.exe"
$llvm = Join-Path $ndk "toolchains/llvm/prebuilt/windows-x86_64/bin"
& $cmake -S (Join-Path $projectRoot "native/speech") -B $build -G Ninja "-DCMAKE_MAKE_PROGRAM=$ninja" "-DCMAKE_TOOLCHAIN_FILE=$ndk/build/cmake/android.toolchain.cmake" "-DCRISPASR_SOURCE=$source" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28 -DANDROID_STL=c++_static -DCMAKE_BUILD_TYPE=Release
Check-Exit "Configure native speech"
& $cmake --build $build --target crispasr-lib -j $Jobs
Check-Exit "Build native speech"
$destination = Join-Path $projectRoot "android/app/src/main/jniLibs/arm64-v8a"
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$library = Join-Path $destination "libservllama_crispasr.so"
Copy-Item -LiteralPath (Join-Path $build "crispasr/src/libservllama_crispasr.so") -Destination $library -Force
& (Join-Path $llvm "llvm-strip.exe") --strip-unneeded $library
Check-Exit "Strip speech library"
$dynamic = & (Join-Path $llvm "llvm-readelf.exe") -d $library
Check-Exit "Inspect speech dependencies"
$needed = @($dynamic | Select-String 'Shared library: \[(.+?)\]' | ForEach-Object { $_.Matches[0].Groups[1].value })
$allowed = @("libc.so","libm.so","libdl.so","liblog.so","libandroid.so","libmediandk.so")
foreach ($dependency in $needed) {
    if ($dependency -notin $allowed) { throw "Unpackaged or conflicting dependency: $dependency" }
}
$segments = & (Join-Path $llvm "llvm-readelf.exe") -lW $library
foreach ($segment in ($segments | Select-String '^\s*LOAD\s')) {
    if ($segment.Line -notmatch '0x4000\s*$') { throw "Speech library is not 16 KiB aligned." }
}
$symbols = & (Join-Path $llvm "llvm-nm.exe") -D --defined-only $library
foreach ($symbol in @("crispasr_session_open","crispasr_session_transcribe","crispasr_session_synthesize","crispasr_c2pa_sign")) {
    if (!($symbols -match $symbol)) { throw "Missing speech ABI: $symbol" }
}
$manifest = [ordered]@{
    schemaVersion = 1
    source = [ordered]@{ repository = "https://github.com/CrispStrobe/CrispASR"; commit = $pin; version = "0.8.37"; ggml = (git -C (Join-Path $source "ggml") rev-parse HEAD); c2pa = (git -C (Join-Path $source "third_party/c2pa-audio") rev-parse HEAD) }
    build = [ordered]@{ abi="arm64-v8a"; ndk=$NdkVersion; minSdk=28; stl="c++_static"; openmp=$false; pageSize=16384; exportedSymbols="crispasr_*"; c2pa=$true }
    library = [ordered]@{ name="libservllama_crispasr.so"; bytes=(Get-Item -LiteralPath $library).Length; sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $library).Hash.ToLowerInvariant(); needed=$needed }
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $projectRoot "native/speech/android-arm64-v8a.json") -Encoding utf8NoBOM
Write-Output "Built and verified $library"
