enum LegacyMigrationStage {
  chats,
  models,
  downloads,
  writing,
  verifying,
  complete,
}

class LegacyMigrationProgress {
  const LegacyMigrationProgress(
    this.stage, {
    this.completed = 0,
    this.total = 0,
  });
  final LegacyMigrationStage stage;
  final int completed;
  final int total;
}
