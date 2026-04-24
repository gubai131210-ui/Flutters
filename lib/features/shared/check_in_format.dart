import 'package:geocoding/geocoding.dart';

/// Human-readable check-in line: city text (if any) + coordinates from metadata.
String formatCheckInDisplayLine(Map<String, dynamic> metadata) {
  final String place = (metadata['checkInPlaceText'] as String?)?.trim() ?? '';
  final double? lat = _readDouble(metadata['checkInLat']);
  final double? lng = _readDouble(metadata['checkInLng']);
  final String coord = lat != null && lng != null
      ? '${lat.toStringAsFixed(5)}°, ${lng.toStringAsFixed(5)}°'
      : '';

  if (place.isNotEmpty && coord.isNotEmpty) {
    return '打卡：$place · $coord';
  }
  if (coord.isNotEmpty) {
    return '打卡：$coord';
  }
  if (place.isNotEmpty) {
    return '打卡：$place';
  }
  return '打卡';
}

/// City-level description from a geocoding [Placemark] (deduped, ordered).
String placeTextFromPlacemark(Placemark p) {
  final parts = <String>[];
  void add(String? s) {
    if (s == null) {
      return;
    }
    final t = s.trim();
    if (t.isEmpty || parts.contains(t)) {
      return;
    }
    parts.add(t);
  }

  add(p.locality);
  add(p.subAdministrativeArea);
  add(p.administrativeArea);
  add(p.country);
  return parts.join(' ');
}

double? _readDouble(Object? raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  if (raw is String) {
    return double.tryParse(raw);
  }
  return null;
}
