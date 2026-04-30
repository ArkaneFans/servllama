# ServLlama AGENTS Guide

## Project Overview

- `ServLlama` is a Flutter application for managing and using local LLM inference API services powered by `llama-server`.
- The project follows a feature-first structure.

## Tech Stack

- Language: `Dart 3`
- Framework: `Flutter`
- UI: `Material 3`
- Platform: currently focused on `Android`, with bundled `llama-server` binaries
- Persistence: `Hive` + `SharedPreferences`
- State management: `provider`
- Networking: `dio`
- Dependencies: `path_provider`, `file_picker`, and others (see `pubspec.yaml`)

## llama-server Integration

- This project bundles and manages `llama-server` as its local inference backend.
- The Flutter app does not implement model inference directly; it communicates with `llama-server` over HTTP APIs.
- `llama-server` is responsible for model loading, inference execution, request handling, and the core inference lifecycle.
- The Flutter app is responsible for service startup orchestration, parameter configuration, status presentation, error handling, and user interaction.
- When making changes related to `llama-server`, clarify the boundary first:
  - whether the change belongs to service process management
  - whether it belongs to API parameter adaptation
  - whether it belongs to model discovery and path management
  - whether it belongs to Flutter UI presentation and interaction logic
- If you need to adjust `llama-server` startup arguments, port, model path, context length, thread count, or similar settings, encapsulate them in the service or repository layer first. Do not scatter these details across page-level code.
- For detailed `llama-server` usage, see `llama-server-README.md`.

## Development Practices

- Put new business logic under `lib/features/<feature>/` whenever possible.
- Use `lib/app/` for app entry, route assembly, and app-level composition.
- Use `lib/core/` only for foundational capabilities shared across features.
- Use `lib/shared/` for reusable UI components and shared presentation utilities.
- Do not add extra entities unless necessary. Avoid defensive programming and do not design for hypothetical future requirements.

## Layering Rules

- The page layer is responsible for presentation, interaction orchestration, and routing.
- The state layer is responsible for page state, user action coordination, and flow orchestration.
- The service or repository layer is responsible for I/O concerns such as processes, file system access, persistence, and networking.
- Models and types should express strongly typed data only, without page logic mixed in.

## Single Responsibility

- A class, component, or module should have one clear responsibility.
- Pages must not handle low-level I/O directly.
- The state layer must not own low-level resource implementation details.
- The service or repository layer must not contain UI presentation logic.
- Shared components must not embed feature-specific business decisions.
- Shared capabilities should remain reusable, and business capabilities should have clear boundaries.

## Development and Verification

- Run `flutter analyze` before submitting changes.
- Prefer adding unit tests when changing business logic.
- Add the minimum necessary widget tests when changing page interactions.
- Do not perform unrelated refactors. When touching old code, only bring it closer to the standard within the scope of the current change.
