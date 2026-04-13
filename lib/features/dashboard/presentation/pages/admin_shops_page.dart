import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_toast.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../app/ui/theme_mode_toggle_button.dart';
import '../../../../core/utils/map_location_url_parser.dart';

class AdminShopsPage extends StatefulWidget {
  const AdminShopsPage({super.key});

  @override
  State<AdminShopsPage> createState() => _AdminShopsPageState();
}

class _AdminShopsPageState extends State<AdminShopsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim().toLowerCase();
    if (nextQuery == _searchQuery) return;
    setState(() {
      _searchQuery = nextQuery;
    });
  }

  bool _matchesShopQuery(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String query,
  ) {
    if (query.isEmpty) return true;
    final data = doc.data();
    final fields = [
      doc.id,
      data['code'] as String? ?? '',
      data['name'] as String? ?? '',
      data['area'] as String? ?? '',
      data['assignedDsfId'] as String? ?? '',
      data['assignedDsfUid'] as String? ?? '',
    ];
    return fields.any((value) => value.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final shopsCol = FirebaseFirestore.instance.collection('shops');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.offAllNamed(AppRoutes.adminDashboard),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to dashboard',
        ),
        titleSpacing: 20,
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: AppTheme.warmSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.store_mall_directory_outlined,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Shops',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                SizedBox(height: 2),
                Text(
                  'Codes, filer status, routes',
                  style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: const [ThemeModeToggleButton(), SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, shopsCol: shopsCol),
        child: const Icon(Icons.add),
      ),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: shopsCol.orderBy('code').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No shops yet. Add your first.'));
            }
            final filteredDocs = docs
                .where((doc) => _matchesShopQuery(doc, _searchQuery))
                .toList();
            final list = ListView.separated(
              itemCount: filteredDocs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data();
                final code = (data['code'] as String?) ?? doc.id;
                final name = (data['name'] as String?) ?? '';
                final filer = (data['filer'] as bool?) ?? false;
                final discount = (data['discountPct'] as num?)?.toDouble();
                final discountEnabled =
                    (data['discountEnabled'] as bool?) ?? true;
                final effectiveDiscount = discount ?? (filer ? 0.05 : 0.025);
                final assigned = (data['assignedDsfId'] as String?) ?? '';
                return GlassCard(
                  onTap: () => _openForm(
                    context,
                    shopsCol: shopsCol,
                    existingId: doc.id,
                    existing: data,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.store, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$code ${name.isEmpty ? '' : '- $name'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                filer ? 'Filer' : 'Non-filer',
                                if (!discountEnabled)
                                  'Discount off'
                                else
                                  'Discount ${(effectiveDiscount * 100).toStringAsFixed(1)}%',
                                if (assigned.isNotEmpty) 'DSF $assigned',
                              ].join(' · '),
                              style: const TextStyle(color: AppTheme.mutedInk),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openForm(
                          context,
                          shopsCol: shopsCol,
                          existingId: doc.id,
                          existing: data,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete shop',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final shopCode = code.trim().isEmpty
                              ? doc.id
                              : code.trim();
                          final shopName = name.trim();

                          final confirmed = await _confirmDeleteShop(
                            context,
                            shopCode: shopCode,
                            shopName: shopName,
                          );
                          if (!confirmed) return;

                          try {
                            final deletedCount = await _deleteShopEverywhere(
                              shopId: doc.id,
                            );
                            if (!context.mounted) return;
                            AppToast.success(
                              'Deleted',
                              message:
                                  'Shop "$shopCode" removed from $deletedCount records.',
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            AppToast.error(
                              'Delete failed',
                              message: e.toString(),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );

            final content = filteredDocs.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No shops yet. Add your first.'
                          : 'No shop found for "${_searchController.text.trim()}".',
                    ),
                  )
                : list;

            if (!kIsWeb) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  Expanded(child: content),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.store_mall_directory_outlined,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Shops Workspace',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _searchQuery.isEmpty
                                  ? '${docs.length} shops in network'
                                  : '${filteredDocs.length} of ${docs.length} shops',
                              style: const TextStyle(
                                color: AppTheme.mutedInk,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openForm(context, shopsCol: shopsCol),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Shop'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 12),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasValue = _searchController.text.trim().isNotEmpty;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search shop by code, name, area, or DSF',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: hasValue
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context, {
    required CollectionReference<Map<String, dynamic>> shopsCol,
    String? existingId,
    Map<String, dynamic>? existing,
  }) async {
    final dsfOptions = await _loadDsfs();
    if (!context.mounted) return;
    final codeController = TextEditingController(
      text: existing?['code'] as String? ?? existingId ?? '',
    );
    final nameController = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final areaController = TextEditingController(
      text: existing?['area'] as String? ?? '',
    );
    final latController = TextEditingController(
      text: _readNum(existing, 'location.lat'),
    );
    final lngController = TextEditingController(
      text: _readNum(existing, 'location.lng'),
    );
    LatLng? picked;
    final initialLoc = _readLatLng(latController.text, lngController.text);
    final existingAssigned = (existing?['assignedDsfId'] as String?)?.trim();
    final existingAssignedUid = (existing?['assignedDsfUid'] as String?)
        ?.trim();
    String? selectedDsf = _resolveSelectedDsfId(
      dsfOptions,
      preferredId: existingAssigned,
      preferredUid: existingAssignedUid,
    );
    var schedule = _buildScheduleState(
      existing?['schedule'] as Map?,
      selectCurrentDayIfEmpty: existingId != null,
    );
    bool filer = existing?['filer'] == true;
    bool discountEnabled = (existing?['discountEnabled'] as bool?) ?? true;
    final existingDiscountPct = (existing?['discountPct'] as num?)?.toDouble();
    final discountController = TextEditingController(
      text: _formatPercentInput(existingDiscountPct ?? (filer ? 0.05 : 0.025)),
    );
    bool isDeleting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingId == null ? 'Add shop' : 'Edit shop'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sectionCard(
                        child: Column(
                          children: [
                            TextField(
                              controller: codeController,
                              decoration: const InputDecoration(
                                labelText: 'Code',
                              ),
                              readOnly: existingId != null,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: areaController,
                              decoration: const InputDecoration(
                                labelText: 'Area',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: filer,
                              onChanged: (v) => setState(() => filer = v),
                              title: const Text('Filer shop'),
                            ),
                            const SizedBox(height: 6),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: discountEnabled,
                              onChanged: (v) {
                                setState(() {
                                  discountEnabled = v;
                                });
                              },
                              title: const Text('Allow discount'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: discountController,
                              enabled: discountEnabled,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Discount %',
                                suffixText: '%',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: latController,
                                    decoration: const InputDecoration(
                                      labelText: 'Lat',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: lngController,
                                    decoration: const InputDecoration(
                                      labelText: 'Lng',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final res = await _pickOnMap(
                                    context,
                                    initial: picked ?? initialLoc,
                                  );
                                  if (res == null) return;
                                  setState(() {
                                    picked = res;
                                    latController.text = res.latitude
                                        .toStringAsFixed(6);
                                    lngController.text = res.longitude
                                        .toStringAsFixed(6);
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                ),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Pick on map'),
                              ),
                            ),
                            if (picked != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Picked: ${picked!.latitude.toStringAsFixed(6)}, ${picked!.longitude.toStringAsFixed(6)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final dropdownItems =
                                    <DropdownMenuItem<String>>[
                                      const DropdownMenuItem(
                                        value: '',
                                        child: Text('Unassigned'),
                                      ),
                                      ...dsfOptions.map(
                                        (d) => DropdownMenuItem(
                                          value: d.id,
                                          child: Text(
                                            d.name.isNotEmpty
                                                ? '${d.name} (${d.id})'
                                                : d.id,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ];

                                return DropdownButtonFormField<String>(
                                  initialValue:
                                      (selectedDsf != null &&
                                          dsfOptions.any(
                                            (o) => o.id == selectedDsf,
                                          ))
                                      ? selectedDsf
                                      : '',
                                  decoration: const InputDecoration(
                                    labelText: 'Assigned DSF',
                                  ),
                                  isExpanded: true,
                                  items: dropdownItems,
                                  selectedItemBuilder: (context) =>
                                      dropdownItems
                                          .map(
                                            (item) => Align(
                                              alignment: Alignment.centerLeft,
                                              child: DefaultTextStyle.merge(
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                child: item.child,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) => setState(
                                    () => selectedDsf = (v == null || v.isEmpty)
                                        ? null
                                        : v,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final pickedSchedule = await _pickSchedule(
                                    context,
                                    schedule,
                                  );
                                  if (pickedSchedule != null) {
                                    setState(() {
                                      schedule = pickedSchedule;
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                ),
                                label: const Text('Pick days'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Schedule',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: schedule.keys.map((d) {
                                final selected = schedule[d] == true;
                                return FilterChip(
                                  label: Text(
                                    d.toUpperCase(),
                                    style: TextStyle(
                                      color: selected
                                          ? AppTheme.antiFlashWhite
                                          : AppTheme.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  showCheckmark: false,
                                  selectedColor: AppTheme.bangladeshGreen,
                                  backgroundColor: AppTheme.skySoft,
                                  side: BorderSide(
                                    color: selected
                                        ? AppTheme.darkGreen
                                        : AppTheme.accentSoft,
                                  ),
                                  selected: selected,
                                  onSelected: (v) {
                                    setState(() {
                                      schedule[d] = v;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final deleteButton = existingId == null
                          ? null
                          : OutlinedButton.icon(
                              onPressed: isDeleting
                                  ? null
                                  : () async {
                                      final shopCode =
                                          (existing?['code'] as String?)
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? (existing?['code'] as String).trim()
                                          : existingId;
                                      final shopName =
                                          (existing?['name'] as String?)
                                              ?.trim() ??
                                          '';
                                      final confirmed = await _confirmDeleteShop(
                                        context,
                                        shopCode: shopCode,
                                        shopName: shopName,
                                      );
                                      if (!confirmed) return;

                                      setState(() => isDeleting = true);
                                      try {
                                        final deletedCount =
                                            await _deleteShopEverywhere(
                                              shopId: existingId,
                                            );
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                        AppToast.success(
                                          'Deleted',
                                          message:
                                              'Shop $shopCode removed ($deletedCount records).',
                                        );
                                      } catch (e) {
                                        AppToast.error(
                                          'Delete failed',
                                          message: e.toString(),
                                        );
                                      } finally {
                                        if (context.mounted) {
                                          setState(() => isDeleting = false);
                                        }
                                      }
                                    },
                              icon: isDeleting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                            );

                      final cancelButton = TextButton(
                        onPressed: isDeleting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      );

                      final saveButton = ElevatedButton(
                        onPressed: isDeleting
                            ? null
                            : () async {
                                final code = codeController.text.trim();
                                if (code.isEmpty) return;
                                if (selectedDsf != null &&
                                    !schedule.values.any((v) => v == true)) {
                                  final pickedSchedule = await _pickSchedule(
                                    context,
                                    schedule,
                                  );
                                  if (pickedSchedule == null ||
                                      !pickedSchedule.values.any(
                                        (v) => v == true,
                                      )) {
                                    return;
                                  }
                                  schedule = pickedSchedule;
                                  setState(() {});
                                }
                                double discountPct = 0;
                                if (discountEnabled) {
                                  final parsed = double.tryParse(
                                    discountController.text.trim(),
                                  );
                                  if (parsed == null ||
                                      parsed.isNaN ||
                                      parsed < 0 ||
                                      parsed > 100) {
                                    AppToast.warning(
                                      'Invalid discount',
                                      message:
                                          'Enter discount between 0 and 100.',
                                    );
                                    return;
                                  }
                                  discountPct = parsed / 100;
                                }
                                final payload = <String, dynamic>{
                                  'code': code,
                                  'name': nameController.text.trim(),
                                  'area': areaController.text.trim(),
                                  'filer': filer,
                                  'discountEnabled': discountEnabled,
                                  'discountPct': discountPct,
                                  'assignedDsfId': selectedDsf ?? '',
                                  'assignedDsfUid': _resolveSelectedDsfUid(
                                    dsfOptions,
                                    selectedDsf,
                                  ),
                                  'schedule': schedule,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                };
                                final lat = double.tryParse(
                                  latController.text.trim(),
                                );
                                final lng = double.tryParse(
                                  lngController.text.trim(),
                                );
                                if (lat != null && lng != null) {
                                  payload['location'] = {
                                    'lat': lat,
                                    'lng': lng,
                                  };
                                }
                                if (existingId == null) {
                                  payload['createdAt'] =
                                      FieldValue.serverTimestamp();
                                }
                                await shopsCol
                                    .doc(existingId ?? code.toLowerCase())
                                    .set(payload, SetOptions(merge: true));
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                                AppToast.success(
                                  'Saved',
                                  message: 'Shop $code saved',
                                );
                              },
                        child: const Text('Save'),
                      );

                      if (constraints.maxWidth < 320) {
                        return Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (deleteButton != null) deleteButton,
                            cancelButton,
                            saveButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          if (deleteButton != null) deleteButton,
                          const Spacer(),
                          cancelButton,
                          const SizedBox(width: 8),
                          saveButton,
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDeleteShop(
    BuildContext context, {
    required String shopCode,
    required String shopName,
  }) async {
    final title = shopName.isNotEmpty ? '$shopCode - $shopName' : shopCode;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete shop everywhere'),
        content: Text(
          'This will permanently delete "$title" from all related places, including\n\n'
          '- global shops\n'
          '- TSA shop lists\n'
          '- daily assignments\n'
          '- shop sales subcollection\n'
          '- duty visit records\n'
          '- alerts\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<int> _deleteShopEverywhere({required String shopId}) async {
    final firestore = FirebaseFirestore.instance;
    final refs = <DocumentReference>[];

    // Global shop document.
    refs.add(firestore.collection('shops').doc(shopId));

    // Alerts linked to this shop.
    final alertsSnap = await firestore
        .collection('alerts')
        .where('shopId', isEqualTo: shopId)
        .get();
    refs.addAll(alertsSnap.docs.map((doc) => doc.reference));

    // Visit documents across all duties without requiring a collection-group
    // index for shopVisits.shopId.
    refs.addAll(await _findShopVisitRefsWithoutCollectionGroupIndex(shopId));

    // Remove from all TSA scopes: shops, sales, and daily assignments.
    final seedTsasSnap = await firestore.collection('seedTsas').get();
    for (final tsaDoc in seedTsasSnap.docs) {
      final tsaRef = tsaDoc.reference;
      final tsaShopRef = tsaRef.collection('shops').doc(shopId);

      final salesSnap = await tsaShopRef.collection('sales').get();
      refs.addAll(salesSnap.docs.map((doc) => doc.reference));
      refs.add(tsaShopRef);

      final assignmentDaysSnap = await tsaRef
          .collection('dailyAssignments')
          .get();
      for (final dayDoc in assignmentDaysSnap.docs) {
        refs.add(dayDoc.reference.collection('shops').doc(shopId));
      }
    }

    // De-duplicate and delete in safe Firestore batch chunks.
    final unique = <String, DocumentReference>{};
    for (final ref in refs) {
      unique[ref.path] = ref;
    }

    var deletedCount = 0;
    var opsInBatch = 0;
    var batch = firestore.batch();

    for (final ref in unique.values) {
      batch.delete(ref);
      deletedCount++;
      opsInBatch++;
      if (opsInBatch >= 450) {
        await batch.commit();
        batch = firestore.batch();
        opsInBatch = 0;
      }
    }

    if (opsInBatch > 0) {
      await batch.commit();
    }

    return deletedCount;
  }

  Future<List<DocumentReference<Map<String, dynamic>>>>
  _findShopVisitRefsWithoutCollectionGroupIndex(String shopId) async {
    final firestore = FirebaseFirestore.instance;
    final targetShopId = shopId.trim();
    if (targetShopId.isEmpty) return const [];

    final refs = <DocumentReference<Map<String, dynamic>>>[];
    final dutiesSnap = await firestore.collection('duties').get();

    for (final dutyDoc in dutiesSnap.docs) {
      final visitsSnap = await dutyDoc.reference.collection('shopVisits').get();
      for (final visitDoc in visitsSnap.docs) {
        final data = visitDoc.data();
        final visitShopId = ((data['shopId'] as String?) ?? visitDoc.id).trim();
        if (visitShopId == targetShopId) {
          refs.add(visitDoc.reference);
        }
      }
    }

    return refs;
  }

  String _formatPercentInput(double rate) {
    final percent = rate * 100;
    final rounded = percent.toStringAsFixed(2);
    return rounded.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _readNum(Map<String, dynamic>? data, String path) {
    if (data == null) return '';
    dynamic cur = data;
    for (final part in path.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return '';
      }
    }
    if (cur is num) return cur.toString();
    return '';
  }

  LatLng? _readLatLng(String lat, String lng) {
    final latVal = double.tryParse(lat);
    final lngVal = double.tryParse(lng);
    if (latVal == null || lngVal == null) return null;
    return LatLng(latVal, lngVal);
  }

  Future<LatLng?> _pickOnMap(BuildContext context, {LatLng? initial}) async {
    final result = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShopMapPickerSheet(
        initialCenter: initial ?? const LatLng(23.8103, 90.4125),
      ),
    );
    return result;
  }

  Future<List<_DsfOption>> _loadDsfs() async {
    final snap = await FirebaseFirestore.instance
        .collection('dsfAccounts')
        .orderBy('name')
        .get();
    return snap.docs
        .map(
          (d) => _DsfOption(
            id: d.id,
            name: (d.data()['name'] as String?)?.trim() ?? '',
            uid: (d.data()['uid'] as String?)?.trim() ?? d.id,
          ),
        )
        .toList();
  }

  String? _resolveSelectedDsfId(
    List<_DsfOption> options, {
    required String? preferredId,
    required String? preferredUid,
  }) {
    final id = preferredId?.trim();
    if (id != null && id.isNotEmpty) {
      final direct = options.any((o) => o.id == id);
      if (direct) return id;
      final byUid = options.where((o) => o.uid == id).toList();
      if (byUid.length == 1) return byUid.single.id;
    }
    final uid = preferredUid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final byUid = options.where((o) => o.uid == uid).toList();
      if (byUid.length == 1) return byUid.single.id;
    }
    return null;
  }

  String _resolveSelectedDsfUid(List<_DsfOption> options, String? selectedId) {
    final id = selectedId?.trim();
    if (id == null || id.isEmpty) return '';
    final match = options.where((o) => o.id == id).toList();
    if (match.length == 1) return match.single.uid;
    return '';
  }

  Map<String, bool> _buildScheduleState(
    Map? rawSchedule, {
    bool selectCurrentDayIfEmpty = false,
  }) {
    final schedule = Map<String, bool>.fromEntries(
      _scheduleDays.map(
        (day) => MapEntry(day, rawSchedule?[day] == true),
      ),
    );
    if (selectCurrentDayIfEmpty && !schedule.values.any((selected) => selected)) {
      schedule[_currentDayKey()] = true;
    }
    return schedule;
  }

  String _currentDayKey() {
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  static const List<String> _scheduleDays = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  Future<Map<String, bool>?> _pickSchedule(
    BuildContext context,
    Map<String, bool> current,
  ) async {
    final working = Map<String, bool>.from(current);
    final result = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Schedule',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: working.keys.map((d) {
                        final selected = working[d] == true;
                        return FilterChip(
                          label: Text(
                            d.toUpperCase(),
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.antiFlashWhite
                                  : AppTheme.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          showCheckmark: false,
                          selectedColor: AppTheme.bangladeshGreen,
                          backgroundColor: AppTheme.skySoft,
                          side: BorderSide(
                            color: selected
                                ? AppTheme.darkGreen
                                : AppTheme.accentSoft,
                          ),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              working[d] = v;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(Map<String, bool>.from(working)),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return result;
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _DsfOption {
  final String id;
  final String name;
  final String uid;

  const _DsfOption({required this.id, required this.name, required this.uid});
}

class _ShopMapPickerSheet extends StatefulWidget {
  final LatLng initialCenter;

  const _ShopMapPickerSheet({required this.initialCenter});

  @override
  State<_ShopMapPickerSheet> createState() => _ShopMapPickerSheetState();
}

class _ShopMapPickerSheetState extends State<_ShopMapPickerSheet> {
  late LatLng _center;
  final _mapController = MapController();
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLocating = false;
  String? _error;
  List<_PlaceResult> _results = [];

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    if (await _tryMoveToSharedLocation(trimmed)) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': trimmed,
        'limit': '5',
      });
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'field_sales_app/1.0 (shop picker)'},
      );
      if (response.statusCode != 200) {
        throw StateError('Search failed (${response.statusCode}).');
      }
      final raw = jsonDecode(response.body);
      if (raw is! List) {
        throw StateError('Unexpected search response.');
      }
      final parsed = <_PlaceResult>[];
      for (final item in raw) {
        final place = _PlaceResult.fromJson(item);
        if (place != null) parsed.add(place);
      }
      setState(() {
        _results = parsed;
        _error = parsed.isEmpty ? 'No results found.' : null;
      });
    } catch (_) {
      setState(() {
        _error = 'Search failed. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _results = [];
      });
      _mapController.move(_center, 16);
    } catch (_) {
      setState(() {
        _error = 'Unable to get current location.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _selectPlace(_PlaceResult place) {
    setState(() {
      _center = LatLng(place.lat, place.lng);
      _results = [];
      _error = null;
    });
    _mapController.move(_center, 16);
  }

  Future<bool> _tryMoveToSharedLocation(String raw) async {
    final parsed = await MapLocationUrlParser.tryParseSmart(raw);
    if (parsed == null) return false;
    setState(() {
      _center = LatLng(parsed.lat, parsed.lng);
      _results = [];
      _error = null;
    });
    _mapController.move(_center, 16);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.82;
    return Container(
      height: height,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pick shop location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _searchPlace,
              decoration: InputDecoration(
                hintText: 'Search location or paste map URL',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _results = [];
                                  _error = null;
                                });
                              },
                              icon: const Icon(Icons.clear),
                            )),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Use current location'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = _results[index];
                    return ListTile(
                      title: Text(
                        place.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectPlace(place),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        _center = latLng;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'field_sales_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _center,
                          width: 42,
                          height: 42,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_center),
              child: const Text('Use this location'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceResult {
  final String label;
  final double lat;
  final double lng;

  const _PlaceResult({
    required this.label,
    required this.lat,
    required this.lng,
  });

  static _PlaceResult? fromJson(Object? value) {
    if (value is! Map) return null;
    final displayName = value['display_name'];
    final latRaw = value['lat'];
    final lngRaw = value['lon'];
    if (displayName is! String || latRaw == null || lngRaw == null) {
      return null;
    }
    final lat = double.tryParse(latRaw.toString());
    final lng = double.tryParse(lngRaw.toString());
    if (lat == null || lng == null) return null;
    return _PlaceResult(label: displayName, lat: lat, lng: lng);
  }
}
