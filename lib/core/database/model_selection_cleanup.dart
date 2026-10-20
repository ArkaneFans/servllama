import 'package:servllama/core/database/app_database.dart';

/// Called in the asset deletion transaction. Historical Run snapshots are kept.
Future<void> clearMissingLocalChatTargets(AppDatabase db) async {
  await db.execute(r"""
    UPDATE assistants SET revision=revision+1,
      config=json_set(json_remove(config,'$.defaultTarget','$.target'),
        '$.chatTarget',NULL,'$.revision',revision+1)
    WHERE COALESCE(json_extract(config,'$.chatTarget.assetId'),
      json_extract(config,'$.defaultTarget.assetId'),
      json_extract(config,'$.target.assetId')) IN
      (SELECT id FROM model_assets WHERE kind='llm' AND state='missing')
  """);
}
