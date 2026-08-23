import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/l10n/l10n.dart';

/// Guards a download-start or resume action behind the Wi-Fi-only policy.
///
/// The policy (DownloadSettings.wifiOnly) silently pauses transfers whenever the
/// device is on a metered connection. That is the right default, but starting a
/// download or tapping "resume" only for it to be paused again with no feedback
/// feels broken. This helper checks the policy up front: when it would block,
/// it asks the user once whether to lift the restriction (turning Wi-Fi-only
/// off). Returns true when the caller may proceed — either the policy does not
/// apply, or the user chose to disable it.
///
/// Returns false when the dialog is dismissed/cancelled, in which case the
/// caller should do nothing.
Future<bool> confirmDownloadOnMeteredNetwork(BuildContext context) async {
  final downloads = context.read<DownloadProvider>();
  final blocked = await downloads.isBlockedByWifiOnlyPolicy();
  if (!blocked) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }

  final l10n = context.l10n;
  final allow = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.signal_cellular_alt_rounded),
      title: Text(l10n.downloadWifiOnlyDialogTitle),
      content: Text(l10n.downloadWifiOnlyDialogMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.downloadWifiOnlyDialogAllow),
        ),
      ],
    ),
  );

  if (allow != true) {
    return false;
  }
  if (!context.mounted) {
    return false;
  }
  // Turning the restriction off persists it, so the user is not prompted again
  // until they re-enable Wi-Fi-only downloads in Settings.
  await downloads.setWifiOnly(false);
  return true;
}
