class SeedPeriodValue {
  final double canola;
  final double corn;
  final double total;

  const SeedPeriodValue({
    required this.canola,
    required this.corn,
    required this.total,
  });
}

class SeedPeriod {
  final String id;
  final String label;
  final String kind; // month | range | other
  final int sortKey;

  const SeedPeriod({
    required this.id,
    required this.label,
    required this.kind,
    required this.sortKey,
  });
}

class SeedShop {
  final String code;
  final String name;
  final String area;
  final double? avg2023;
  final bool? isFiler;
  final Map<SeedPeriod, SeedPeriodValue> sales;

  const SeedShop({
    required this.code,
    required this.name,
    required this.area,
    required this.avg2023,
    required this.isFiler,
    required this.sales,
  });
}

class SeedTsaSheet {
  final String sheetName;
  final String tsaName;
  final List<SeedShop> shops;

  const SeedTsaSheet({
    required this.sheetName,
    required this.tsaName,
    required this.shops,
  });
}

