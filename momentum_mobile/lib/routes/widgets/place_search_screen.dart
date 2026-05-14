/// Full-screen place search experience resembling modern map apps.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/place_suggestion.dart';
import '../services/places_service.dart';
import '../stores/routes_store.dart';

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({
    super.key,
    required this.title,
    required this.initialQuery,
    required this.isOrigin,
  });

  final String title;
  final String initialQuery;
  final bool isOrigin;

  static Future<PlaceSuggestion?> show(
    BuildContext context, {
    required String title,
    String initialQuery = '',
    bool isOrigin = false,
  }) {
    return Navigator.of(context).push<PlaceSuggestion>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PlaceSearchScreen(
          title: title,
          initialQuery: initialQuery,
          isOrigin: isOrigin,
        ),
        transitionsBuilder: (context, anim, secondaryAnim, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: anim.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  late final TextEditingController _ctrl;
  final _focusNode = FocusNode();

  String _query = '';
  bool _isLoading = false;
  List<PlaceSuggestion> _results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery;
    _ctrl.addListener(_onTextChanged);

    // Auto-focus after transition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    if (_query.isNotEmpty) {
      _performSearch(_query);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _ctrl.text;
    if (text == _query) return;
    setState(() => _query = text);

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (text.trim().length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    _isLoading = true;
    setState(() {});

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(text);
    });
  }

  Future<void> _performSearch(String q) async {
    final results = await PlacesService.instance.search(q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    // Return a special marker that tells the caller to use GPS
    Navigator.of(context).pop(
      const PlaceSuggestion(
        placeId: 'CURRENT_LOCATION',
        displayName: 'Your Location',
        shortName: 'Your Location',
        address: '',
        lat: 0,
        lng: 0,
        category: 'gps',
      ),
    );
  }

  void _clear() {
    _ctrl.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header / Search Bar ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? scheme.primary.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            widget.isOrigin
                                ? Icons.trip_origin_rounded
                                : Icons.location_on_rounded,
                            size: 20,
                            color: widget.isOrigin
                                ? scheme.primary
                                : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focusNode,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: widget.title,
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (v) {
                                if (v.trim().isNotEmpty) _performSearch(v);
                              },
                            ),
                          ),
                          if (_query.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close_rounded,
                                  size: 20, color: scheme.onSurfaceVariant),
                              onPressed: _clear,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              LinearProgressIndicator(minHeight: 2, color: scheme.primary),

            // ── Body ───────────────────────────────────────────────────
            Expanded(
              child: _query.trim().length < 2
                  ? _buildEmptyState(scheme)
                  : _buildResults(scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      children: [
        if (widget.isOrigin) ...[
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.my_location_rounded,
                  color: scheme.primary, size: 20),
            ),
            title: Text(
              'Your location',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: _useCurrentLocation,
          ),
          const Divider(height: 1),
        ],

        // Show recent searches from DB
        ListenableBuilder(
          listenable: RoutesStore.instance,
          builder: (context, _) {
            final recents = RoutesStore.instance.recentRoutes;
            if (recents.isEmpty) return const SizedBox.shrink();

            // Distinct destinations/origins for suggestions
            final seenNames = <String>{};
            final items = <Widget>[];

            for (final r in recents) {
              final n = widget.isOrigin ? r.originName : r.destName;
              if (seenNames.contains(n) || n.contains(',')) continue; // skip raw latlngs
              seenNames.add(n);

              items.add(ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history_rounded,
                      color: scheme.onSurfaceVariant, size: 20),
                ),
                title: Text(n),
                subtitle: widget.isOrigin ? null : Text(r.routeSummary),
                onTap: () {
                  Navigator.of(context).pop(
                    PlaceSuggestion(
                      placeId: '',
                      displayName: n,
                      shortName: n,
                      address: '',
                      lat: widget.isOrigin ? r.originLat : r.destLat,
                      lng: widget.isOrigin ? r.originLng : r.destLng,
                      category: 'history',
                    ),
                  );
                },
              ));

              if (items.length >= 5) break;
            }

            if (items.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Recent Places',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...items,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildResults(ColorScheme scheme) {
    if (!_isLoading && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No places found for "$_query"',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
      itemBuilder: (context, index) {
        final place = _results[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(place.icon, color: scheme.onSurfaceVariant, size: 20),
          ),
          title: Text(
            place.shortName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: place.address.isNotEmpty
              ? Text(
                  place.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () => Navigator.of(context).pop(place),
        );
      },
    );
  }
}
