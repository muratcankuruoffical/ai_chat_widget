import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final Color dotColor;

  const TypingIndicator({
    super.key,
    this.dotColor = const Color(0xFF9CA3AF),
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Stagger the animations
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, top: 4, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _animations[i],
              builder: (context, child) {
                return Container(
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  child: Transform.translate(
                    offset: Offset(0, _animations[i].value),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

