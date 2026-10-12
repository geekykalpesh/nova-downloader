import 'package:flutter/material.dart';
import '../../models.dart';
import '../../theme_provider.dart';

class SourceTableRow extends StatefulWidget {
  final MediaGroup group;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SourceTableRow({
    super.key,
    required this.group,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<SourceTableRow> createState() => _SourceTableRowState();
}

class _SourceTableRowState extends State<SourceTableRow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (context, _) {
        final t = ThemeProvider();

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: _isHovering ? t.surfaceLight : t.panel,
                border: Border(bottom: BorderSide(color: t.border.withOpacity(0.6))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: t.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.video_library_rounded, color: t.accent, size: 18),
                  ),
                  const SizedBox(width: 16),

                  // Name and Channel
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.group.uploader,
                          style: TextStyle(color: t.subtext, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Item Count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.border),
                    ),
                    child: Text(
                      '${widget.group.items.length} ${widget.group.items.length == 1 ? "video" : "videos"}',
                      style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: t.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('Ready', style: TextStyle(color: t.success, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(width: 24),

                  // Actions
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: t.danger, size: 19),
                    onPressed: widget.onDelete,
                    tooltip: 'Remove Source',
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
