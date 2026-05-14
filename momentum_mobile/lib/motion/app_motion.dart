/// Shared motion primitives — tab entrances, route pushes, switcher transitions.
library;

import 'package:flutter/material.dart';

/// Fades / slides tab body when it becomes active ([IndexedStack] friendly).
class TabEntrance extends StatefulWidget {
  const TabEntrance({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<TabEntrance> createState() => _TabEntranceState();
}

class _TabEntranceState extends State<TabEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _opacity = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.032),
      end: Offset.zero,
    ).animate(curved);
    if (widget.active) {
      _c.value = 1;
    }
  }

  @override
  void didUpdateWidget(TabEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Full-screen route: fade + slight upward slide (in); mirrors on pop.
Route<T> fadeSlidePageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.048),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// For [AnimatedSwitcher] — incoming child fades and rises slightly.
Widget fadeSlideSwitcherChild(
  Animation<double> animation,
  Widget child, {
  Offset begin = const Offset(0, 0.022),
}) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
      child: child,
    ),
  );
}
