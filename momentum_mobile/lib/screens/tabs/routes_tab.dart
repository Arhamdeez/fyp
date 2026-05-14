/// Routes tab — complete production rebuild.
///
/// Architecture: ChangeNotifier singleton (RoutesStore) + ListenableBuilder.
/// No Riverpod — matches the existing app-wide pattern.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/momentum_api.dart';
import '../../motion/app_motion.dart';
import '../../routes/models/route_model.dart';
import '../../routes/models/saved_route.dart';
import '../../routes/stores/routes_store.dart';
import '../../routes/widgets/empty_state.dart';
import '../../routes/widgets/loading_sequence.dart';
import '../../routes/widgets/route_card.dart';
import '../../routes/widgets/route_detail_sheet.dart';
import '../../routes/widgets/route_search_bar.dart';

class RoutesTab extends StatefulWidget {
  const RoutesTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<RoutesTab> createState() => _RoutesTabState();
}

class _RoutesTabState extends State<RoutesTab>
    with AutomaticKeepAliveClientMixin {
  final RoutesStore _store = RoutesStore.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _store.init();
  }

  void _onCardTap(RouteOption route) {
    _store.selectRoute(route);
    showRouteDetailSheet(context, route);
  }

  void _onRetry() => _store.search(widget.api);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: scheme.surface,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Collapsible header ──────────────────────────────────────
              SliverAppBar(
                pinned: true,
                floating: false,
                expandedHeight: 0,
                backgroundColor: scheme.surface,
                surfaceTintColor: Colors.transparent,
                title: const _RoutesHeader(),
                centerTitle: false,
                actions: [
                  if (_store.savedRoutes.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.bookmark_rounded),
                      tooltip: 'Saved routes',
                      onPressed: () => _showSavedSheet(context),
                    ),
                ],
              ),

              // ── Search bar ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: RouteSearchBar(api: widget.api),
              ),

              // ── Body content ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) =>
                      fadeSlideSwitcherChild(animation, child),
                  child: _buildBody(scheme),
                ),
              ),

              // Bottom padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    // Loading
    if (_store.isLoading) {
      return LoadingSequence(
        key: const ValueKey('loading'),
        phase: _store.phase,
      );
    }

    // Error — but only when there are no routes (could be a retry)
    if (_store.error != null && _store.routes.isEmpty) {
      return Padding(
        key: const ValueKey('error'),
        padding: const EdgeInsets.only(top: 60),
        child: EmptyState(
          type: _errorType(_store.error!),
          message: _store.error,
          onRetry: _onRetry,
        ),
      );
    }

    // Results
    if (_store.routes.isNotEmpty) {
      return _RouteResults(
        key: const ValueKey('results'),
        routes: _store.routes,
        selectedRoute: _store.selectedRoute,
        onTap: _onCardTap,
      );
    }

    // First use / idle
    return Padding(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.only(top: 60),
      child: EmptyState(
        type: EmptyStateType.firstUse,
        onRetry: null,
      ),
    );
  }

  EmptyStateType _errorType(String error) {
    final e = error.toLowerCase();
    if (e.contains('internet') || e.contains('network') || e.contains('socket')) {
      return EmptyStateType.noInternet;
    }
    if (e.contains('location') || e.contains('gps') || e.contains('permission')) {
      return EmptyStateType.gpsDisabled;
    }
    return EmptyStateType.error;
  }

  void _showSavedSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedRoutesSheet(store: _store),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RoutesHeader
// ─────────────────────────────────────────────────────────────────────────────

class _RoutesHeader extends StatelessWidget {
  const _RoutesHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.alt_route_rounded, color: scheme.primary, size: 26),
        const SizedBox(width: 12),
        Text(
          'Routes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RouteResults
// ─────────────────────────────────────────────────────────────────────────────

class _RouteResults extends StatefulWidget {
  const _RouteResults({
    super.key,
    required this.routes,
    required this.selectedRoute,
    required this.onTap,
  });

  final List<RouteOption> routes;
  final RouteOption? selectedRoute;
  final void Function(RouteOption) onTap;

  @override
  State<_RouteResults> createState() => _RouteResultsState();
}

class _RouteResultsState extends State<_RouteResults>
    with SingleTickerProviderStateMixin {
  late AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 540),
    )..forward();
  }

  @override
  void didUpdateWidget(_RouteResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameRouteList(widget.routes, oldWidget.routes)) {
      _entrance.forward(from: 0);
    }
  }

  static bool _sameRouteList(List<RouteOption> a, List<RouteOption> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].type != b[i].type) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Widget _staggerCard(int index, RouteOption route) {
    final delay = (index * 0.12).clamp(0.0, 0.5);
    final end = (delay + 0.45).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(delay, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(anim),
        child: RouteCard(
          key: ValueKey(route.type),
          route: route,
          isSelected: widget.selectedRoute?.type == route.type,
          onTap: () => widget.onTap(route),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final routes = widget.routes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Row(
            children: [
              Text(
                '${routes.length} options',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  'Tap card',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < routes.length; i++) _staggerCard(i, routes[i]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SavedRoutesSheet
// ─────────────────────────────────────────────────────────────────────────────

class _SavedRoutesSheet extends StatelessWidget {
  const _SavedRoutesSheet({required this.store});

  final RoutesStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final saved = store.savedRoutes;
    final recent = store.recentRoutes
        .where((r) => !r.isFavorite)
        .take(5)
        .toList();

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Saved & Recent Routes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (saved.isEmpty && recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No saved routes.\nBookmark one from results.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            if (saved.isNotEmpty) ...[
              _SavedSectionHeader(
                icon: Icons.bookmark_rounded,
                label: 'Favourites',
                color: scheme.secondary,
              ),
              const SizedBox(height: 8),
              for (final r in saved)
                _SavedRouteListTile(
                  route: r,
                  onLoad: () {
                    store.loadSavedRoute(r);
                    Navigator.of(context).pop();
                  },
                  onDelete: () => store.deleteSaved(r.id!),
                  scheme: scheme,
                ),
            ],
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SavedSectionHeader(
                icon: Icons.history_rounded,
                label: 'Recent',
                color: scheme.primary,
              ),
              const SizedBox(height: 8),
              for (final r in recent)
                _SavedRouteListTile(
                  route: r,
                  onLoad: () {
                    store.loadSavedRoute(r);
                    Navigator.of(context).pop();
                  },
                  onDelete: () => store.deleteSaved(r.id!),
                  scheme: scheme,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedSectionHeader extends StatelessWidget {
  const _SavedSectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _SavedRouteListTile extends StatelessWidget {
  const _SavedRouteListTile({
    required this.route,
    required this.onLoad,
    required this.onDelete,
    required this.scheme,
  });

  final SavedRoute route;
  final VoidCallback onLoad;
  final VoidCallback onDelete;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(route.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.route_rounded,
              size: 20, color: scheme.onPrimaryContainer),
        ),
        title: Text(
          route.routeSummary,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          route.lastEtaMinutes != null
              ? 'ETA ~${route.lastEtaMinutes} min · ${route.lastDistanceKm?.toStringAsFixed(1) ?? '?'} km'
              : _formatDate(route.savedAt),
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: scheme.onSurfaceVariant),
          onPressed: () {
            HapticFeedback.lightImpact();
            onLoad();
          },
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          onLoad();
        },
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}
