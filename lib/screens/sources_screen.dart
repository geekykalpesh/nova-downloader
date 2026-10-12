import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../yt_dlp_service.dart';
import '../theme_provider.dart';
import 'playlist_screen.dart';
import '../widgets/shimmer_effect.dart';
import '../download_manager.dart';
import '../widgets/source_table_row.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});
  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final TextEditingController _urlController = TextEditingController();
  final List<MediaGroup> _groups = [];
  bool _isFetching = false;
  String _error = '';
  VideoQuality _selectedQuality = VideoQuality.best;

  @override
  void initState() {
    super.initState();
    _loadSavedSources();
  }

  Future<void> _loadSavedSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('saved_sources');
      if (list != null) {
        setState(() {
          _groups.clear();
          for (final item in list) {
            _groups.add(MediaGroup.fromJson(jsonDecode(item)));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetch() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) return;
    setState(() { _isFetching = true; _error = ''; });
    try {
      final group = await YtDlpService().fetchMetadata(rawUrl, quality: _selectedQuality);
      if (mounted) {
        setState(() {
          _groups.insert(0, group);
          _isFetching = false;
          _urlController.clear();
        });
        final prefs = await SharedPreferences.getInstance();
        final jsonList = _groups.map((g) => jsonEncode(g.toJson())).toList();
        await prefs.setStringList('saved_sources', jsonList);
      }
    } catch (e) {
      if (mounted) setState(() { _isFetching = false; _error = 'Error loading source: $e'; });
    }
  }

  void _deleteGroup(String id) async {
    final prefs = await SharedPreferences.getInstance();
    
    final matches = _groups.where((g) => g.id == id);
    final groupToDelete = matches.isEmpty ? null : matches.first;
    if (groupToDelete != null) {
      final videoIds = groupToDelete.items.map((v) => v.id).toSet();
      final tasksToRemove = DownloadManager().tasks.where((t) => videoIds.contains(t.video.id)).toList();
      for (final task in tasksToRemove) {
        DownloadManager().removeTask(task.id, deleteFile: false);
      }
    }

    setState(() {
      _groups.removeWhere((g) => g.id == id);
    });
    
    final jsonList = _groups.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList('saved_sources', jsonList);
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
              // Top URL input bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: t.panel,
                  border: Border(bottom: BorderSide(color: t.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.border),
                        ),
                        child: TextField(
                          controller: _urlController,
                          style: TextStyle(color: t.text, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Paste YouTube Video or Playlist URL...',
                            hintStyle: TextStyle(color: t.subtext.withOpacity(0.7), fontSize: 13),
                            prefixIcon: Icon(Icons.add_link_rounded, color: t.accent, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (_) => _fetch(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: t.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.border),
                      ),
                      child: DropdownButton<VideoQuality>(
                        value: _selectedQuality,
                        dropdownColor: t.surface,
                        underline: const SizedBox(),
                        style: TextStyle(color: t.text, fontWeight: FontWeight.w500, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: VideoQuality.best, child: Text('Best Quality')),
                          DropdownMenuItem(value: VideoQuality.p1080, child: Text('1080p HD')),
                          DropdownMenuItem(value: VideoQuality.p720, child: Text('720p HD')),
                          DropdownMenuItem(value: VideoQuality.audio, child: Text('Audio (MP3)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedQuality = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isFetching ? null : _fetch,
                      icon: _isFetching
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.panel))
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(_isFetching ? 'Fetching...' : 'Fetch Source', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error.isNotEmpty)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: t.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error, style: TextStyle(color: t.danger, fontSize: 12))),
                    ],
                  ),
                ),

              // Content Area
              Expanded(
                child: _isFetching
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: 4,
                        itemBuilder: (c, i) => Container(
                          height: 60,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: const ShimmerBox(borderRadius: BorderRadius.all(Radius.circular(8))),
                        ),
                      )
                    : _groups.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: t.surfaceLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.video_library_outlined, size: 48, color: t.subtext),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No saved sources yet',
                                  style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Paste a YouTube Video or Playlist URL above to inspect and download its contents.',
                                  style: TextStyle(color: t.subtext, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: t.bg,
                                  border: Border(bottom: BorderSide(color: t.border.withOpacity(0.7))),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 36 + 16),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'TITLE & CHANNEL',
                                        style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        'ITEMS',
                                        style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        'STATUS',
                                        style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                      ),
                                    ),
                                    const SizedBox(width: 24 + 40),
                                  ],
                                ),
                              ),

                              // Source List
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _groups.length,
                                  itemBuilder: (context, index) {
                                    final group = _groups[index];
                                    return SourceTableRow(
                                      group: group,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PlaylistDetailScreen(group: group),
                                          ),
                                        );
                                      },
                                      onDelete: () => _deleteGroup(group.id),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
