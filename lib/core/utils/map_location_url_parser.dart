class ParsedMapLocation {
  final double lat;
  final double lng;

  const ParsedMapLocation({required this.lat, required this.lng});
}

class MapLocationUrlParser {
  static ParsedMapLocation? tryParse(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty) return null;

    final direct = _fromCoordinateText(input);
    if (direct != null) return direct;

    final uri = Uri.tryParse(input);
    if (uri == null) return null;

    final geo = _fromGeoUri(uri);
    if (geo != null) return geo;

    final queryBased = _fromQueryParams(uri);
    if (queryBased != null) return queryBased;

    return _fromPath(uri);
  }

  static ParsedMapLocation? _fromGeoUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'geo') return null;
    return _fromCoordinateText(uri.path);
  }

  static ParsedMapLocation? _fromQueryParams(Uri uri) {
    const coordinateKeys = [
      'q',
      'query',
      'll',
      'sll',
      'center',
      'destination',
      'origin',
    ];
    for (final key in coordinateKeys) {
      final value = uri.queryParameters[key];
      if (value == null || value.trim().isEmpty) continue;
      final parsed = _fromCoordinateText(Uri.decodeComponent(value));
      if (parsed != null) return parsed;
    }
    return null;
  }

  static ParsedMapLocation? _fromPath(Uri uri) {
    final decodedPath = Uri.decodeFull(uri.path);

    final atMatch = RegExp(
      r'@(-?\d{1,2}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(decodedPath);
    if (atMatch != null) {
      return _build(latRaw: atMatch.group(1), lngRaw: atMatch.group(2));
    }

    final generic = _fromCoordinateText(decodedPath);
    if (generic != null) return generic;

    return null;
  }

  static ParsedMapLocation? _fromCoordinateText(String text) {
    final cleaned = text.trim().replaceFirst(RegExp(r'^loc:'), '');
    final match = RegExp(
      r'(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(cleaned);
    if (match == null) return null;

    return _build(latRaw: match.group(1), lngRaw: match.group(2));
  }

  static ParsedMapLocation? _build({
    required String? latRaw,
    required String? lngRaw,
  }) {
    final lat = double.tryParse(latRaw ?? '');
    final lng = double.tryParse(lngRaw ?? '');
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
    return ParsedMapLocation(lat: lat, lng: lng);
  }
}
