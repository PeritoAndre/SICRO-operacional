import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/location_record.dart';
import '../../domain/models/occurrence.dart';
import '../data/occurrence_repository.dart';
import 'location_capture_service.dart';

class OperationalSessionTracker extends ChangeNotifier {
  OperationalSessionTracker({
    required this.repository,
    LocationCaptureService? locationService,
    this.sampleInterval = const Duration(seconds: 30),
  }) : locationService = locationService ?? const LocationCaptureService();

  final OccurrenceRepository repository;
  final LocationCaptureService locationService;
  final Duration sampleInterval;

  StreamSubscription<LocationRecord>? _subscription;
  String? _activeOccurrenceId;
  DateTime? _lastSavedAt;
  LocationRecord? _bestReading;
  bool _started = false;
  bool _tracking = false;
  bool _starting = false;
  String? _lastError;

  bool get tracking => _tracking;
  bool get starting => _starting;
  String? get activeOccurrenceId => _activeOccurrenceId;
  String? get lastError => _lastError;
  LocationRecord? get bestReading => _bestReading;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    repository.addListener(_syncWithRepository);
    _syncWithRepository();
  }

  @override
  void dispose() {
    repository.removeListener(_syncWithRepository);
    _subscription?.cancel();
    super.dispose();
  }

  void _syncWithRepository() {
    final active = _activeOccurrence();
    if (active == null) {
      _stopTracking();
      return;
    }

    if (_activeOccurrenceId == active.id && (_tracking || _starting)) {
      return;
    }

    _startTracking(active.id);
  }

  FieldOccurrence? _activeOccurrence() {
    for (final occurrence in repository.occurrences) {
      if (occurrence.sessionActive) {
        return occurrence;
      }
    }
    return null;
  }

  Future<void> _startTracking(String occurrenceId) async {
    await _subscription?.cancel();
    _activeOccurrenceId = occurrenceId;
    _lastSavedAt = null;
    _bestReading = repository.findById(occurrenceId)?.bestGpsLocation;
    _tracking = false;
    _starting = true;
    _lastError = null;
    notifyListeners();

    try {
      await locationService.ensureReady();
      if (_activeOccurrenceId != occurrenceId) {
        return;
      }
      _subscription = locationService.watchOperationalLocation().listen(
        _handleLocation,
        onError: (Object error) {
          _lastError = 'Falha no GPS operacional: $error';
          _tracking = false;
          _starting = false;
          notifyListeners();
        },
      );
      _tracking = true;
      _starting = false;
      notifyListeners();
    } catch (error) {
      if (_activeOccurrenceId != occurrenceId) {
        return;
      }
      _lastError = error.toString();
      _tracking = false;
      _starting = false;
      notifyListeners();
    }
  }

  void _handleLocation(LocationRecord reading) {
    final occurrenceId = _activeOccurrenceId;
    if (occurrenceId == null) {
      return;
    }

    final occurrence = repository.findById(occurrenceId);
    if (occurrence == null || !occurrence.sessionActive) {
      _stopTracking();
      return;
    }

    final isBest = _bestReading == null || _isBetter(reading, _bestReading!);
    if (isBest) {
      _bestReading = reading;
    }

    final now = DateTime.now();
    final shouldSample =
        _lastSavedAt == null || now.difference(_lastSavedAt!) >= sampleInterval;
    if (isBest || shouldSample) {
      _lastSavedAt = now;
      repository.addGpsReading(occurrenceId, reading);
    }
  }

  void _stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _activeOccurrenceId = null;
    _lastSavedAt = null;
    _bestReading = null;
    _tracking = false;
    _starting = false;
    notifyListeners();
  }

  bool _isBetter(LocationRecord candidate, LocationRecord currentBest) {
    final candidateAccuracy = candidate.accuracyMeters;
    final bestAccuracy = currentBest.accuracyMeters;
    if (candidateAccuracy == null) {
      return false;
    }
    if (bestAccuracy == null) {
      return true;
    }
    return candidateAccuracy < bestAccuracy;
  }
}
