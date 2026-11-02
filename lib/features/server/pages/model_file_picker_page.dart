import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:servllama/core/services/model_file_browser.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/app_message.dart';

class ModelFilePickerPage extends StatefulWidget {
  const ModelFilePickerPage({
    super.key,
    required this.rootPath,
    required this.directoriesOnly,
    this.browser,
  });
  final String rootPath;
  final bool directoriesOnly;
  final ModelFileBrowser? browser;

  static Future<SelectedModelPath?> pick(
    BuildContext context, {
    required bool directoriesOnly,
  }) async {
    final browser = ModelFileBrowser();
    try {
      final root = await browser.requestAccess();
      if (!context.mounted) return null;
      if (root == null) {
        AppMessage.show(context, context.l10n.modelStoragePermissionRequired);
        return null;
      }
      return Navigator.push<SelectedModelPath>(
        context,
        MaterialPageRoute(
          builder: (_) => ModelFilePickerPage(
            rootPath: root,
            directoriesOnly: directoriesOnly,
            browser: browser,
          ),
        ),
      );
    } on PlatformException {
      if (context.mounted) {
        AppMessage.show(context, context.l10n.modelStoragePermissionRequired);
      }
      return null;
    }
  }

  @override
  State<ModelFilePickerPage> createState() => _ModelFilePickerPageState();
}

class _ModelFilePickerPageState extends State<ModelFilePickerPage> {
  late final ModelFileBrowser _browser = widget.browser ?? ModelFileBrowser();
  late String _directory = widget.rootPath;
  late Future<List<ModelFileEntry>> _entries = _read();
  bool _selecting = false;

  Future<List<ModelFileEntry>> _read() =>
      _browser.list(_directory, directoriesOnly: widget.directoriesOnly);

  void _open(String directory) => setState(() {
    _directory = directory;
    _entries = _read();
  });

  Future<void> _select(ModelFileEntry entry) async {
    if (_selecting) return;
    _selecting = true;
    final selection = await _browser.select(entry);
    if (mounted && ModalRoute.of(context)!.isCurrent) {
      Navigator.pop(context, selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.directoriesOnly ? l10n.modelAddMnnDir : l10n.modelAddGguf,
        ),
        actions: [
          IconButton(
            tooltip: l10n.modelPickerStorageRoot,
            onPressed: () => _open(widget.rootPath),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: IconButton(
              tooltip: l10n.modelPickerParent,
              onPressed: _directory == widget.rootPath
                  ? null
                  : () => _open(p.dirname(_directory)),
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
            title: Text(
              _directory,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<ModelFileEntry>>(
              future: _entries,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.modelPickerCannotRead,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return Center(child: Text(l10n.modelPickerEmpty));
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      leading: Icon(
                        entry.isDirectory
                            ? Icons.folder_outlined
                            : Icons.insert_drive_file_outlined,
                      ),
                      title: Text(entry.name),
                      trailing: entry.isDirectory
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: () => entry.isDirectory
                          ? _open(entry.path)
                          : _select(entry),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.directoriesOnly
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => _select(
                    ModelFileEntry(path: _directory, isDirectory: true),
                  ),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(l10n.modelPickerSelectDirectory),
                ),
              ),
            )
          : null,
    );
  }
}
