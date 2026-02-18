import 'package:http/http.dart' as http;

class ParsedMapLocation {
  final double lat;
  final double lng;

  const ParsedMapLocation({required this.lat, required this.lng});
}

class MapLocationUrlParser {
  static const _shortMapHosts = <String>{
    'maps.app.goo.gl',
    'goo.gl',
    'maps.google.com',
    'maps.google.co.in',
  };

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

    final pathBased = _fromPath(uri);
    if (pathBased != null) return pathBased;

    return _fromFragment(uri);
  }

  static Future<ParsedMapLocation?> tryParseSmart(String rawInput) async {
    final direct = tryParse(rawInput);
    if (direct != null) return direct;

    final raw = rawInput.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    final expanded = await _expandPotentialShortMapUrl(uri);
    if (expanded == null) return null;
    return tryParse(expanded);
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
      'daddr',
      'saddr',
      'near',
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

    final bangMatch = RegExp(
      r'!3d(-?\d{1,2}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(decodedPath);
    if (bangMatch != null) {
      return _build(latRaw: bangMatch.group(1), lngRaw: bangMatch.group(2));
    }

    final generic = _fromCoordinateText(decodedPath);
    if (generic != null) return generic;

    return null;
  }

  static ParsedMapLocation? _fromFragment(Uri uri) {
    final fragment = Uri.decodeFull(uri.fragment);
    if (fragment.isEmpty) return null;

    final mapMatch = RegExp(
      r'map=\d+(?:\.\d+)?/(-?\d{1,2}(?:\.\d+)?)/(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(fragment);
    if (mapMatch != null) {
      return _build(latRaw: mapMatch.group(1), lngRaw: mapMatch.group(2));
    }
    return _fromCoordinateText(fragment);
  }

  static ParsedMapLocation? _fromCoordinateText(String text) {
    final cleaned = text
        .trim()
        .replaceFirst(RegExp(r'^loc:'), '')
        .replaceAll('+', ' ')
        .replaceAll(RegExp(r'[()]'), ' ');

    final labeled = RegExp(
      r'lat(?:itude)?\s*[:=]\s*(-?\d{1,2}(?:\.\d+)?).{0,30}?(?:lng|lon|longitude)\s*[:=]\s*(-?\d{1,3}(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (labeled != null) {
      return _build(latRaw: labeled.group(1), lngRaw: labeled.group(2));
    }

    final match = RegExp(
      r'(-?\d{1,2}(?:\.\d+)?)\s*(?:,|\s+)\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(cleaned);
    if (match == null) return null;

    return _build(latRaw: match.group(1), lngRaw: match.group(2));
  }

  static Future<String?> _expandPotentialShortMapUrl(Uri uri) async {
    final host = uri.host.toLowerCase();
    final isShortHost =
        _shortMapHosts.contains(host) || host.endsWith('.app.goo.gl');
    if (!isShortHost) return null;
    try {
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'field_sales_app/1.0 (map parser)'},
      );
      final resolved = response.request?.url.toString();
      if (resolved == null || resolved.trim().isEmpty) return null;
      return resolved;
    } catch (_) {
      return null;
    }
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
