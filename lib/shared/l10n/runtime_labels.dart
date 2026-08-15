import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';
import 'package:servllama/features/downloads/services/device_capability_service.dart';
import 'package:servllama/features/downloads/services/model_catalog_service.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

/// Maps the typed enums the state and service layers emit to localized text.
/// Keeping this in one place is what lets those layers stay free of display
/// strings (AGENTS.md).
class RuntimeLabels {
  const RuntimeLabels._();

  static String status(AppLocalizations l10n, EngineRuntimeStatus status) {
    switch (status) {
      case EngineRuntimeStatus.idle:
        return l10n.serverStatusIdle;
      case EngineRuntimeStatus.preparing:
        return l10n.serverStatusPreparing;
      case EngineRuntimeStatus.ready:
        return l10n.serverStatusRunning;
      case EngineRuntimeStatus.stopping:
        return l10n.serverStatusStopping;
      case EngineRuntimeStatus.error:
        return l10n.serverStatusError;
    }
  }

  static String phase(AppLocalizations l10n, RuntimePhase phase) {
    switch (phase) {
      case RuntimePhase.loadingModel:
        return l10n.serverPhaseLoadingModel;
      case RuntimePhase.startingServer:
        return l10n.serverPhaseStartingServer;
      case RuntimePhase.verifying:
        return l10n.serverPhaseVerifying;
      case RuntimePhase.unloadingModel:
        return l10n.serverPhaseUnloadingModel;
      case RuntimePhase.stoppingServer:
        return l10n.serverPhaseStoppingServer;
    }
  }

  static String runtimeError(
    AppLocalizations l10n,
    EngineRuntimeError error,
    int port,
  ) {
    switch (error.kind) {
      case EngineRuntimeErrorKind.portInUse:
        return l10n.runtimeErrorPortInUse(port);
      case EngineRuntimeErrorKind.modelLoadFailed:
        return l10n.runtimeErrorModelLoadFailed;
      case EngineRuntimeErrorKind.serverStartFailed:
        return l10n.runtimeErrorServerStartFailed;
      case EngineRuntimeErrorKind.serverStopFailed:
        return l10n.runtimeErrorServerStopFailed;
      case EngineRuntimeErrorKind.modelRequired:
        return l10n.runtimeErrorModelRequired;
      case EngineRuntimeErrorKind.engineUnavailable:
        return l10n.runtimeErrorEngineUnavailable;
      case EngineRuntimeErrorKind.unknown:
        return l10n.runtimeErrorUnknown(error.detail ?? '');
    }
  }

  static String uptime(AppLocalizations l10n, Duration duration) {
    if (duration.inHours >= 1) {
      return l10n.serverUptimeHoursMinutes(
        duration.inHours,
        duration.inMinutes % 60,
      );
    }
    return l10n.serverUptimeMinutes(duration.inMinutes);
  }

  static String downloadStatus(AppLocalizations l10n, DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return l10n.downloadStatusQueued;
      case DownloadStatus.running:
        return l10n.downloadStatusRunning;
      case DownloadStatus.paused:
        return l10n.downloadStatusPaused;
      case DownloadStatus.failed:
        return l10n.downloadStatusFailed;
      case DownloadStatus.downloaded:
        return l10n.downloadStatusDownloaded;
      case DownloadStatus.completed:
        return l10n.downloadStatusCompleted;
    }
  }

  static String downloadError(AppLocalizations l10n, String detail) {
    for (final kind in DownloadErrorKind.values) {
      if (kind.name != detail) {
        continue;
      }
      switch (kind) {
        case DownloadErrorKind.network:
          return l10n.downloadErrorNetwork;
        case DownloadErrorKind.unauthorized:
          return l10n.downloadErrorUnauthorized;
        case DownloadErrorKind.notFound:
          return l10n.downloadErrorNotFound;
        case DownloadErrorKind.diskFull:
          return l10n.downloadErrorDiskFull;
        case DownloadErrorKind.integrity:
          return l10n.downloadErrorIntegrity;
        case DownloadErrorKind.cancelled:
          return l10n.downloadErrorCancelled;
        case DownloadErrorKind.alreadyQueued:
          return l10n.downloadErrorAlreadyQueued;
      }
    }
    return detail;
  }

  static String hubError(AppLocalizations l10n, ModelHubErrorKind kind) {
    switch (kind) {
      case ModelHubErrorKind.network:
        return l10n.discoverErrorNetwork;
      case ModelHubErrorKind.unauthorized:
        return l10n.discoverErrorUnauthorized;
      case ModelHubErrorKind.notFound:
        return l10n.discoverErrorNotFound;
      case ModelHubErrorKind.malformedResponse:
        return l10n.discoverErrorMalformed;
    }
  }

  static String feasibility(AppLocalizations l10n, ModelFeasibility value) {
    switch (value) {
      case ModelFeasibility.comfortable:
        return l10n.feasibilityComfortable;
      case ModelFeasibility.tight:
        return l10n.feasibilityTight;
      case ModelFeasibility.notEnoughMemory:
        return l10n.feasibilityNotEnoughMemory;
      case ModelFeasibility.unknown:
        return l10n.feasibilityUnknown;
    }
  }

  static String capability(AppLocalizations l10n, ModelCapability capability) {
    switch (capability) {
      case ModelCapability.chinese:
        return l10n.modelCapabilityChinese;
      case ModelCapability.english:
        return l10n.modelCapabilityEnglish;
      case ModelCapability.vision:
        return l10n.modelCapabilityVision;
      case ModelCapability.toolCalling:
        return l10n.modelCapabilityToolCalling;
    }
  }

  /// The catalog asset stores an ARB key so it can stay language-neutral.
  static String catalogSummary(AppLocalizations l10n, String summaryKey) {
    switch (summaryKey) {
      case 'verifiedSmallGeneralist':
        return l10n.catalogSummaryVerifiedSmallGeneralist;
      case 'verifiedEntryLevel':
        return l10n.catalogSummaryVerifiedEntryLevel;
      case 'verifiedBalanced':
        return l10n.catalogSummaryVerifiedBalanced;
      case 'verifiedMnnDefault':
        return l10n.catalogSummaryVerifiedMnnDefault;
      case 'verifiedMnnBalanced':
        return l10n.catalogSummaryVerifiedMnnBalanced;
      case 'verifiedMnnVision':
        return l10n.catalogSummaryVerifiedMnnVision;
      default:
        return '';
    }
  }
}
