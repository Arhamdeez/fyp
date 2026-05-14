/// Animated skeleton loading sequence with cycling phase messages.
library;

import 'package:flutter/material.dart';

import '../models/route_model.dart';

class LoadingSequence extends StatefulWidget {
  const LoadingSequence({super.key, required this.phase});

  final LoadingPhase phase;

  @override
  State<LoadingSequence> createState() => _LoadingSequenceState();
}

class _LoadingSequenceState extends State<LoadingSequence>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 24),
        // Phase message
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _PhaseMessage(
            key: ValueKey(widget.phase),
            phase: widget.phase,
            pulseCtrl: _pulseCtrl,
          ),
        ),
        const SizedBox(height: 28),
        // Skeleton cards
        for (int i = 0; i < 3; i++) ...[
          _SkeletonCard(shimmerCtrl: _shimmerCtrl, scheme: scheme, index: i),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _PhaseMessage extends StatelessWidget {
  const _PhaseMessage({
    super.key,
    required this.phase,
    required this.pulseCtrl,
  });

  final LoadingPhase phase;
  final AnimationController pulseCtrl;

  IconData _icon() => switch (phase) {
        LoadingPhase.locating => Icons.my_location_rounded,
        LoadingPhase.fetchingInsights => Icons.alt_route_rounded,
        LoadingPhase.fetchingWeather => Icons.cloud_rounded,
        LoadingPhase.analyzing => Icons.auto_awesome_rounded,
        _ => Icons.search_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, child) => Transform.scale(
            scale: 0.95 + pulseCtrl.value * 0.10,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(_icon(), color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          phase.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This won\'t take long…',
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.shimmerCtrl,
    required this.scheme,
    required this.index,
  });

  final AnimationController shimmerCtrl;
  final ColorScheme scheme;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Stagger: each card starts with slight delay
    final delay = index * 0.15;
    return AnimatedBuilder(
      animation: shimmerCtrl,
      builder: (_, child) {
        final t = (shimmerCtrl.value - delay).clamp(0.0, 1.0);
        final shimmerX = -1.0 + 3 * t;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(shimmerX - 0.5, 0),
                end: Alignment(shimmerX + 0.5, 0),
                colors: [
                  Colors.transparent,
                  scheme.surface.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ).createShader(bounds),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _bone(w: 10, h: 10, r: 5),
                        const SizedBox(width: 8),
                        _bone(w: 140, h: 14, r: 7),
                        const Spacer(),
                        _bone(w: 50, h: 32, r: 10),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _bone(w: 80, h: 36, r: 10),
                        const SizedBox(width: 12),
                        _bone(w: 70, h: 36, r: 10),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _bone(w: double.infinity, h: 8, r: 4),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _bone(w: 90, h: 26, r: 13),
                        const SizedBox(width: 8),
                        _bone(w: 80, h: 26, r: 13),
                        const SizedBox(width: 8),
                        _bone(w: 70, h: 26, r: 13),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bone({required double w, required double h, required double r}) =>
      Container(
        width: w == double.infinity ? null : w,
        height: h,
        decoration: BoxDecoration(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(r),
        ),
      );
}
