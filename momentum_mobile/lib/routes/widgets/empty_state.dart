/// Reusable empty / error state widget.
library;

import 'package:flutter/material.dart';

enum EmptyStateType {
  firstUse,
  noResults,
  noInternet,
  gpsDisabled,
  error,
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.type,
    this.message,
    this.onRetry,
  });

  final EmptyStateType type;
  final String? message;
  final VoidCallback? onRetry;

  _Config _config(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (type) {
      EmptyStateType.firstUse => _Config(
          icon: Icons.explore_rounded,
          color: scheme.primary,
          title: 'Plan a route',
          subtitle: message ??
              'Choose origin and destination, then tap Get Routes.',
          buttonLabel: null,
        ),
      EmptyStateType.noResults => _Config(
          icon: Icons.search_off_rounded,
          color: scheme.secondary,
          title: 'No Routes Found',
          subtitle: message ??
              'We couldn\'t find routes for those locations. Try different addresses.',
          buttonLabel: 'Try Again',
        ),
      EmptyStateType.noInternet => _Config(
          icon: Icons.wifi_off_rounded,
          color: scheme.error,
          title: 'No Internet Connection',
          subtitle: message ??
              'Please check your network and try again.',
          buttonLabel: 'Retry',
        ),
      EmptyStateType.gpsDisabled => _Config(
          icon: Icons.location_off_rounded,
          color: scheme.error,
          title: 'Location Access Needed',
          subtitle: message ??
              'Please enable location permissions in Settings to use GPS.',
          buttonLabel: 'Retry',
        ),
      EmptyStateType.error => _Config(
          icon: Icons.error_outline_rounded,
          color: scheme.error,
          title: 'Something Went Wrong',
          subtitle: message ?? 'An unexpected error occurred. Please try again.',
          buttonLabel: 'Retry',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: cfg.color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(cfg.icon, size: 48, color: cfg.color),
            ),
            const SizedBox(height: 24),
            Text(
              cfg.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              cfg.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (cfg.buttonLabel != null && onRetry != null) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(cfg.buttonLabel!),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Config {
  const _Config({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? buttonLabel;
}
