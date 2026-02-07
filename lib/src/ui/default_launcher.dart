import 'package:flutter/material.dart';

class DefaultChatLauncher extends StatefulWidget {
  final VoidCallback onTap;
  final Color backgroundColor;
  final bool isOpen;

  const DefaultChatLauncher({
    super.key,
    required this.onTap,
    required this.backgroundColor,
    this.isOpen = false,
  });

  @override
  State<DefaultChatLauncher> createState() => _DefaultChatLauncherState();
}

class _DefaultChatLauncherState extends State<DefaultChatLauncher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.backgroundColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              widget.isOpen ? Icons.close : Icons.chat_bubble_rounded,
              key: ValueKey(widget.isOpen),
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
