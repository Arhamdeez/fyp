/// Origin/destination search bar with GPS, swap, and "Get Routes" CTA.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../stores/routes_store.dart';
import 'place_search_screen.dart';
import '../../api/momentum_api.dart';

class RouteSearchBar extends StatefulWidget {
  const RouteSearchBar({super.key, required this.api});

  final MomentumApi api;

  @override
  State<RouteSearchBar> createState() => _RouteSearchBarState();
}

class _RouteSearchBarState extends State<RouteSearchBar>
    with SingleTickerProviderStateMixin {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _originFocus = FocusNode();
  final _destFocus = FocusNode();

  late final AnimationController _swapCtrl;
  late final Animation<double> _swapAnim;
  bool _swapped = false;

  final RoutesStore _store = RoutesStore.instance;

  @override
  void initState() {
    super.initState();
    _swapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _swapAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _swapCtrl, curve: Curves.easeInOutBack),
    );
    // Sync text from store (e.g. loaded saved route)
    _syncFromStore();
    _store.addListener(_syncFromStore);
  }

  void _syncFromStore() {
    if (!mounted) return;
    if (_originCtrl.text != _store.originName) {
      _originCtrl.text = _store.originName;
    }
    if (_destCtrl.text != _store.destName) {
      _destCtrl.text = _store.destName;
    }
  }

  @override
  void dispose() {
    _store.removeListener(_syncFromStore);
    _originCtrl.dispose();
    _destCtrl.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    _swapCtrl.dispose();
    super.dispose();
  }

  void _swap() async {
    HapticFeedback.lightImpact();
    _swapped = !_swapped;
    if (_swapped) {
      await _swapCtrl.forward();
    } else {
      await _swapCtrl.reverse();
    }
    _store.swapOriginDest();
  }

  void _useGps() {
    HapticFeedback.lightImpact();
    _store.useCurrentLocationAsOrigin();
  }

  Future<void> _search() async {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    await _store.search(widget.api);
  }

  Future<void> _openSearch({required bool isOrigin}) async {
    final result = await PlaceSearchScreen.show(
      context,
      title: isOrigin ? 'Where from?' : 'Where to?',
      initialQuery: isOrigin ? _originCtrl.text : _destCtrl.text,
      isOrigin: isOrigin,
    );

    if (result != null) {
      if (result.placeId == 'CURRENT_LOCATION') {
        _useGps();
        return;
      }

      if (isOrigin) {
        _store.setOrigin(
          name: result.shortName,
          lat: result.lat,
          lng: result.lng,
        );
      } else {
        _store.setDest(
          name: result.shortName,
          lat: result.lat,
          lng: result.lng,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final isLoading = _store.isLoading;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Origin field ─────────────────────────────────────────
                _SearchField(
                  controller: _originCtrl,
                  focusNode: _originFocus,
                  hint: 'Origin',
                  icon: Icons.trip_origin_rounded,
                  iconColor: scheme.primary,
                  onClear: () {
                    _originCtrl.clear();
                    _store.clearOrigin();
                  },
                  onTap: () => _openSearch(isOrigin: true),
                  trailing: Tooltip(
                    message: 'Use my location',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: isLoading ? null : _useGps,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.my_location_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Divider + swap ───────────────────────────────────────
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Container(
                        width: 2,
                        height: 20,
                        color: scheme.outlineVariant,
                      ),
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _swapAnim,
                      builder: (_, child) => Transform.rotate(
                        angle: _swapAnim.value * 3.14159,
                        child: IconButton(
                          icon: const Icon(Icons.swap_vert_rounded),
                          color: scheme.primary,
                          tooltip: 'Swap origin & destination',
                          onPressed: isLoading ? null : _swap,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Destination field ────────────────────────────────────
                _SearchField(
                  controller: _destCtrl,
                  focusNode: _destFocus,
                  hint: 'Destination',
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFFDC2626),
                  onClear: () {
                    _destCtrl.clear();
                    _store.clearDest();
                  },
                  onTap: () => _openSearch(isOrigin: false),
                ),

                const SizedBox(height: 14),

                // ── Get Routes button ────────────────────────────────────
                _GetRoutesButton(
                  onPressed: isLoading ? null : _search,
                  isLoading: isLoading,
                ),

                // ── Error snackbar inline ────────────────────────────────
                if (_store.error != null) ...[
                  const SizedBox(height: 10),
                  _ErrorBanner(
                    message: _store.error!,
                    onDismiss: _store.clearError,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchField
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onClear,
    required this.onTap,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onClear;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            readOnly: true,
            onTap: onTap,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, val, child) => val.text.isEmpty
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: onClear,
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GetRoutesButton
// ─────────────────────────────────────────────────────────────────────────────

class _GetRoutesButton extends StatefulWidget {
  const _GetRoutesButton({required this.onPressed, required this.isLoading});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<_GetRoutesButton> createState() => _GetRoutesButtonState();
}

class _GetRoutesButtonState extends State<_GetRoutesButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => _ctrl.forward() : null,
      onTapUp: enabled ? (_) => _ctrl.reverse() : null,
      onTapCancel: enabled ? () => _ctrl.reverse() : null,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: enabled ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      key: const ValueKey('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.alt_route_rounded,
                          size: 20,
                          color: enabled ? Colors.white : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Get Routes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: enabled ? Colors.white : scheme.onSurfaceVariant,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorBanner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded,
                size: 18, color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
