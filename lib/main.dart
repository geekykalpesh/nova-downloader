import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:tray_manager/legacy.dart';
import 'package:flutter/services.dart';

import 'yt_dlp_service.dart';
import 'download_manager.dart';
import 'theme_provider.dart';
import 'screens/sources_screen.dart';
import 'screens/queue_screen.dart';
import 'models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Color(0xFF0F172A),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Nova Downloader Pro',
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setTitle('Nova Downloader Pro');
      await windowManager.show();
      await windowManager.focus();
    });

    // Initialize system tray
    try {
      await trayManager.setIcon('assets/tray_icon.png');
      await trayManager.setToolTip('Nova Downloader Pro');
      await trayManager.setContextMenu(Menu(
        items: [
          MenuItem(key: 'show', label: 'Show Window'),
          MenuItem(key: 'hide', label: 'Hide Window'),
          MenuItem(key: 'exit', label: 'Exit'),
        ],
      ));
      trayManager.addListener(MyTrayListener());
    } catch (e) {
      debugPrint('Tray initialization note: $e');
    }

    // Prevent close button from exiting; minimize to tray
    await windowManager.setPreventClose(true);
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (context, _) {
        final t = ThemeProvider();
        return MaterialApp(
          title: 'Nova Downloader Pro',
          debugShowCheckedModeBanner: false,
          theme: t.themeData,
          home: const AppShell(),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _isInitializing = true;
  String _initStatus = 'Initializing engine...';
  double _initProgress = 0.0;
  String _lastClipboardUrl = '';
  Timer? _clipboardTimer;

  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onExitRequested: () async {
        DownloadManager().pauseAll();
        return AppExitResponse.exit;
      },
    );
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkClipboard());
    _initializeApp();
  }

  @override
  void dispose() {
    _listener.dispose();
    _clipboardTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty && text != _lastClipboardUrl) {
        if (text.startsWith('http') && 
           (text.contains('youtu.be') || text.contains('youtube.com') || text.endsWith('.mp4') || text.endsWith('.m3u8'))) {
          _lastClipboardUrl = text;
          if (mounted && !_isInitializing) {
            _promptClipboardDownload(text);
          }
        }
      }
    } catch (_) {}
  }

  void _promptClipboardDownload(String url) {
    final t = ThemeProvider();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.border)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: t.accentLight, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.link_rounded, color: t.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Link Detected!', style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Would you like to download this detected media link?', style: TextStyle(color: t.subtext, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.border)),
              child: Text(url, style: TextStyle(color: t.text, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Ignore', style: TextStyle(color: t.subtext))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: t.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(c);
              setState(() { _isInitializing = true; _initStatus = 'Analyzing clipboard link...'; });
              try {
                final group = await YtDlpService().fetchMetadata(url, quality: VideoQuality.best);
                final prefs = await SharedPreferences.getInstance();
                String dir = prefs.getString('default_dir') ?? '';
                if (dir.isEmpty) {
                  final defaultDir = await getDownloadsDirectory();
                  dir = defaultDir?.path ?? '';
                }
                
                for (var i = 0; i < group.items.length; i++) {
                  DownloadManager().addTask(group.items[i], dir, playlistIndex: group.items.length > 1 ? i : null);
                }
                
                if (mounted) setState(() { _selectedIndex = 0; _isInitializing = false; });
              } catch (_) {
                if (mounted) setState(() { _isInitializing = false; });
              }
            },
            child: const Text('Download Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    await DownloadManager().init();
    try {
      await YtDlpService().init((progress, message) {
        if (mounted) setState(() { _initProgress = progress; _initStatus = message; });
      });
      if (prefs.getString('default_dir') == null) {
        final defaultDir = await getDownloadsDirectory();
        if (defaultDir != null) await prefs.setString('default_dir', defaultDir.path);
      }
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) setState(() => _initStatus = 'Error: $e');
    }
  }

  void _showSettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    String? currentDir = prefs.getString('default_dir');
    String currentBrowser = prefs.getString('browser') ?? 'None';

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) {
          final t = ThemeProvider();
          return AlertDialog(
            backgroundColor: t.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.border)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: t.accentLight, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.settings_rounded, color: t.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Application Settings', style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DEFAULT DOWNLOAD DIRECTORY', style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(8)),
                          child: Text(currentDir ?? 'Not Set', style: TextStyle(color: t.text, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Browse'),
                        onPressed: () async {
                          final result = await FilePicker.getDirectoryPath();
                          if (result != null) {
                            await prefs.setString('default_dir', result);
                            setDialogState(() => currentDir = result);
                            setState(() {});
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('COOKIE EXTRACTION (FOR AGE-RESTRICTED CONTENT)', style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButton<String>(
                      value: currentBrowser,
                      isExpanded: true,
                      dropdownColor: t.surface,
                      underline: const SizedBox(),
                      style: TextStyle(color: t.text, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'None', child: Text('None (Default)')),
                        DropdownMenuItem(value: 'chrome', child: Text('Google Chrome')),
                        DropdownMenuItem(value: 'edge', child: Text('Microsoft Edge')),
                        DropdownMenuItem(value: 'brave', child: Text('Brave')),
                        DropdownMenuItem(value: 'firefox', child: Text('Firefox')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await prefs.setString('browser', val);
                          setDialogState(() => currentBrowser = val);
                        }
                      },
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text('Done', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (context, _) {
        final t = ThemeProvider();
        
        if (_isInitializing) {
          return Scaffold(
            backgroundColor: t.bg,
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: t.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text('Nova Downloader Pro', style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 8),
                    Text(_initStatus, style: TextStyle(color: t.subtext, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _initProgress > 0 ? _initProgress : null,
                        color: t.accent,
                        backgroundColor: t.border,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: t.bg,
          appBar: AppBar(
            backgroundColor: t.panel,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text('Nova Downloader', style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.accentLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: t.accent.withOpacity(0.4)),
                  ),
                  child: Text('PRO', style: TextStyle(color: t.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ],
            ),
            actions: [
              // Theme Toggle Button
              IconButton(
                icon: Icon(
                  t.isDarkMode ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                  color: t.subtext,
                  size: 20,
                ),
                onPressed: t.toggleTheme,
                tooltip: t.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              ),
              const SizedBox(width: 4),

              // Settings Button
              IconButton(
                icon: Icon(Icons.settings_outlined, color: t.subtext, size: 20),
                onPressed: () => _showSettings(context),
                tooltip: 'Settings',
              ),
              const SizedBox(width: 16),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: t.border, height: 1),
            ),
          ),
          body: Row(
            children: [
              // Modern Desktop Sidebar
              Container(
                width: 230,
                color: t.panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Text(
                        'LIBRARY',
                        style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Downloads Sidebar item with live count
                    ListenableBuilder(
                      listenable: DownloadManager(),
                      builder: (context, _) {
                        final count = DownloadManager().tasks.length;
                        return _buildSidebarItem(
                          context,
                          0,
                          Icons.download_rounded,
                          'Downloads',
                          badgeCount: count > 0 ? count : null,
                          t: t,
                        );
                      },
                    ),

                    // Sources Sidebar item
                    _buildSidebarItem(
                      context,
                      1,
                      Icons.video_library_rounded,
                      'My Sources',
                      t: t,
                    ),

                    const Spacer(),

                    // Bottom info card in sidebar
                    Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.folder_outlined, size: 16, color: t.accent),
                              const SizedBox(width: 8),
                              Text('Downloads Folder', style: TextStyle(color: t.text, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FutureBuilder<SharedPreferences>(
                            future: SharedPreferences.getInstance(),
                            builder: (context, snapshot) {
                              final dir = snapshot.data?.getString('default_dir') ?? 'Default';
                              final shortDir = dir.length > 22 ? '...${dir.substring(dir.length - 19)}' : dir;
                              return Text(shortDir, style: TextStyle(color: t.subtext, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis);
                            },
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Nova Downloader v2.1.0', style: TextStyle(color: t.subtext.withOpacity(0.5), fontSize: 10)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Vertical Border Divider
              Container(width: 1, color: t.border),
              
              // Main Content Area
              Expanded(
                child: _selectedIndex == 0 
                    ? const QueueScreen() 
                    : const SourcesScreen(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarItem(
    BuildContext context,
    int index,
    IconData icon,
    String label, {
    int? badgeCount,
    required ThemeProvider t,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(8),
        hoverColor: t.surfaceLight,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? t.accentLight : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? t.accent : t.subtext,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? t.text : t.subtext,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              if (badgeCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? t.accent : t.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      color: isSelected ? Colors.white : t.subtext,
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
  }
}

// Tray menu listener implementation
class MyTrayListener extends TrayListener {
  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem item) async {
    switch (item.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'hide':
        await windowManager.hide();
        break;
      case 'exit':
        await windowManager.destroy();
        exit(0);
    }
  }
}
