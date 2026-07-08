import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService _syncService;
  bool _syncing = false;
  SyncResult? _lastResult;
  bool _isOnline = true;
  StreamSubscription? _connectivitySub;

  SyncProvider(this._syncService) {
    _monitorConnectivity();
  }

  bool get syncing => _syncing;
  SyncResult? get lastResult => _lastResult;
  bool get isOnline => _isOnline;

  void _monitorConnectivity() {
    _connectivitySub = _syncService.connectivityStream.listen((results) async {
      final wasOffline = !_isOnline;
      _isOnline = await _syncService.hasConnectivity;
      notifyListeners();

      // Auto-sync when coming back online
      if (wasOffline && _isOnline) {
        await syncNow();
      }
    });
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    notifyListeners();

    _lastResult = await _syncService.syncAll();

    _syncing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
