String slugifyId(String input) {
  final lower = input.trim().toLowerCase();
  final slug = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final collapsed = slug.replaceAll(RegExp(r'_+'), '_').replaceAll(
    RegExp(r'^_+|_+$'),
    '',
  );
  return collapsed.isEmpty ? 'unknown' : collapsed;
}

int monthNumberFromName(String name) {
  final n = name.trim().toLowerCase();
  switch (n) {
    case 'jan':
    case 'january':
      return 1;
    case 'feb':
    case 'fab':
    case 'february':
      return 2;
    case 'mar':
    case 'march':
      return 3;
    case 'apr':
    case 'april':
      return 4;
    case 'may':
      return 5;
    case 'jun':
    case 'june':
      return 6;
    case 'jul':
    case 'july':
      return 7;
    case 'aug':
    case 'august':
      return 8;
    case 'sep':
    case 'sept':
    case 'september':
      return 9;
    case 'oct':
    case 'october':
      return 10;
    case 'nov':
    case 'november':
      return 11;
    case 'dec':
    case 'december':
      return 12;
    default:
      throw StateError('Unknown month name: $name');
  }
}

