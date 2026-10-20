import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';

void main() {
  test('LLM and speech coexist while each domain admits one model', () {
    final resources = ResourceCoordinator();
    addTearDown(resources.dispose);
    final llm = resources.tryAcquire(
      kind: LocalResourceKind.llm,
      assetId: 'llm',
      owner: 'server',
    )!;
    final asr = resources.tryAcquire(
      kind: LocalResourceKind.asr,
      assetId: 'asr',
      owner: 'transcript',
    )!;
    expect(
      resources.tryAcquire(
        kind: LocalResourceKind.llm,
        assetId: 'other',
        owner: 'other',
      ),
      isNull,
    );
    expect(
      resources.tryAcquire(
        kind: LocalResourceKind.tts,
        assetId: 'tts',
        owner: 'voice',
      ),
      isNull,
    );
    resources.release(asr);
    final tts = resources.tryAcquire(
      kind: LocalResourceKind.tts,
      assetId: 'tts',
      owner: 'voice',
    );
    expect(tts, isNotNull);
    expect(resources.leaseFor(LocalResourceDomain.llm), same(llm));
    resources.release(llm);
    expect(resources.leaseFor(LocalResourceDomain.speech), same(tts));
  });

  for (final kind in [LocalResourceKind.llm, LocalResourceKind.asr]) {
    test(
      'unconfirmed ${kind.name} cleanup only quarantines its owner domain',
      () {
        final resources = ResourceCoordinator();
        addTearDown(resources.dispose);
        final affected = resources.tryAcquire(
          kind: kind,
          assetId: 'affected',
          owner: 'first',
        )!;
        resources.quarantine(affected);
        expect(resources.requiresRestart(kind.domain), isTrue);
        expect(resources.release(affected), isFalse);
        expect(resources.leaseFor(kind.domain), same(affected));
        expect(
          resources.tryAcquire(
            kind: kind,
            assetId: 'replacement',
            owner: 'next',
          ),
          isNull,
        );
        final otherKind = kind == LocalResourceKind.llm
            ? LocalResourceKind.tts
            : LocalResourceKind.llm;
        expect(resources.requiresRestart(otherKind.domain), isFalse);
        expect(
          resources.tryAcquire(
            kind: otherKind,
            assetId: 'other',
            owner: 'other',
          ),
          isNotNull,
        );
      },
    );
  }

  test('stale cleanup cannot quarantine a later speech job', () {
    final resources = ResourceCoordinator();
    addTearDown(resources.dispose);
    final old = resources.tryAcquire(
      kind: LocalResourceKind.asr,
      assetId: 'asr',
      owner: 'old',
    )!;
    resources.release(old);
    final current = resources.tryAcquire(
      kind: LocalResourceKind.tts,
      assetId: 'tts',
      owner: 'new',
    )!;
    resources.quarantine(old);
    expect(resources.requiresRestart(LocalResourceDomain.speech), isFalse);
    expect(resources.release(old), isFalse);
    expect(resources.leaseFor(LocalResourceDomain.speech), same(current));
    expect(resources.release(current), isTrue);
  });
}
