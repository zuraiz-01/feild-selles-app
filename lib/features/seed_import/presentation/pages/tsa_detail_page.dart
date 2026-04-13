import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';

import '../../../../app/routes/app_routes.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_toast.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../app/ui/theme_mode_toggle_button.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../../core/utils/shop_assignment_sync.dart';
import '../../../../core/utils/map_location_url_parser.dart';
import '../../data/seed_utils.dart';

class TsaDetailPage extends StatelessWidget {
  const TsaDetailPage({super.key});

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

  bool _isImportedShop(Map<String, dynamic> data) {
    return data['importId'] != null || data['importedAt'] != null;
  }

  String _resolveDsfUid(
    QuerySnapshot<Map<String, dynamic>> dsfOptions,
    String? dsfId,
  ) {
    final id = dsfId?.trim();
    if (id == null || id.isEmpty) return '';
    final matches = dsfOptions.docs.where((doc) => doc.id == id).toList();
    if (matches.length != 1) return '';
    return (matches.single.data()['uid'] as String?)?.trim() ?? '';
  }

  String _resolveDsfName(
    QuerySnapshot<Map<String, dynamic>> dsfOptions,
    String? dsfId,
  ) {
    final id = dsfId?.trim();
    if (id == null || id.isEmpty) return '';
    final matches = dsfOptions.docs.where((doc) => doc.id == id).toList();
    if (matches.length != 1) return '';
    return (matches.single.data()['name'] as String?)?.trim() ?? '';
  }

  static const _dayOptions = <Map<String, String>>[
    {'key': 'mon', 'label': 'Monday'},
    {'key': 'tue', 'label': 'Tuesday'},
    {'key': 'wed', 'label': 'Wednesday'},
    {'key': 'thu', 'label': 'Thursday'},
    {'key': 'fri', 'label': 'Friday'},
    {'key': 'sat', 'label': 'Saturday'},
    {'key': 'sun', 'label': 'Sunday'},
  ];

  String _labelForDayKey(String key) {
    for (final item in _dayOptions) {
      if (item['key'] == key) return item['label'] ?? key;
    }
    return key;
  }

