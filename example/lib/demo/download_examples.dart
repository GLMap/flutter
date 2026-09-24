import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glmap/glmap.dart';

import 'common.dart';

class DownloadMapsDemo extends StatefulWidget {
  const DownloadMapsDemo({
    super.key,
    this.parent,
    this.title = 'Download Maps',
  });
  final int? parent;
  final String title;
  @override
  State<DownloadMapsDemo> createState() => _DownloadMapsDemoState();
}

class _DownloadMapsDemoState extends State<DownloadMapsDemo> {
  List<GLMapRegion> regions = [];
  final progress = <(int, int), GLMapDownloadProgress>{};
  StreamSubscription<GLMapDownloadProgress>? subscription;
  String query = '', status = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    subscription = GLMapSDK.downloads.listen((event) {
      if (!mounted || event.area) return;
      setState(() => progress[(event.id, event.dataSet)] = event);
      if (event.finished) {
        if (event.error != null) setState(() => status = event.error!);
        load();
      }
    });
    load(refresh: widget.parent == null);
  }

  Future<void> load({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        busy = true;
        status = '';
      });
    }
    try {
      final result = await GLMapSDK.regions(
        parent: widget.parent,
        refresh: refresh,
      );
      if (mounted) {
        setState(
          () => regions = result..sort((a, b) => a.name.compareTo(b.name)),
        );
      }
    } catch (error) {
      if (mounted) setState(() => status = describeError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(Future<void> Function() action) async {
    try {
      await action();
      await load();
    } catch (error) {
      if (mounted) setState(() => status = describeError(error));
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = regions
        .where((r) => r.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh catalog',
            onPressed: () => load(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search regions',
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          if (status.isNotEmpty)
            Padding(padding: const EdgeInsets.all(12), child: Text(status)),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final r = visible[index];
                final tasks = progress.values
                    .where((p) => p.id == r.id && !p.finished)
                    .toList();
                final active = tasks.isNotEmpty || r.downloadingMask != 0;
                final downloaded = tasks.fold<int>(
                  0,
                  (sum, p) => sum + p.downloaded,
                );
                final total = tasks.fold<int>(0, (sum, p) => sum + p.total);
                return ListTile(
                  leading: Icon(
                    r.isCollection
                        ? Icons.folder_outlined
                        : r.downloadedMask != 0
                        ? Icons.offline_pin_outlined
                        : Icons.map_outlined,
                  ),
                  title: Text(r.name),
                  subtitle: Text(
                    active
                        ? 'Downloading ${total > 0 ? (100 * downloaded / total).toStringAsFixed(0) : '…'}%'
                        : r.isCollection
                        ? 'Browse regions'
                        : r.downloadedMask != 0
                        ? 'On device · ${(r.localBytes / 1e6).toStringAsFixed(1)} MB'
                        : '${(r.downloadBytes / 1e6).toStringAsFixed(1)} MB',
                  ),
                  onTap: r.isCollection
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DownloadMapsDemo(parent: r.id, title: r.name),
                          ),
                        )
                      : () =>
                            act(active ? r.cancelDownload : () => r.download()),
                  trailing: r.isCollection
                      ? const Icon(Icons.chevron_right)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: active
                                  ? 'Cancel download'
                                  : 'Download datasets',
                              onPressed: () => act(
                                active ? r.cancelDownload : () => r.download(),
                              ),
                              icon: Icon(active ? Icons.close : Icons.download),
                            ),
                            if (r.downloadedMask != 0)
                              IconButton(
                                tooltip: 'Delete downloaded data',
                                onPressed: () async {
                                  final yes = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Delete ${r.name}?'),
                                      content: const Text(
                                        'Remove downloaded datasets from this demo.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (yes == true) await act(() => r.delete());
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadBBoxDemo extends StatefulWidget {
  const DownloadBBoxDemo({super.key});
  @override
  State<DownloadBBoxDemo> createState() => _DownloadBBoxDemoState();
}

class _DownloadBBoxDemoState extends MapDemoState<DownloadBBoxDemo> {
  GLMapRequest<void>? request;
  StreamSubscription<GLMapDownloadProgress>? subscription;
  @override
  String get title => 'Download BBox';
  @override
  String get api => 'GLMapManager · map + navigation + elevation for an area';
  @override
  Future<void> ready(GLMapController controller) async {
    await controller.fitBounds(townBounds);
    subscription = GLMapSDK.downloads.listen((event) {
      if (event.area && event.id == request?.id) {
        message(
          '${GLMapDataSet.values[event.dataSet].name}: ${event.total > 0 ? (100 * event.downloaded / event.total).toStringAsFixed(0) : '…'}%${event.error == null ? '' : ' · ${event.error}'}',
        );
      }
    });
  }

  Future<void> download() async {
    request = GLMapSDK.downloadArea(townBounds);
    message('Downloading three datasets…');
    await request!.result;
    await map!.setOnlineTiles(false);
    message('Area downloaded and registered with the SDK');
  }

  @override
  Widget controls() => Wrap(
    spacing: 8,
    children: [
      button('Download this area', download),
      OutlinedButton(
        onPressed: request == null ? null : () => request!.cancel(),
        child: const Text('Cancel'),
      ),
    ],
  );
  @override
  void dispose() {
    subscription?.cancel();
    request?.cancel();
    super.dispose();
  }
}
