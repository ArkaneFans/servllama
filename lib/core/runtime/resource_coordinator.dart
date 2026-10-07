import 'package:flutter/foundation.dart';

enum LocalResourceDomain { llm, speech }

enum LocalResourceKind {
  llm(LocalResourceDomain.llm),
  asr(LocalResourceDomain.speech),
  tts(LocalResourceDomain.speech);

  const LocalResourceKind(this.domain);
  final LocalResourceDomain domain;
}

@immutable
class ResourceLease {
  const ResourceLease._(this.token, this.kind, this.assetId, this.owner);
  final int token;
  final LocalResourceKind kind;
  final String assetId;
  final String owner;
}

/// LLM and speech own independent residency. ASR/TTS share the speech FIFO.
/// Acquiring/releasing is synchronous; never hold a mutex across native awaits.
class ResourceCoordinator extends ChangeNotifier {
  final Map<LocalResourceDomain, ResourceLease> _leases = {};
  final Set<LocalResourceDomain> _quarantined = {};
  int _epoch = 0;
  bool requiresRestart(LocalResourceDomain domain) =>
      _quarantined.contains(domain);
  void quarantine(ResourceLease lease) {
    final domain = lease.kind.domain;
    if (_leases[domain]?.token != lease.token) return;
    _quarantined.add(domain);
    notifyListeners();
  }

  ResourceLease? leaseFor(LocalResourceDomain domain) => _leases[domain];
  bool isFree(LocalResourceDomain domain) => !_leases.containsKey(domain);
  ResourceLease? tryAcquire({
    required LocalResourceKind kind,
    required String assetId,
    required String owner,
  }) {
    if (!isFree(kind.domain) || requiresRestart(kind.domain)) {
      return null;
    }
    final lease = ResourceLease._(++_epoch, kind, assetId, owner);
    _leases[kind.domain] = lease;
    notifyListeners();
    return lease;
  }

  bool release(ResourceLease lease) {
    final domain = lease.kind.domain;
    if (_leases[domain]?.token != lease.token || requiresRestart(domain)) {
      return false;
    }
    _leases.remove(domain);
    notifyListeners();
    return true;
  }
}
