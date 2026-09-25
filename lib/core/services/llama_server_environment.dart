Map<String, String> llamaServerLibraryEnvironment(String nativeLibraryDir) {
  return <String, String>{
    // Vendor dirs are appended so the backends can dlopen Qualcomm
    // public libraries (libcdsprpc.so for Hexagon, libOpenCL.so for
    // OpenCL) — the spawned process does not inherit the app
    // classloader namespace that normally exposes them.
    'LD_LIBRARY_PATH': '$nativeLibraryDir:/vendor/lib64:/odm/lib64',
    // Required by FastRPC to locate the libggml-htp-vNN.so NPU-side
    // libraries when the Hexagon backend is used.
    'ADSP_LIBRARY_PATH': nativeLibraryDir,
  };
}
