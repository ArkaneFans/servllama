#!/usr/bin/env bash
# Build ServLlama's llama.cpp Android bundle inside
# ghcr.io/snapdragon-toolchain/arm64-android.
# llama-server lives under tools/, and cmake --install installs every enabled
# tool, so this builds the default all target with tools left on. HTP skels
# are ExternalProjects and are not dependencies of llama-server. Tests,
# examples, and the app are disabled.
set -euo pipefail

src="${1:-}"
if [[ -z "${src}" || ! -d "${src}" ]]; then
  echo "usage: build_snapdragon_android.sh <llama.cpp-source>" >&2
  exit 2
fi
cd "${src}"

: "${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT is empty}"
: "${HEXAGON_SDK_ROOT:?HEXAGON_SDK_ROOT is empty}"
: "${HEXAGON_TOOLS_ROOT:?HEXAGON_TOOLS_ROOT is empty}"
: "${DEST_JNI:?DEST_JNI is empty}"

test -f CMakeUserPresets.json
test -d "${ANDROID_NDK_ROOT}"
test -d "${HEXAGON_SDK_ROOT}"
test -d "${HEXAGON_TOOLS_ROOT}"
test -x "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
test -x "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf"

echo "ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}"
echo "HEXAGON_SDK_ROOT=${HEXAGON_SDK_ROOT}"
echo "HEXAGON_TOOLS_ROOT=${HEXAGON_TOOLS_ROOT}"
echo "OPENCL_SDK_ROOT=${OPENCL_SDK_ROOT-<unset>}"

configure_log="${src}/build-snapdragon-configure.log"
stdbuf -oL -eL cmake --preset arm64-android-servllama-release -B build-snapdragon \
  -DGGML_NATIVE=OFF \
  -DANDROID_STL=c++_static \
  -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON \
  -DLLAMA_BUILD_APP=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_TOOLS=ON \
  2>&1 | tee "${configure_log}"

if ! grep -q "Including OpenCL backend" "${configure_log}"; then
  echo "Configure did not enable the OpenCL backend." >&2
  exit 1
fi
if ! grep -q "Including Hexagon backend" "${configure_log}"; then
  echo "Configure did not enable the Hexagon backend." >&2
  exit 1
fi

cmake --build build-snapdragon -j "$(nproc)"
cmake --install build-snapdragon --prefix pkg-snapdragon/llama.cpp

prefix="${src}/pkg-snapdragon/llama.cpp"
strip="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
readelf="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf"

find "${prefix}/bin" "${prefix}/lib" -type f \
  \( -name '*.so' -o -name 'llama-server' \) \
  ! -name 'libggml-htp-*' \
  -print0 \
  | xargs -0 -r "${strip}" --strip-unneeded

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "${DEST_JNI}"
python3 "${script_dir}/package_jni_libs.py" "${prefix}" "${DEST_JNI}"
chmod 755 "${DEST_JNI}/libllama-server.so"

verify_jni() {
  local dir="$1"
  local android=0
  local hexagon=0
  local binary machine alignment dep loads base

  while IFS= read -r -d '' binary; do
    machine="$("${readelf}" -h "${binary}" | awk -F: '/Machine:/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}')"
    base="$(basename "${binary}")"
    if [[ "${base}" == libggml-htp-*.so ]]; then
      if [[ "${machine}" != "Qualcomm Hexagon" ]]; then
        echo "Expected a Qualcomm Hexagon ELF for ${base}, found: ${machine:-unknown}" >&2
        exit 1
      fi
      hexagon=$((hexagon + 1))
      continue
    fi

    if [[ "${machine}" != "AArch64" ]]; then
      echo "Unexpected ELF architecture for ${base}: ${machine:-unknown}" >&2
      exit 1
    fi
    android=$((android + 1))
    loads=0
    while read -r alignment; do
      loads=$((loads + 1))
      if (( alignment < 0x4000 )); then
        echo "${base} has a LOAD segment aligned below 16 KiB: ${alignment}" >&2
        exit 1
      fi
    done < <("${readelf}" -lW "${binary}" | awk '$1 == "LOAD" { print $NF }')
    if (( loads == 0 )); then
      echo "${base} has no LOAD segments." >&2
      exit 1
    fi

    while read -r dep; do
      [[ -n "${dep}" ]] || continue
      case "${dep}" in
        libc.so|libdl.so|libm.so|liblog.so|libandroid.so|libz.so|libOpenCL.so|libcdsprpc.so)
          continue
          ;;
      esac
      if [[ ! -f "${dir}/${dep}" ]]; then
        echo "Missing runtime dependency ${dep}, required by ${base}." >&2
        exit 1
      fi
    done < <("${readelf}" -dW "${binary}" | sed -n 's/.*Shared library: \[\([^]]*\)\].*/\1/p')
  done < <(find "${dir}" -maxdepth 1 -type f -name '*.so' -print0)

  if (( android == 0 || hexagon < 4 )); then
    echo "Bundle check failed: android_elf=${android} hexagon_elf=${hexagon}." >&2
    exit 1
  fi
  echo "Verified ${android} Android libraries and ${hexagon} Hexagon skels."
}

verify_jni "${DEST_JNI}"

env_out="${TOOLCHAIN_ENV_OUT:-}"
if [[ -n "${env_out}" ]]; then
  mkdir -p "$(dirname "${env_out}")"
  cat > "${env_out}" <<EOF
ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}
HEXAGON_SDK_ROOT=${HEXAGON_SDK_ROOT}
HEXAGON_TOOLS_ROOT=${HEXAGON_TOOLS_ROOT}
EOF
fi