  Future<String?> _pickDayKey(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select day'),
        children: [
          for (final item in _dayOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(item['key']),
              child: Text(item['label'] ?? ''),
            ),
        ],
      ),
    );
  }

  Future<void> _assignShopsForDay(
    BuildContext context, {
    required String tsaId,
    required String dayKey,
  }) async {
    final shopsCol = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops');
    final assignmentRoot = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('dailyAssignments')
        .doc(dayKey)
        .collection('shops');

    final shopsSnap = await shopsCol.orderBy('code').get();
    final availableShops = shopsSnap.docs
        .where((doc) => !_isImportedShop(doc.data()))
        .toList();
    final currentAssignedSnap = await assignmentRoot.get();
    if (!context.mounted) return;
    final availableIds = availableShops.map((d) => d.id).toSet();
    final selected = currentAssignedSnap.docs
        .map((d) => d.id)
        .where(availableIds.contains)
        .toSet();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final working = Set<String>.from(selected);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Assign shops (${_labelForDayKey(dayKey)})'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final doc in availableShops)
                      CheckboxListTile(
                        value: working.contains(doc.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              working.add(doc.id);
                            } else {
                              working.remove(doc.id);
                            }
                          });
                        },
                        title: Text(
                          ((doc.data()['name'] as String?)?.trim().isNotEmpty ??
                                  false)
                              ? '${doc.data()['name']} (${doc.data()['code'] ?? doc.id})'
                              : (doc.data()['code'] as String?) ?? doc.id,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final firestore = FirebaseFirestore.instance;
                    var batch = firestore.batch();
                    var ops = 0;

                    Future<void> commitIfNeeded() async {
                      if (ops < 450) return;
                      await batch.commit();
                      batch = firestore.batch();
                      ops = 0;
                    }

                    for (final doc in currentAssignedSnap.docs) {
                      batch.delete(doc.reference);
                      ops++;
                      await commitIfNeeded();
                    }
                    for (final id in working) {
                      batch.set(assignmentRoot.doc(id), {
                        'assignedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                      ops++;
                      await commitIfNeeded();
                    }
                    if (ops > 0) {
                      await batch.commit();
                    }
                    if (!context.mounted) return;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      AppToast.success(
        'Saved',
        message: 'Assignments updated for ${_labelForDayKey(dayKey)}.',
      );
    }
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

  String _formatPercentInput(double rate) {
    final percent = rate * 100;
    final rounded = percent.toStringAsFixed(2);
    return rounded.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> _createShop(BuildContext context, String tsaId) async {
    final dsfOptions = await FirebaseFirestore.instance
        .collection('dsfAccounts')
        .orderBy('name')
        .get();
    if (!context.mounted) return;
    final shopsCol = FirebaseFirestore.instance.collection('shops');
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final areaController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String? selectedDsf = dsfOptions.docs.any((d) => d.id == tsaId)
        ? tsaId
        : null;
    var schedule = {
      'mon': true,
      'tue': true,
      'wed': true,
      'thu': true,
      'fri': true,
      'sat': false,
      'sun': false,
    };
    bool filer = false;
    bool discountEnabled = true;
    final discountController = TextEditingController(
      text: _formatPercentInput(0.025),
    );
    LatLng? picked;

    final result = await showDialog<_CreateShopResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add shop'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: codeController,
                            decoration: const InputDecoration(
                              labelText: 'Code',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                          ),
                          const SizedBox(height: 14),
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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                            keyboardType: const TextInputType.numberWithOptions(
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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                          OutlinedButton.icon(
                            onPressed: () async {
                              final res = await _pickOnMap(
                                context,
                                initial: picked,
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
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Pick on map'),
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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue:
                                (selectedDsf != null &&
                                    dsfOptions.docs.any(
                                      (d) => d.id == selectedDsf,
                                    ))
                                ? selectedDsf
                                : '',
                            decoration: const InputDecoration(
                              labelText: 'Assigned DSF',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Unassigned'),
                              ),
                              ...dsfOptions.docs.map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    ((d.data()['name'] as String?)
                                                ?.trim()
                                                .isNotEmpty ??
                                            false)
                                        ? '${d.data()['name']} (${d.id})'
                                        : d.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => selectedDsf = (v == null || v.isEmpty)
                                  ? null
                                  : v,
                            ),
                          ),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final code = codeController.text.trim();
                    if (code.isEmpty) return;
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
                          message: 'Enter discount between 0 and 100.',
                        );
                        return;
                      }
                      discountPct = parsed / 100;
                    }
                    Navigator.of(context).pop(
                      _CreateShopResult(
                        code: code,
                        name: nameController.text.trim(),
                        area: areaController.text.trim(),
                        lat:
                            double.tryParse(latController.text.trim()) ??
                            picked?.latitude,
                        lng:
                            double.tryParse(lngController.text.trim()) ??
                            picked?.longitude,
                        filer: filer,
                        discountEnabled: discountEnabled,
                        discountPct: discountPct,
                        dsfId: selectedDsf,
                        schedule: schedule,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final payload = <String, dynamic>{
      'code': result.code,
      'name': result.name,
      'area': result.area,
      'filer': result.filer,
      'discountEnabled': result.discountEnabled,
      'discountPct': result.discountEnabled ? result.discountPct : 0.0,
      'tsaId': tsaId,
      'assignedDsfId': result.dsfId ?? '',
      'assignedDsfUid': _resolveDsfUid(dsfOptions, result.dsfId),
      'schedule': result.schedule,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (result.lat != null && result.lng != null) {
      payload['location'] = {'lat': result.lat, 'lng': result.lng};
    }
    final shopId = slugifyId(result.code);
    await shopsCol.doc(shopId).set(payload, SetOptions(merge: true));

    // Also add into TSA shops for immediate use.
    final tsaShopRef = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops')
        .doc(shopId);
    await tsaShopRef.set({
      'shopId': shopId,
      'code': result.code,
      'name': result.name,
      'filer': result.filer,
      'discountEnabled': result.discountEnabled,
      'discountPct': result.discountEnabled ? result.discountPct : 0.0,
      if (result.area.isNotEmpty) 'area': result.area,
      if (result.lat != null && result.lng != null)
        'location': {'lat': result.lat, 'lng': result.lng},
      'assignedDsfId': result.dsfId ?? '',
      'assignedDsfUid': _resolveDsfUid(dsfOptions, result.dsfId),
      'schedule': result.schedule,
      'tsaId': tsaId,
      'source': 'admin_dialog',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await syncShopTsaAssignment(
      firestore: FirebaseFirestore.instance,
      shopId: shopId,
      previousTsaId: null,
      previousSchedule: null,
      nextTsaId: tsaId,
      nextSchedule: result.schedule,
      nextTsaName: _resolveDsfName(dsfOptions, tsaId),
      nextTsaShopData: {
        'shopId': shopId,
        'code': result.code,
        'name': result.name,
        'filer': result.filer,
        'discountEnabled': result.discountEnabled,
        'discountPct': result.discountEnabled ? result.discountPct : 0.0,
        if (result.area.isNotEmpty) 'area': result.area,
        if (result.lat != null && result.lng != null)
          'location': {'lat': result.lat, 'lng': result.lng},
        'assignedDsfId': result.dsfId ?? '',
        'assignedDsfUid': _resolveDsfUid(dsfOptions, result.dsfId),
        'schedule': result.schedule,
        'tsaId': tsaId,
        'source': 'admin_dialog',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    AppToast.success('Shop added', message: result.code);
  }

  Future<void> _addExistingShop(BuildContext context, String tsaId) async {
    final dsfOptions = await FirebaseFirestore.instance
        .collection('dsfAccounts')
        .orderBy('name')
        .get();
    final globalShops = await FirebaseFirestore.instance
        .collection('shops')
        .orderBy('code')
        .get();
    if (!context.mounted) return;
    if (globalShops.docs.isEmpty) {
      AppToast.warning(
        'No shops found',
        message: 'Add a shop first, then pick from existing.',
      );
      return;
    }
    String? selectedId;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Choose a shop'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: globalShops.docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = globalShops.docs[index];
                    final data = doc.data();
                    final code = (data['code'] as String?) ?? doc.id;
                    final name = (data['name'] as String?) ?? '';
                    final title = '$code ${name.isEmpty ? '' : '• $name'}';
                    final isSelected = selectedId == doc.id;
                    return ListTile(
                      onTap: () => setState(() => selectedId = doc.id),
                      title: Text(title),
                      subtitle: (data['area'] as String?)?.isNotEmpty == true
                          ? Text(data['area'] as String)
                          : null,
                      trailing: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedId == null
                      ? null
                      : () => Navigator.of(context).pop(selectedId),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!context.mounted || picked == null) return;
    final doc = globalShops.docs.firstWhere((d) => d.id == picked);
    final data = doc.data();
    final code = (data['code'] as String?) ?? doc.id;
    final name = (data['name'] as String?) ?? '';
    final area = (data['area'] as String?) ?? '';
    final schedule = normalizeShopSchedule(data['schedule'] as Map?);
    final tsaShopRef = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops')
        .doc(doc.id);
    await tsaShopRef.set({
      'shopId': doc.id,
      'code': code,
      'name': name,
      if (area.isNotEmpty) 'area': area,
      if (data['location'] is Map) 'location': data['location'],
      'filer': data['filer'] == true,
      'discountEnabled': (data['discountEnabled'] as bool?) ?? true,
      'discountPct': (data['discountPct'] as num?)?.toDouble() ?? 0.0,
      'assignedDsfId': (data['assignedDsfId'] as String?) ?? '',
      'assignedDsfUid': (data['assignedDsfUid'] as String?) ?? '',
      'schedule': schedule,
      'tsaId': tsaId,
      'source': 'global_shops',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await syncShopTsaAssignment(
      firestore: FirebaseFirestore.instance,
      shopId: doc.id,
      previousTsaId: null,
      previousSchedule: null,
      nextTsaId: tsaId,
      nextSchedule: schedule,
      nextTsaName: _resolveDsfName(dsfOptions, tsaId),
      nextTsaShopData: {
        'shopId': doc.id,
        'code': code,
        'name': name,
        if (area.isNotEmpty) 'area': area,
        if (data['location'] is Map) 'location': data['location'],
        'filer': data['filer'] == true,
        'discountEnabled': (data['discountEnabled'] as bool?) ?? true,
        'discountPct': (data['discountPct'] as num?)?.toDouble() ?? 0.0,
        'assignedDsfId': (data['assignedDsfId'] as String?) ?? '',
        'assignedDsfUid': (data['assignedDsfUid'] as String?) ?? '',
        'schedule': schedule,
        'tsaId': tsaId,
        'source': 'global_shops',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    AppToast.success('Shop added', message: '$code added from existing shops');
  }

  Future<void> _openAddShopChoice(BuildContext context, String tsaId) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add shop'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('existing'),
            child: const ListTile(
              leading: Icon(Icons.store_mall_directory_outlined),
              title: Text('From existing shops'),
              subtitle: Text('Pick a shop already added in admin'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('new'),
            child: const ListTile(
              leading: Icon(Icons.add_location_alt_outlined),
              title: Text('Add new shop'),
              subtitle: Text('Create a new shop with location'),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'existing') {
      await _addExistingShop(context, tsaId);
    } else if (choice == 'new') {
      await _createShop(context, tsaId);
    }
  }

  Future<Map<String, bool>?> _pickSchedule(
    BuildContext context,
    Map<String, bool> current,
  ) async {
    final working = Map<String, bool>.from(current);
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick visiting days'),
          content: Wrap(
            spacing: 8,
            children: working.keys.map((d) {
              final selected = working[d] == true;
              return FilterChip(
                label: Text(
                  d.toUpperCase(),
                  style: TextStyle(
                    color: selected ? AppTheme.antiFlashWhite : AppTheme.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                showCheckmark: false,
                selectedColor: AppTheme.bangladeshGreen,
                backgroundColor: AppTheme.skySoft,
                side: BorderSide(
                  color: selected ? AppTheme.darkGreen : AppTheme.accentSoft,
                ),
                selected: selected,
                onSelected: (v) => working[d] = v,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(working),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final args = (Get.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final tsaId = (args['tsaId'] as String?) ?? '';
    final tsaName = (args['tsaName'] as String?) ?? tsaId;

    if (tsaId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Missing tsaId')));
    }

    final shopsCol = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.offAllNamed(_resolveDashboardRoute()),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to dashboard',
        ),
        title: Text(tsaName),
        actions: [
          const ThemeModeToggleButton(),
          IconButton(
            onPressed: () async {
              final dayKey = await _pickDayKey(context);
              if (dayKey == null) return;
              if (!context.mounted) return;
              await _assignShopsForDay(context, tsaId: tsaId, dayKey: dayKey);
            },
            icon: const Icon(Icons.event_available),
            tooltip: 'Assign shops for a day',
          ),
          IconButton(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddShopChoice(context, tsaId),
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
            final docs = snapshot.data!.docs
                .where((doc) => !_isImportedShop(doc.data()))
                .toList();
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No shops found.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openAddShopChoice(context, tsaId),
                      icon: const Icon(Icons.add),
                      label: const Text('Add shop'),
                    ),
                  ],
                ),
              );
            }

            final list = ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final code = (data['code'] as String?) ?? doc.id;
                final name = (data['name'] as String?) ?? '';
                final area = (data['area'] as String?) ?? '';
                final title = '$code ${name.isEmpty ? '' : '• $name'}';

                return GlassCard(
                  onTap: () => Get.toNamed(
                    AppRoutes.seedShopDetail,
                    arguments: {
                      'tsaId': tsaId,
                      'shopId': doc.id,
                      'shopTitle': title,
                    },
                  ),
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
                          color: AppTheme.warmSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.store, color: AppTheme.warm),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (area.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                area,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.toNamed(
                          AppRoutes.seedShopDetail,
                          arguments: {
                            'tsaId': tsaId,
                            'shopId': doc.id,
                            'shopTitle': title,
                          },
                        ),
                        icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      ),
                    ],
                  ),
                );
              },
            );

            if (!kIsWeb) return list;

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
                          Icons.storefront_outlined,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TSA Shops Workspace',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${docs.length} shops linked with $tsaName',
                              style: const TextStyle(
                                color: AppTheme.mutedInk,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openAddShopChoice(context, tsaId),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Shop'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: list),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CreateShopResult {
  final String code;
  final String name;
  final String area;
  final double? lat;
  final double? lng;
  final bool filer;
  final bool discountEnabled;
  final double discountPct;
  final String? dsfId;
  final Map<String, bool> schedule;

  const _CreateShopResult({
    required this.code,
    required this.name,
    required this.area,
    this.lat,
    this.lng,
    this.filer = false,
    this.discountEnabled = true,
    this.discountPct = 0,
    this.dsfId,
    this.schedule = const {},
  });
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
