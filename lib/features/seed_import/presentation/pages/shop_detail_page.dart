import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/utils/file_save.dart';
import '../../../reports/domain/export/excel_exporter.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_toast.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../app/ui/theme_mode_toggle_button.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class ShopDetailPage extends StatelessWidget {
  const ShopDetailPage({super.key});

  String _resolveDashboardRoute() {
    final profile = Get.find<SessionService>().profile;
    if (profile == null) return AppRoutes.adminDashboard;
    switch (profile.role) {
      case UserRole.admin:
        return AppRoutes.adminDashboard;
      case UserRole.distributor:
        return AppRoutes.distributorDashboard;
      case UserRole.dsf:
        return AppRoutes.dsfHome;
    }
  }

  DateTime? _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final local = date.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  String _weekdayLabel(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _formatDayDate(DateTime date) {
    final local = date.toLocal();
    return '${_weekdayLabel(local)}, ${local.year}-${_two(local.month)}-${_two(local.day)}';
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  String _formatNumber(num value) {
    final v = value.toDouble();
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  String _normalizeUnit(dynamic raw) {
    final unit = raw?.toString().trim() ?? '';
    if (unit.isEmpty) return 'L';
    final lower = unit.toLowerCase();
    if (lower == 'l' ||
        lower == 'ltr' ||
        lower == 'liter' ||
        lower == 'litre') {
      return 'L';
    }
    return unit;
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(item.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }

  Widget _detailSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.skySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _kvLine(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$key: $value', style: const TextStyle(color: AppTheme.ink)),
    );
  }

  Future<void> _shareAndOpenMap(
    BuildContext context, {
    required String shopTitle,
    required double lat,
    required double lng,
  }) async {
    final trimmedShop = shopTitle.trim();
    final coords = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    final query = trimmedShop.isEmpty ? coords : '$trimmedShop, $coords';
    final primaryMapUri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    final fallbackMapUri = Uri.https('www.google.com', '/maps', {'q': coords});
    final shareText = trimmedShop.isEmpty
        ? 'Submitted location: $coords\n$primaryMapUri'
        : '$trimmedShop\nSubmitted location: $coords\n$primaryMapUri';

    try {
      await Clipboard.setData(ClipboardData(text: shareText));
    } catch (_) {
      // Clipboard can fail on some browsers; map opening should still continue.
    }

    var opened = await launchUrl(primaryMapUri, webOnlyWindowName: '_blank');
    if (!opened) {
      opened = await launchUrl(fallbackMapUri, webOnlyWindowName: '_blank');
    }
    if (!context.mounted) return;
    AppToast.info(
      opened ? 'Shared' : 'Copied',
      message: opened
          ? 'Location copied and map opened.'
          : 'Location copied. Could not open map.',
    );
  }

  Future<void> _openVisitDetails(
    BuildContext context, {
    required String visitId,
    required Map<String, dynamic> data,
    required String defaultShopTitle,
  }) async {
    final submittedAt = _toDate(data['submittedAt']);
    final visitStartedAt = _toDate(data['visitStartedAt']);
    final orders = _asMapList(data['orders']);
    final stockItems = _asMapList(data['stockItems']);
    final recovery = data['recovery'];
    final recoveryType =
        (recovery is Map ? recovery['type'] : null)?.toString() ?? '';
    final recoveryAmount = recovery is Map
        ? _toDouble(recovery['amount'])
        : null;
    final chequeImageUrl = recovery is Map
        ? (recovery['chequeImageUrl']?.toString() ?? '')
        : '';
    final notes = (data['notes'] as String?)?.trim() ?? '';
    final distanceMeters = _toDouble(data['distanceMeters']);
    final submittedLocation = data['submittedLocation'];
    final lat = submittedLocation is Map
        ? _toDouble(submittedLocation['lat'])
        : null;
    final lng = submittedLocation is Map
        ? _toDouble(submittedLocation['lng'])
        : null;
    final visitShopTitleRaw = (data['shopTitle'] as String?)?.trim() ?? '';
    final visitShopTitle = visitShopTitleRaw.isEmpty
        ? defaultShopTitle
        : visitShopTitleRaw;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: DraggableScrollableSheet(
              initialChildSize: 0.78,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Visit Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(
                        'Visit ID: $visitId',
                        style: const TextStyle(color: AppTheme.mutedInk),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            _detailSection(
                              context: context,
                              title: 'Summary',
                              children: [
                                _kvLine('Submitted', _formatDate(submittedAt)),
                                _kvLine(
                                  'Visit started',
                                  _formatDate(visitStartedAt),
                                ),
                                _kvLine('Orders', '${orders.length}'),
                                _kvLine('Stock items', '${stockItems.length}'),
                                _kvLine(
                                  'Recovery',
                                  recoveryAmount == null
                                      ? 'Not added'
                                      : '${recoveryType.toUpperCase()} ${recoveryAmount.toStringAsFixed(2)}',
                                ),
                                if (distanceMeters != null)
                                  _kvLine(
                                    'Distance',
                                    '${distanceMeters.toStringAsFixed(0)} m',
                                  ),
                              ],
                            ),
                            _detailSection(
                              context: context,
                              title: 'Orders',
                              children: orders.isEmpty
                                  ? const [Text('No orders recorded.')]
                                  : orders.map((item) {
                                      final name =
                                          (item['productName']?.toString() ??
                                                  item['productId']
                                                      ?.toString() ??
                                                  'Product')
                                              .trim();
                                      final qtyRaw = item['quantity'];
                                      final qty = qtyRaw is num
                                          ? _formatNumber(qtyRaw)
                                          : qtyRaw?.toString() ?? '-';
                                      final unit = _normalizeUnit(item['unit']);
                                      final lineAmount = _toDouble(
                                        item['lineAmount'],
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          '- $name: $qty $unit${lineAmount == null ? '' : ' (Rs ${lineAmount.toStringAsFixed(2)})'}',
                                        ),
                                      );
                                    }).toList(),
                            ),
                            _detailSection(
                              context: context,
                              title: 'Stock Items',
                              children: stockItems.isEmpty
                                  ? const [Text('No stock items recorded.')]
                                  : stockItems.map((item) {
                                      final name =
                                          (item['productName']?.toString() ??
                                                  item['productId']
                                                      ?.toString() ??
                                                  'Product')
                                              .trim();
                                      final qtyRaw = item['quantity'];
                                      final qty = qtyRaw is num
                                          ? _formatNumber(qtyRaw)
                                          : qtyRaw?.toString() ?? '-';
                                      final unit = _normalizeUnit(item['unit']);
                                      final lineAmount = _toDouble(
                                        item['lineAmount'],
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          '- $name: $qty $unit${lineAmount == null ? '' : ' (Rs ${lineAmount.toStringAsFixed(2)})'}',
                                        ),
                                      );
                                    }).toList(),
                            ),
                            _detailSection(
                              context: context,
                              title: 'Recovery & Notes',
                              children: [
                                _kvLine(
                                  'Type',
                                  recoveryType.isEmpty
                                      ? 'N/A'
                                      : recoveryType.toUpperCase(),
                                ),
                                _kvLine(
                                  'Amount',
                                  recoveryAmount == null
                                      ? 'N/A'
                                      : recoveryAmount.toStringAsFixed(2),
                                ),
                                if (chequeImageUrl.isNotEmpty)
                                  _kvLine('Cheque image', 'Attached'),
                                _kvLine(
                                  'Notes',
                                  notes.isEmpty ? 'No notes' : notes,
                                ),
                              ],
                            ),
                            _detailSection(
                              context: context,
                              title: 'Location',
                              children: [
                                _kvLine(
                                  'Shop',
                                  visitShopTitle.isEmpty
                                      ? 'N/A'
                                      : visitShopTitle,
                                ),
                                _kvLine(
                                  'Submitted location',
                                  (lat == null || lng == null)
                                      ? 'Not captured'
                                      : '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                                ),
                                if (lat != null && lng != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: FilledButton.icon(
                                      onPressed: () => _shareAndOpenMap(
                                        context,
                                        shopTitle: visitShopTitle,
                                        lat: lat,
                                        lng: lng,
                                      ),
                                      icon: const Icon(
                                        Icons.share_location_outlined,
                                      ),
                                      label: const Text(
                                        'Open to view shop location',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _safeToken(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_').trim();
    return cleaned.isEmpty ? 'shop' : cleaned;
  }

  Future<void> _exportSalesData(
    BuildContext context, {
    required String tsaId,
    required String shopId,
    required String shopTitle,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> salesDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> visitDocs,
  }) async {
    try {
      final now = DateTime.now();
      final fileName =
          'shop_${_safeToken(shopId)}_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}.xlsx';

      final salesRows = salesDocs.map((doc) {
        final data = doc.data();
        final label = (data['label'] as String?) ?? doc.id;
        return [
          doc.id,
          label,
          (data['canola'] as num?)?.toDouble() ?? 0,
          (data['corn'] as num?)?.toDouble() ?? 0,
          (data['total'] as num?)?.toDouble() ?? 0,
        ];
      }).toList();

      final visitRows = visitDocs.map((doc) {
        final data = doc.data();
        final submittedAt = _formatDate(_toDate(data['submittedAt']));
        final orderCount = (data['orders'] is List)
            ? (data['orders'] as List).length
            : 0;
        final stockCount = (data['stockItems'] is List)
            ? (data['stockItems'] as List).length
            : 0;
        final recovery = data['recovery'];
        final recoveryType =
            (recovery is Map ? recovery['type'] : null) as String?;
        final recoveryAmount = (recovery is Map && recovery['amount'] is num)
            ? (recovery['amount'] as num).toDouble()
            : null;
        return [
          doc.id,
          submittedAt,
          orderCount,
          stockCount,
          recoveryType ?? '',
          recoveryAmount ?? '',
          (data['notes'] as String?)?.trim() ?? '',
          (data['shopTitle'] as String?) ?? '',
          (data['tsaId'] as String?) ?? '',
        ];
      }).toList();

      final exporter = ExcelExporter();
      final result = await exporter.exportWorkbook(
        fileName: fileName,
        sheets: [
          ExcelSheet(
            name: 'SUMMARY',
            headers: const [
              'tsa_id',
              'shop_id',
              'shop_title',
              'exported_at',
              'imported_sales_count',
              'live_visit_count',
            ],
            rows: [
              [
                tsaId,
                shopId,
                shopTitle,
                now.toIso8601String(),
                salesDocs.length,
                visitDocs.length,
              ],
            ],
          ),
          ExcelSheet(
            name: 'IMPORTED_SALES',
            headers: const ['doc_id', 'label', 'canola', 'corn', 'total'],
            rows: salesRows,
          ),
          ExcelSheet(
            name: 'LIVE_VISITS',
            headers: const [
              'visit_doc_id',
              'submitted_at',
              'order_count',
              'stock_count',
              'recovery_type',
              'recovery_amount',
              'notes',
              'shop_title',
              'tsa_id',
            ],
            rows: visitRows,
          ),
        ],
      );

      final savedPath = await saveBytesToUserFile(
        fileName: result.fileName,
        bytes: result.bytes,
      );

      if (!context.mounted) return;
      AppToast.success(
        'Export complete',
        message: savedPath == null
            ? 'Excel download started.'
            : 'Excel saved to: $savedPath',
      );
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error('Export failed', message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final args = (Get.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final tsaId = (args['tsaId'] as String?) ?? '';
    final shopId = (args['shopId'] as String?) ?? '';
    final shopTitle = (args['shopTitle'] as String?) ?? shopId;

    if (tsaId.isEmpty || shopId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Missing tsaId/shopId')));
    }

    final salesStream = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops')
        .doc(shopId)
        .collection('sales')
        .orderBy('sortKey')
        .snapshots();

    final visitsStream = FirebaseFirestore.instance
        .collectionGroup('shopVisits')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.offAllNamed(_resolveDashboardRoute()),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to dashboard',
        ),
        title: Text(shopTitle),
        actions: [
          const ThemeModeToggleButton(),
          IconButton(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: salesStream,
          builder: (context, salesSnap) {
            if (salesSnap.hasError) {
              return Center(child: Text(salesSnap.error.toString()));
            }
            if (!salesSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: visitsStream,
              builder: (context, visitsSnap) {
                if (visitsSnap.hasError) {
                  return Center(child: Text(visitsSnap.error.toString()));
                }
                if (!visitsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final salesDocs = salesSnap.data!.docs;
                final visitDocs =
                    visitsSnap.data!.docs.where((doc) {
                      final data = doc.data();
                      final visitShopId =
                          ((data['shopId'] as String?) ?? doc.id).trim();
                      if (visitShopId != shopId) return false;

                      final visitTsaId = ((data['tsaId'] as String?) ?? '')
                          .trim();
                      if (visitTsaId == tsaId) return true;

                      // Backward compatibility for old visits that missed tsaId.
                      // Keep these only when distributorId matches current tsaId.
                      if (visitTsaId.isEmpty) {
                        final distributorId =
                            ((data['distributorId'] as String?) ?? '').trim();
                        return distributorId == tsaId;
                      }
                      return false;
                    }).toList()..sort((a, b) {
                      final aDate = _toDate(a.data()['submittedAt']);
                      final bDate = _toDate(b.data()['submittedAt']);
                      if (aDate == null && bDate == null) return 0;
                      if (aDate == null) return 1;
                      if (bDate == null) return -1;
                      return bDate.compareTo(aDate);
                    });

                if (salesDocs.isEmpty && visitDocs.isEmpty) {
                  return const Center(
                    child: Text('No sales or visit data found.'),
                  );
                }

                return ListView(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: ElevatedButton.icon(
                        onPressed: () => _exportSalesData(
                          context,
                          tsaId: tsaId,
                          shopId: shopId,
                          shopTitle: shopTitle,
                          salesDocs: salesDocs,
                          visitDocs: visitDocs,
                        ),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Export Sales Data'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (salesDocs.isNotEmpty) ...[
                      const SectionTitle(
                        title: 'Imported Sales',
                        subtitle: 'Excel or seeded period-wise sales data.',
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(salesDocs.length, (index) {
                        final data = salesDocs[index].data();
                        final label =
                            (data['label'] as String?) ?? salesDocs[index].id;
                        final canola =
                            (data['canola'] as num?)?.toDouble() ?? 0;
                        final corn = (data['corn'] as num?)?.toDouble() ?? 0;
                        final total = (data['total'] as num?)?.toDouble() ?? 0;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == salesDocs.length - 1 ? 0 : 12,
                          ),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 46,
                                  width: 46,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentSoft,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.pie_chart,
                                    color: AppTheme.accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Canola: $canola | Corn: $corn | Total: $total',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    if (salesDocs.isNotEmpty && visitDocs.isNotEmpty)
                      const SizedBox(height: 16),
                    if (visitDocs.isNotEmpty) ...[
                      const SectionTitle(
                        title: 'Live Visit Entries',
                        subtitle:
                            'Data submitted by field visit (orders, stock, recovery).',
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(visitDocs.length, (index) {
                        final data = visitDocs[index].data();
                        final submittedAt = _toDate(data['submittedAt']);
                        final orderCount = (data['orders'] is List)
                            ? (data['orders'] as List).length
                            : 0;
                        final stockCount = (data['stockItems'] is List)
                            ? (data['stockItems'] as List).length
                            : 0;
                        final recovery = data['recovery'];
                        final recoveryAmount =
                            (recovery is Map && recovery['amount'] is num)
                            ? (recovery['amount'] as num).toDouble()
                            : null;
                        final recoveryType =
                            (recovery is Map ? recovery['type'] : null)
                                as String?;
                        final notes = (data['notes'] as String?)?.trim() ?? '';

                        final chips = <String>[
                          'Submitted ${_formatDate(submittedAt)}',
                          'Orders $orderCount',
                          'Stock $stockCount',
                          if (recoveryAmount != null)
                            '${(recoveryType ?? 'recovery').toUpperCase()} ${recoveryAmount.toStringAsFixed(2)}',
                        ];

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == visitDocs.length - 1 ? 0 : 12,
                          ),
                          child: GestureDetector(
                            onTap: () => _openVisitDetails(
                              context,
                              visitId: visitDocs[index].id,
                              data: data,
                              defaultShopTitle: shopTitle,
                            ),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 46,
                                    width: 46,
                                    decoration: BoxDecoration(
                                      color: AppTheme.skySoft,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.assignment_turned_in_outlined,
                                      color: AppTheme.sky,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatDayDate(
                                            submittedAt ?? DateTime.now(),
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          chips.join(' | '),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        if (notes.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Notes: $notes',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppTheme.mutedInk,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
