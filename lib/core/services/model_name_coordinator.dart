import 'dart:async';

import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';

class AllocatedModelName {
  const AllocatedModelName({required this.requestedName, required this.name});

  final String requestedName;
  final String name;

  bool get wasRenamed => requestedName.toLowerCase() != name.toLowerCase();
}

/// Serializes model-name allocation across imports, downloads and manual
/// renames. Installed GGUF/MNN models remain authoritative in their own
/// repositories; this coordinator adds short-lived reservations for work that
/// has not reached either repository yet.
class ModelNameCoordinator {
  ModelNameCoordinator({required UnifiedModelRepository unifiedRepository})
    : _unifiedRepository = unifiedRepository;

  final UnifiedModelRepository _unifiedRepository;
  final Map<String, String> _reservations = <String, String>{};
  Future<void> _operationTail = Future<void>.value();

  Future<AllocatedModelName> reserveAvailable({
    required String ownerId,
    required String requestedName,
    String? preferredName,
    String? excludingLibraryId,
  }) {
    return _synchronized(() async {
      final requested = requestedName.trim();
      _unifiedRepository.validateName(requested);
      final preferred = preferredName?.trim();
      if (preferred != null) {
        _unifiedRepository.validateName(preferred);
      }

      final occupied = await _occupiedNames(
        excludingOwnerId: ownerId,
        excludingLibraryId: excludingLibraryId,
      );
      final allocated = preferred != null && !_contains(occupied, preferred)
          ? await _usePreferredOrAllocate(
              preferred,
              requested,
              occupied,
              excludingLibraryId,
            )
          : await _nextAvailable(requested, occupied, excludingLibraryId);
      _reservations[ownerId] = allocated;
      return AllocatedModelName(requestedName: requested, name: allocated);
    });
  }

  /// Reserves exactly what the user typed. This is used by manual rename,
  /// where silently modifying input would be surprising.
  Future<void> reserveExact({
    required String ownerId,
    required String name,
    String? excludingLibraryId,
  }) {
    return _synchronized(() async {
      final trimmedName = name.trim();
      _unifiedRepository.validateName(trimmedName);
      final occupied = await _occupiedNames(
        excludingOwnerId: ownerId,
        excludingLibraryId: excludingLibraryId,
      );
      if (_contains(occupied, trimmedName)) {
        throw const ModelOperationException(
          ModelOperationErrorCode.modelNameExists,
        );
      }
      if (await _unifiedRepository.isStorageNameOccupied(
        trimmedName,
        excludingLibraryId: excludingLibraryId,
      )) {
        throw const ModelOperationException(
          ModelOperationErrorCode.modelNameExists,
        );
      }
      _reservations[ownerId] = trimmedName;
    });
  }

  /// Gives an already-committed model priority over pending reservations. If
  /// another installed model claimed the name during the native copy, a new
  /// suffix is allocated so the committed directory can be renamed safely.
  Future<AllocatedModelName> reserveCommitted({
    required String ownerId,
    required String requestedName,
    required String committedName,
    required String excludingLibraryId,
  }) {
    return _synchronized(() async {
      final requested = requestedName.trim();
      final committed = committedName.trim();
      _unifiedRepository.validateName(requested);
      _unifiedRepository.validateName(committed);

      final installed = await _unifiedRepository.listModels();
      final installedNames = <String>{
        for (final model in installed)
          if (model.id != excludingLibraryId) model.name,
      };
      final committedConflicts =
          _contains(installedNames, committed) ||
          await _unifiedRepository.isStorageNameOccupied(
            committed,
            excludingLibraryId: excludingLibraryId,
          );
      final allocated = committedConflicts
          ? await _nextAvailable(requested, <String>{
              ...installedNames,
              for (final entry in _reservations.entries)
                if (entry.key != ownerId) entry.value,
            }, excludingLibraryId)
          : committed;
      _reservations[ownerId] = allocated;
      return AllocatedModelName(requestedName: requested, name: allocated);
    });
  }

  Future<void> ensureAvailable(
    String name, {
    String? excludingLibraryId,
  }) async {
    final ownerId = 'check:${DateTime.now().microsecondsSinceEpoch}';
    try {
      await reserveExact(
        ownerId: ownerId,
        name: name,
        excludingLibraryId: excludingLibraryId,
      );
    } finally {
      await release(ownerId);
    }
  }

  /// Snapshot passed to native directory import. Native still performs its own
  /// final filesystem check, and Flutter revalidates after import to close the
  /// picker/copy race window.
  Future<List<String>> unavailableNames({String? excludingOwnerId}) {
    return _synchronized(() async {
      final occupied = await _occupiedNames(excludingOwnerId: excludingOwnerId);
      return occupied.toList(growable: false);
    });
  }

  Future<void> release(String ownerId) {
    return _synchronized(() async {
      _reservations.remove(ownerId);
    });
  }

  Future<Set<String>> _occupiedNames({
    String? excludingOwnerId,
    String? excludingLibraryId,
  }) async {
    final models = await _unifiedRepository.listModels();
    return <String>{
      for (final model in models)
        if (model.id != excludingLibraryId) model.name,
      for (final entry in _reservations.entries)
        if (entry.key != excludingOwnerId) entry.value,
    };
  }

  Future<String> _usePreferredOrAllocate(
    String preferredName,
    String requestedName,
    Set<String> occupied,
    String? excludingLibraryId,
  ) async {
    if (!await _unifiedRepository.isStorageNameOccupied(
      preferredName,
      excludingLibraryId: excludingLibraryId,
    )) {
      return preferredName;
    }
    return _nextAvailable(requestedName, occupied, excludingLibraryId);
  }

  Future<String> _nextAvailable(
    String requestedName,
    Set<String> occupied,
    String? excludingLibraryId,
  ) async {
    if (!_contains(occupied, requestedName) &&
        !await _unifiedRepository.isStorageNameOccupied(
          requestedName,
          excludingLibraryId: excludingLibraryId,
        )) {
      return requestedName;
    }
    for (var suffix = 2; ; suffix += 1) {
      final candidate = '$requestedName ($suffix)';
      if (!_contains(occupied, candidate) &&
          !await _unifiedRepository.isStorageNameOccupied(
            candidate,
            excludingLibraryId: excludingLibraryId,
          )) {
        return candidate;
      }
    }
  }

  bool _contains(Set<String> names, String candidate) {
    final normalized = candidate.toLowerCase();
    return names.any((name) => name.toLowerCase() == normalized);
  }

  Future<T> _synchronized<T>(Future<T> Function() operation) {
    final previous = _operationTail;
    final gate = Completer<void>();
    _operationTail = gate.future;
    return previous.then((_) => operation()).whenComplete(gate.complete);
  }
}
