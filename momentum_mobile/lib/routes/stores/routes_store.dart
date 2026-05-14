// ChangeNotifier store — single source of truth for the Routes tab.
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/momentum_api.dart';
import '../../live/location_store.dart';
import '../db/route_db.dart';
import '../models/route_model.dart';
import '../models/saved_route.dart';
import '../services/maps_launcher.dart';
import '../services/places_service.dart';
import '../services/route_service.dart';

class RoutesStore extends ChangeNotifier {
  RoutesStore._();
  static final RoutesStore instance = RoutesStore._();

  // ── State ────────────────────────────────────────────────────────────────

  String originName = '';
  String destName = '';
  double? originLat;
  double? originLng;
  double? destLat;
  double? destLng;

  List<RouteOption> routes = const [];
  RouteOption? selectedRoute;
  LoadingPhase phase = LoadingPhase.idle;
  String? error;

  List<SavedRoute> savedRoutes = const [];
  List<SavedRoute> recentRoutes = const [];

  bool get hasOrigin => originLat != null && originLng != null && originName.isNotEmpty;
  bool get hasDest => destLat != null && destLng != null && destName.isNotEmpty;
  bool get canSearch => hasOrigin && hasDest;
  bool get isLoading => phase.isLoading;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      savedRoutes = await RouteDb.instance.listFavorites();
      recentRoutes = await RouteDb.instance.listRecent();
      notifyListeners();
    } catch (_) {}
  }

  // ── Location ─────────────────────────────────────────────────────────────

  Future<void> useCurrentLocationAsOrigin() async {
    phase = LoadingPhase.locating;
    error = null;
    notifyListeners();

    try {
      await LocationStore.instance.refresh();
      final pos = LocationStore.instance.position;
      if (pos == null) throw StateError(LocationStore.instance.error ?? 'Location unavailable');

      originLat = pos.latitude;
      originLng = pos.longitude;
      final name = await PlacesService.instance.reverseGeocode(pos.latitude, pos.longitude);
      originName = name.isEmpty ? 'Your Location' : name;
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
    } finally {
      phase = LoadingPhase.idle;
      notifyListeners();
    }
  }

  void setOrigin({required String name, required double lat, required double lng}) {
    originName = name;
    originLat = lat;
    originLng = lng;
    error = null;
    notifyListeners();
  }

  void setDest({required String name, required double lat, required double lng}) {
    destName = name;
    destLat = lat;
    destLng = lng;
    error = null;
    notifyListeners();
  }

  void swapOriginDest() {
    final tmpName = originName;
    final tmpLat = originLat;
    final tmpLng = originLng;
    originName = destName;
    originLat = destLat;
    originLng = destLng;
    destName = tmpName;
    destLat = tmpLat;
    destLng = tmpLng;
    routes = const [];
    selectedRoute = null;
    notifyListeners();
  }

  void clearOrigin() {
    originName = '';
    originLat = null;
    originLng = null;
    routes = const [];
    selectedRoute = null;
    notifyListeners();
  }

  void clearDest() {
    destName = '';
    destLat = null;
    destLng = null;
    routes = const [];
    selectedRoute = null;
    notifyListeners();
  }

  // ── Search ───────────────────────────────────────────────────────────────

  Future<void> search(MomentumApi api) async {
    if (!canSearch) {
      error = 'Please enter both origin and destination.';
      notifyListeners();
      return;
    }

    error = null;
    routes = const [];
    selectedRoute = null;

    // Phase 1: fetching insights
    phase = LoadingPhase.fetchingInsights;
    notifyListeners();

    try {
      // Slight delay to show message before network call
      await Future.delayed(const Duration(milliseconds: 600));

      phase = LoadingPhase.fetchingWeather;
      notifyListeners();

      final fetched = await RouteService.instance.fetchRoutes(
        api: api,
        originLat: originLat!,
        originLng: originLng!,
        destLat: destLat!,
        destLng: destLng!,
        originName: originName,
        destName: destName,
      );

      phase = LoadingPhase.analyzing;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 700));

      routes = fetched;
      selectedRoute = fetched.isNotEmpty ? fetched.last : null; // recommended
      phase = LoadingPhase.done;

      // Auto-save to recent
      if (fetched.isNotEmpty) {
        _saveRecent(fetched.first);
      }
    } catch (e) {
      error = _humanizeError(e);
      phase = LoadingPhase.idle;
    }

    notifyListeners();
  }

  // ── Selection ────────────────────────────────────────────────────────────

  void selectRoute(RouteOption route) {
    selectedRoute = route;
    notifyListeners();
  }

  // ── Favorites ────────────────────────────────────────────────────────────

  Future<void> toggleFavorite(SavedRoute route) async {
    route.isFavorite = !route.isFavorite;
    if (route.id != null) {
      await RouteDb.instance.toggleFavorite(route.id!, isFavorite: route.isFavorite);
    }
    savedRoutes = await RouteDb.instance.listFavorites();
    recentRoutes = await RouteDb.instance.listRecent();
    notifyListeners();
  }

  Future<SavedRoute?> saveCurrentRoute(RouteOption route) async {
    if (!canSearch) return null;
    final saved = SavedRoute(
      label: '${originName.split(',').first} → ${destName.split(',').first}',
      originName: originName,
      destName: destName,
      originLat: originLat!,
      originLng: originLng!,
      destLat: destLat!,
      destLng: destLng!,
      savedAt: DateTime.now(),
      isFavorite: true,
      lastEtaMinutes: route.etaMinutes,
      lastDistanceKm: route.distanceKm,
    );
    final id = await RouteDb.instance.insert(saved);
    savedRoutes = await RouteDb.instance.listFavorites();
    recentRoutes = await RouteDb.instance.listRecent();
    notifyListeners();
    return SavedRoute(
      id: id,
      label: saved.label,
      originName: saved.originName,
      destName: saved.destName,
      originLat: saved.originLat,
      originLng: saved.originLng,
      destLat: saved.destLat,
      destLng: saved.destLng,
      savedAt: saved.savedAt,
      isFavorite: true,
    );
  }

  Future<void> _saveRecent(RouteOption r) async {
    try {
      await RouteDb.instance.insert(
        SavedRoute(
          label: '${originName.split(',').first} → ${destName.split(',').first}',
          originName: originName,
          destName: destName,
          originLat: originLat!,
          originLng: originLng!,
          destLat: destLat!,
          destLng: destLng!,
          savedAt: DateTime.now(),
          isFavorite: false,
          lastEtaMinutes: r.etaMinutes,
          lastDistanceKm: r.distanceKm,
        ),
      );
      recentRoutes = await RouteDb.instance.listRecent();
      notifyListeners();
    } catch (_) {}
  }

  // ── Share ────────────────────────────────────────────────────────────────

  Future<void> shareRoute(BuildContext context, RouteOption route) async {
    final uri = MapsLauncher.directionsUri(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      originLabel: route.originName,
      destLabel: route.destName,
      mapsVariant: route.type,
    );

    final weatherLine = route.weather.isAvailable
        ? '${route.weather.condition} · ${route.weather.tempC.round()}°C'
        : 'Unavailable';

    final text = [
      '${route.originName} → ${route.destName}',
      '${route.title} · ETA ${route.etaLabel} · ${route.distanceLabel}',
      'Traffic: ${route.traffic.levelLabel}',
      'Weather: $weatherLine',
      '',
      'Open in Maps:',
      uri.toString(),
      '',
      'Shared from Momentum',
    ].join('\n');

    final box = context.findRenderObject();
    Rect? shareOrigin;
    if (box is RenderBox && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      shareOrigin = offset & box.size;
    }

    try {
      final subject =
          'Route: ${route.originName.split(',').first} → ${route.destName.split(',').first}';
      if (shareOrigin != null &&
          shareOrigin.width > 0 &&
          shareOrigin.height > 0) {
        await Share.share(
          text,
          subject: subject,
          sharePositionOrigin: shareOrigin,
        );
      } else {
        await Share.share(text, subject: subject);
      }
    } catch (e, st) {
      debugPrint('shareRoute failed: $e\n$st');
      rethrow;
    }
  }

  // ── Load saved route into search ─────────────────────────────────────────

  void loadSavedRoute(SavedRoute r) {
    setOrigin(name: r.originName, lat: r.originLat, lng: r.originLng);
    setDest(name: r.destName, lat: r.destLat, lng: r.destLng);
    routes = const [];
    selectedRoute = null;
    error = null;
    notifyListeners();
  }

  // ── Delete saved route ───────────────────────────────────────────────────

  Future<void> deleteSaved(int id) async {
    await RouteDb.instance.delete(id);
    savedRoutes = await RouteDb.instance.listFavorites();
    recentRoutes = await RouteDb.instance.listRecent();
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void clearError() {
    error = null;
    notifyListeners();
  }

  void reset() {
    routes = const [];
    selectedRoute = null;
    phase = LoadingPhase.idle;
    error = null;
    notifyListeners();
  }

  static String _humanizeError(Object e) {
    if (e is TimeoutException) {
      return 'The request took too long. Please try again on a faster network.';
    }
    if (e is SocketException) {
      return 'No internet connection. Please connect to Wi-Fi or cellular data.';
    }
    if (e is FormatException) {
      return 'Received invalid response from the server. Please try again later.';
    }

    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return 'No internet connection. Please connect to Wi-Fi or cellular data.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'The request took too long. Please try again on a faster network.';
    }
    if (msg.contains('Rate limit') || msg.contains('429')) {
      return 'You have made too many requests. Please wait a moment and try again.';
    }
    if (msg.contains('404')) return 'The requested route could not be found (404).';
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return 'The routing server is currently unavailable. Please try again shortly.';
    }
    
    // Clean up generic exceptions
    final cleanMsg = msg.replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
    return cleanMsg.length > 120 ? '${cleanMsg.substring(0, 120)}…' : cleanMsg;
  }
}
