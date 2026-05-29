import 'package:geolocator/geolocator.dart';

import '../../domain/models/location_record.dart';

class LocationCaptureException implements Exception {
  const LocationCaptureException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationCaptureService {
  const LocationCaptureService();

  Future<void> ensureReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationCaptureException(
        'Ative a localizacao do aparelho para capturar o GPS.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationCaptureException('Permissao de localizacao negada.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationCaptureException(
        'Permissao de localizacao bloqueada. Libere nas configuracoes do aparelho.',
      );
    }
  }

  Stream<LocationRecord> watchLocation() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).map((position) => _recordFromPosition(position));
  }

  Stream<LocationRecord> watchOperationalLocation() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).map((position) => _recordFromPosition(position));
  }

  Future<LocationRecord> captureCurrentLocation() async {
    await ensureReady();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );

    return _recordFromPosition(position);
  }

  LocationRecord _recordFromPosition(Position position) {
    return LocationRecord(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      altitudeMeters: position.altitude,
      capturedAt: DateTime.now(),
      source: 'gps',
    );
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
