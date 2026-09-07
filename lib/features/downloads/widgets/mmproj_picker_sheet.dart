import 'package:flutter/material.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/l10n/l10n.dart';

class MmprojPickerResult {
  const MmprojPickerResult({required this.enabled, this.file});

  final bool enabled;
  final HubRepoFile? file;
}

class MmprojPickerSheet extends StatefulWidget {
  const MmprojPickerSheet({
    super.key,
    required this.files,
    this.allowDisable = true,
    this.initialEnabled = true,
    this.initialFile,
    this.title,
    this.confirmLabel,
    this.onChanged,
  });

  final List<HubRepoFile> files;
  final bool allowDisable;
  final bool initialEnabled;
  final HubRepoFile? initialFile;
  final String? title;
  final String? confirmLabel;
  final ValueChanged<MmprojPickerResult>? onChanged;

  @override
  State<MmprojPickerSheet> createState() => _MmprojPickerSheetState();
}

class _MmprojPickerSheetState extends State<MmprojPickerSheet> {
  late bool _enabled;
  HubRepoFile? _selected;

  @override
  void initState() {
    super.initState();
    _enabled = widget.allowDisable ? widget.initialEnabled : true;
    _selected = _resolveInitialFile();
  }

  HubRepoFile? _resolveInitialFile() {
    if (widget.files.isEmpty) {
      return null;
    }
    final initialPath = widget.initialFile?.path;
    if (initialPath != null) {
      for (final file in widget.files) {
        if (file.path == initialPath) {
          return file;
        }
      }
    }
    return widget.files.first;
  }

  MmprojPickerResult get _result =>
      MmprojPickerResult(enabled: _enabled, file: _selected);

  void _emit() {
    widget.onChanged?.call(_result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isLight = theme.brightness == Brightness.light;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          28 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? l10n.repoVisionSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.allowDisable) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                key: const Key('mmproj_enable_switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.repoVisionEnable),
                value: _enabled,
                onChanged: (value) {
                  setState(() => _enabled = value);
                  _emit();
                },
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.repoVisionMmprojSection,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withAlpha(220),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.files.isEmpty)
              Text(
                l10n.repoVisionNoMmproj,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Opacity(
                opacity: _enabled ? 1 : 0.45,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF5F6F8)
                        : colorScheme.surfaceContainerHighest.withAlpha(86),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: RadioGroup<String>(
                    groupValue: _selected?.path,
                    onChanged: (value) {
                      if (!_enabled || value == null) {
                        return;
                      }
                      setState(() {
                        _selected = widget.files.firstWhere(
                          (file) => file.path == value,
                        );
                      });
                      _emit();
                    },
                    child: Column(
                      children: [
                        for (var i = 0; i < widget.files.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: colorScheme.outlineVariant.withAlpha(80),
                            ),
                          RadioListTile<String>(
                            key: Key('mmproj_option_${widget.files[i].path}'),
                            value: widget.files[i].path,
                            enabled: _enabled,
                            title: Text(
                              widget.files[i].fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              FormatUtils.bytes(widget.files[i].sizeBytes),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.confirmLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('mmproj_picker_confirm_button'),
                onPressed: !_enabled || _selected == null
                    ? null
                    : () => Navigator.of(context).pop(_result),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(widget.confirmLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
