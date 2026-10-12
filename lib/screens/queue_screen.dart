import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../download_manager.dart';
import '../theme_provider.dart';
import '../yt_dlp_service.dart';
import '../widgets/download_table_row.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final Set<String> _selectedTaskIds = {};
  String _searchQuery = '';
  int _activeTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tabs = ['All', 'Downloading', 'Completed', 'Paused', 'Failed'];

  void _toggleSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedTaskIds.add(id);
      } else {
        _selectedTaskIds.remove(id);
      }
    });
  }

  void _selectAll(List<DownloadTaskModel> tasks, bool selected) {
    setState(() {
      if (selected) {
        _selectedTaskIds.addAll(tasks.map((t) => t.id));
      } else {
        _selectedTaskIds.clear();
      }
    });
  }

  void _showAddDownloadDialog(BuildContext context, ThemeProvider t) {
    final urlController = TextEditingController();
    VideoQuality selectedQuality = VideoQuality.best;
    bool isAnalyzing = false;
    String error = '';

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) {
          return AlertDialog(
            backgroundColor: t.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: t.border),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_link_rounded, color: t.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Add New Download', style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YouTube Video or Playlist URL', style: TextStyle(color: t.subtext, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlController,
                    style: TextStyle(color: t.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'https://www.youtube.com/watch?v=...',
                      hintStyle: TextStyle(color: t.subtext.withOpacity(0.6), fontSize: 13),
                      filled: true,
                      fillColor: t.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.accent, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Preferred Quality', style: TextStyle(color: t.subtext, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.border),
                    ),
                    child: DropdownButton<VideoQuality>(
                      value: selectedQuality,
                      isExpanded: true,
                      dropdownColor: t.surface,
                      underline: const SizedBox(),
                      style: TextStyle(color: t.text, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: VideoQuality.best, child: Text('Best Available Quality (1080p / 4K)')),
                        DropdownMenuItem(value: VideoQuality.p1080, child: Text('1080p Full HD')),
                        DropdownMenuItem(value: VideoQuality.p720, child: Text('720p HD')),
                        DropdownMenuItem(value: VideoQuality.audio, child: Text('Audio Only (MP3)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedQuality = val);
                      },
                    ),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(error, style: TextStyle(color: t.danger, fontSize: 12)),
                  ],
                  if (isAnalyzing) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.accent)),
                        const SizedBox(width: 12),
                        Text('Analyzing link...', style: TextStyle(color: t.subtext, fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isAnalyzing ? null : () => Navigator.pop(c),
                child: Text('Cancel', style: TextStyle(color: t.subtext)),
              ),
              ElevatedButton(
                onPressed: isAnalyzing
                    ? null
                    : () async {
                        final rawUrl = urlController.text.trim();
                        if (rawUrl.isEmpty) return;

                        setDialogState(() {
                          isAnalyzing = true;
                          error = '';
                        });

                        try {
                          final group = await YtDlpService().fetchMetadata(rawUrl, quality: selectedQuality);
                          final prefs = await SharedPreferences.getInstance();
                          String dir = prefs.getString('default_dir') ?? '';
                          if (dir.isEmpty) {
                            final defaultDir = await getDownloadsDirectory();
                            dir = defaultDir?.path ?? '';
                          }

                          for (var i = 0; i < group.items.length; i++) {
                            DownloadManager().addTask(group.items[i], dir, playlistIndex: group.items.length > 1 ? i : null);
                          }

                          if (c.mounted) Navigator.pop(c);
                        } catch (e) {
                          setDialogState(() {
                            isAnalyzing = false;
                            error = 'Failed to analyze URL: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Download'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (context, _) {
        final t = ThemeProvider();

        return Container(
          color: t.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: t.panel,
                  border: Border(bottom: BorderSide(color: t.border)),
                ),
                child: Row(
                  children: [
                    // Primary Action: Add Download Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Download', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showAddDownloadDialog(context, t),
                    ),
                    const SizedBox(width: 14),

                    // Selection or Global Actions
                    if (_selectedTaskIds.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: t.accentLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_selectedTaskIds.length} selected',
                          style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildToolbarButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Resume',
                        color: t.success,
                        onPressed: () {
                          for (final id in _selectedTaskIds) {
                            DownloadManager().resumeTask(id);
                          }
                          setState(() => _selectedTaskIds.clear());
                        },
                        t: t,
                      ),
                      const SizedBox(width: 6),
                      _buildToolbarButton(
                        icon: Icons.pause_rounded,
                        label: 'Pause',
                        color: t.warning,
                        onPressed: () {
                          for (final id in _selectedTaskIds) {
                            DownloadManager().pauseTask(id);
                          }
                        },
                        t: t,
                      ),
                      const SizedBox(width: 6),
                      _buildToolbarButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Remove',
                        color: t.danger,
                        onPressed: () {
                          for (final id in _selectedTaskIds) {
                            DownloadManager().removeTask(id);
                          }
                          setState(() => _selectedTaskIds.clear());
                        },
                        t: t,
                      ),
                    ] else ...[
                      _buildToolbarButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Resume All',
                        color: t.text,
                        onPressed: () => DownloadManager().resumeAll(),
                        t: t,
                      ),
                      const SizedBox(width: 6),
                      _buildToolbarButton(
                        icon: Icons.pause_rounded,
                        label: 'Pause All',
                        color: t.text,
                        onPressed: () => DownloadManager().pauseAll(),
                        t: t,
                      ),
                    ],

                    const Spacer(),

                    // Search Input Box
                    Container(
                      width: 240,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: t.text, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search downloads...',
                          hintStyle: TextStyle(color: t.subtext.withOpacity(0.7), fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: t.subtext),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, size: 16, color: t.subtext),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Tabs with Counters
              ListenableBuilder(
                listenable: DownloadManager(),
                builder: (context, _) {
                  final allTasks = DownloadManager().tasks;
                  final downloadingCount = allTasks.where((x) => x.status == DownloadStatus.downloading).length;
                  final completedCount = allTasks.where((x) => x.status == DownloadStatus.completed).length;
                  final pausedCount = allTasks.where((x) => x.status == DownloadStatus.paused).length;
                  final failedCount = allTasks.where((x) => x.status == DownloadStatus.error).length;

                  final counts = [allTasks.length, downloadingCount, completedCount, pausedCount, failedCount];

                  return Container(
                    height: 44,
                    color: t.panel,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: List.generate(_tabs.length, (index) {
                        final isSelected = _activeTabIndex == index;
                        final count = counts[index];

                        return InkWell(
                          onTap: () => setState(() => _activeTabIndex = index),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected ? t.accent : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Row(
                                children: [
                                  Text(
                                    _tabs[index],
                                    style: TextStyle(
                                      color: isSelected ? t.text : t.subtext,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? t.accentLight : t.surfaceLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: isSelected ? t.accent : t.subtext,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),

              // Table Header
              ListenableBuilder(
                listenable: DownloadManager(),
                builder: (context, _) {
                  final allTasks = DownloadManager().tasks;
                  final allSelected = allTasks.isNotEmpty && _selectedTaskIds.length == allTasks.length;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: t.bg,
                      border: Border(bottom: BorderSide(color: t.border.withOpacity(0.7))),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Checkbox(
                            value: allSelected,
                            onChanged: (val) => _selectAll(allTasks, val ?? false),
                            activeColor: t.accent,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const SizedBox(width: 88), // Thumbnail space
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 6,
                          child: Text(
                            'VIDEO & PROGRESS',
                            style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'STATUS',
                            style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 110,
                          child: Text(
                            'ACTIONS',
                            style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Task List or Empty State
              Expanded(
                child: ListenableBuilder(
                  listenable: DownloadManager(),
                  builder: (context, _) {
                    final allTasks = DownloadManager().tasks;

                    // Filter logic
                    var filteredTasks = allTasks.where((task) {
                      if (_searchQuery.isNotEmpty && !task.video.title.toLowerCase().contains(_searchQuery)) {
                        return false;
                      }

                      switch (_activeTabIndex) {
                        case 1:
                          return task.status == DownloadStatus.downloading;
                        case 2:
                          return task.status == DownloadStatus.completed;
                        case 3:
                          return task.status == DownloadStatus.paused;
                        case 4:
                          return task.status == DownloadStatus.error;
                        default:
                          return true;
                      }
                    }).toList();

                    if (filteredTasks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: t.surfaceLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.download_done_rounded, size: 48, color: t.subtext),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty ? 'No downloads match "$_searchQuery"' : 'No downloads here',
                              style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try searching with a different keyword.'
                                  : 'Click "+ Add Download" above or explore My Sources to get started.',
                              style: TextStyle(color: t.subtext, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Download'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: t.accent,
                                side: BorderSide(color: t.accent),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showAddDownloadDialog(context, t),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return DownloadTableRow(
                          key: ValueKey(task.id),
                          task: task,
                          isSelected: _selectedTaskIds.contains(task.id),
                          onSelect: (val) => _toggleSelection(task.id, val ?? false),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required ThemeProvider t,
  }) {
    return TextButton.icon(
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        backgroundColor: t.surfaceLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: onPressed,
    );
  }
}
