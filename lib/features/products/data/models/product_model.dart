import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String sku;
  final String name;
  final String? category;
  final String? brand;
  final String? unit;
  final double? price;
  final double? stock;

  const ProductModel({
    required this.sku,
    required this.name,
    this.category,
    this.brand,
    this.unit,
    this.price,
    this.stock,
  });

  factory ProductModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Product not found for id=${doc.id}');
    }
    return ProductModel.fromMap(data, fallbackId: doc.id);
  }

  factory ProductModel.fromMap(
    Map<String, dynamic> data, {
    required String fallbackId,
  }) {
    final sku = _stringOrNull(data['sku']) ?? fallbackId;
    final name = _stringOrNull(data['name']) ?? sku;
    return ProductModel(
      sku: sku,
      name: name,
      category: _stringOrNull(data['category']),
      brand: _stringOrNull(data['brand']),
      unit: _stringOrNull(data['unit']),
      price: _doubleOrNull(data['price']),
      stock: _doubleOrNull(data['stock']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sku': sku,
      'name': name,
      if (category != null) 'category': category,
      if (brand != null) 'brand': brand,
      if (unit != null) 'unit': unit,
      if (price != null) 'price': price,
      if (stock != null) 'stock': stock,
    };
  }

  static String? _stringOrNull(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _doubleOrNull(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }
}
