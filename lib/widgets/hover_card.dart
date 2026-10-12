import 'package:flutter/material.dart';

class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color baseColor;
  final Color hoverColor;
  final Border? border;
  final Border? hoverBorder;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    required this.baseColor,
    required this.hoverColor,
    this.border,
    this.hoverBorder,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) {
        setState(() => _isHovered = true);
        if (widget.onTap != null) _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        if (widget.onTap != null) _controller.reverse();
      },
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverColor : widget.baseColor,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
              border: _isHovered ? (widget.hoverBorder ?? widget.border) : widget.border,
              boxShadow: _isHovered && widget.onTap != null
                  ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]
                  : [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
