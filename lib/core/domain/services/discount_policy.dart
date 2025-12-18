enum ShopTaxStatus { filer, nonFiler }

class DiscountResult {
  final double discountRate;
  final double discountAmount;
  final double netAmount;

  const DiscountResult({
    required this.discountRate,
    required this.discountAmount,
    required this.netAmount,
  });
}

class DiscountPolicy {
  static const filerDiscount = 0.05;
  static const nonFilerDiscount = 0.025;

  DiscountResult apply({
    required ShopTaxStatus taxStatus,
    required double grossAmount,
  }) {
    final rate = taxStatus == ShopTaxStatus.filer
        ? filerDiscount
        : nonFilerDiscount;
    final discountAmount = grossAmount * rate;
    final net = grossAmount - discountAmount;
    return DiscountResult(
      discountRate: rate,
      discountAmount: discountAmount,
      netAmount: net,
    );
  }
}
