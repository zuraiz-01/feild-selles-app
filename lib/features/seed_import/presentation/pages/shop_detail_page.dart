import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/utils/file_save.dart';
import '../../../reports/domain/export/excel_exporter.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class ShopDetailPage extends StatelessWidget {
  const ShopDetailPage({super.key});

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
      Get.snackbar(
        'Export complete',
        savedPath == null
            ? 'Excel download started.'
            : 'Excel saved to: $savedPath',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (!context.mounted) return;
      Get.snackbar(
        'Export failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
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
        .where('shopId', isEqualTo: shopId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.offAllNamed(AppRoutes.adminDashboard),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to dashboard',
        ),
        title: Text(shopTitle),
        actions: [
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
                      final visitTsaId = ((data['tsaId'] as String?) ?? '')
                          .trim();
                      // Some older/global flows saved shop visits without tsaId.
                      return visitTsaId == tsaId || visitTsaId.isEmpty;
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
                                        'Visit ${index + 1}',
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
                              ],
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
