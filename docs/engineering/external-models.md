# External local models

The model library offers two actions under its add button:

- **Copy model to ServLlama** keeps the existing GGUF/SAF MNN import flow.
- **Use external model** registers a real filesystem path without copying
  source model files. GGUF selects a file; MNN selects a complete directory.

## File selection and permissions

`ModelFileBrowser` lists only immediate child directories and GGUF files.
`ModelFilePickerPage` provides directory navigation, a storage-root shortcut,
and a current-directory selection button for MNN. It is not a general document
manager: there is no search, editing, cloud-provider support or SAF URI mapping.
The first version browses the device's primary shared storage.

The Android host requests storage access only when the external picker opens:
`MANAGE_EXTERNAL_STORAGE` on API 30+, and legacy read access on API 28-29.
Android 10 uses `requestLegacyExternalStorage`. Copy imports do not require
this new authorization. All-files access is subject to Google Play policy.

Do not use Android `file_picker` results as external paths: its file-selection
implementation copies the selected document to app cache.

## Persistence and ownership

Reuse `model_assets` with `storage_owner='external'`. No schema migration or
second model catalog is needed. GGUF details remain in the existing `gguf`
manifest; external MNN capabilities and registration time live in its manifest.
Duplicate paths reuse the existing registration. Names use the shared name
coordinator and never rename the external source.

External entries are not checked for existence during list refresh, startup
or before loading. They remain ready until the user removes their registration;
an unavailable or invalid source fails through the existing engine load flow.
There is no automatic copying, missing-file cleanup, watcher or recovery.
GGUF size is optional selection-time metadata. External MNN directories are
not recursively scanned for size. Optional MNN capability metadata is read
when registering and loading, without validating referenced files.

Removal clears model selection references but preserves conversation history
and source files. Rename updates only the display/API alias. External GGUF
projectors use the same external picker; replacement/removal detaches references
without deleting files. Managed models keep their existing file operations.

## Engine loading

llama.cpp receives the registered GGUF/projector paths as normal CLI arguments.
MNN uses the plugin's public `loadModelFromPath` API and the same runtime/session
pipeline as imported models. The plugin owns no external-model registry.
External MNN IDs are `external-` plus SHA-256 of the absolute directory path,
so aliases do not change identities or cache keys. Generated mmap/GPU caches
stay in the plugin's private runtime directory and use the existing cache UI.

Tests cover absent external files, source-preserving operations, SQL indexing,
native path dispatch, directory selection and the unchanged copy-import action.
