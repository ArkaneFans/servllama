from pathlib import Path
import shutil
import sys

WHITELIST_PREFIXES = (
    "libggml.so",
    "libggml-base.so",
    "libggml-cpu-",
    "libggml-opencl.so",
    "libggml-hexagon.so",
    "libggml-htp-",
    "libllama.so",
    "libllama-common.so",
    "libllama-server-impl.so",
    "libllama-server.so",
    "libmtmd.so",
)

def allowed(name: str) -> bool:
    return any(name == prefix or name.startswith(prefix) for prefix in WHITELIST_PREFIXES)

def main() -> int:
    if len(sys.argv) < 3:
        print("usage: package_jni_libs.py <pkg-snapdragon/llama.cpp> <jniLibs/arm64-v8a>")
        return 2
    src = Path(sys.argv[1])
    dest = Path(sys.argv[2])
    dest.mkdir(parents=True, exist_ok=True)
    copied = []
    for folder in (src / "bin", src / "lib"):
        if not folder.is_dir():
            continue
        for path in folder.iterdir():
            name = path.name
            if name == "llama-server":
                name = "libllama-server.so"
            if not allowed(name):
                continue
            target = dest / name
            shutil.copy2(path, target)
            copied.append(name)
    copied = sorted(set(copied))
    missing = [
        name for name in (
            "libggml.so", "libggml-base.so", "libggml-opencl.so", "libggml-hexagon.so",
            "libllama.so", "libllama-common.so", "libllama-server-impl.so",
            "libllama-server.so", "libmtmd.so",
        ) if name not in copied
    ]
    if missing:
        print("missing:", ", ".join(missing))
        return 1
    if not any(name.startswith("libggml-cpu-") for name in copied):
        print("missing CPU variants")
        return 1
    if not any(name.startswith("libggml-htp-") for name in copied):
        print("missing HTP kernels")
        return 1
    print("copied", len(copied), "files to", dest)
    for name in copied:
        print(" ", name)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
