import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/user_role.dart';
import '../../core/services/session/session_service.dart';

class LoggedInNameText extends StatefulWidget {
  final String prefix;
  final String fallback;
  final TextStyle? style;

  const LoggedInNameText({
    super.key,
    this.prefix = '',
    this.fallback = 'User',
    this.style,
  });

  @override
  State<LoggedInNameText> createState() => _LoggedInNameTextState();
}

class _LoggedInNameTextState extends State<LoggedInNameText> {
  late final Future<String> _nameFuture;

  @override
  void initState() {
    super.initState();
    _nameFuture = _resolveName();
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return '${input[0].toUpperCase()}${input.substring(1)}';
  }

  String _nameFromEmail(String? email) {
    final localPart = (email ?? '').split('@').first.trim();
    if (localPart.isEmpty) return '';
    final parts = localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) => _capitalize(part.trim()))
        .toList();
    if (parts.isEmpty) return '';
    return parts.join(' ');
  }

  Future<String> _resolveDsfName(String uid) async {
    final col = FirebaseFirestore.instance.collection('dsfAccounts');

    final directDoc = await col.doc(uid).get();
    final directName = (directDoc.data()?['name'] as String?)?.trim();
    if (directName != null && directName.isNotEmpty) {
      return directName;
    }

    final byUid = await col.where('uid', isEqualTo: uid).limit(1).get();
    if (byUid.docs.isNotEmpty) {
      final mappedName = (byUid.docs.first.data()['name'] as String?)?.trim();
      if (mappedName != null && mappedName.isNotEmpty) {
        return mappedName;
      }
    }

    return '';
  }

  Future<String> _resolveDistributorName(String distributorId) async {
    if (distributorId.trim().isEmpty) return '';
    final doc = await FirebaseFirestore.instance
        .collection('distributors')
        .doc(distributorId)
        .get();
    final name = (doc.data()?['name'] as String?)?.trim();
    return name ?? '';
  }

  Future<String> _resolveName() async {
    final authUser = FirebaseAuth.instance.currentUser;
    final authDisplayName = (authUser?.displayName ?? '').trim();
    final authEmailName = _nameFromEmail(authUser?.email);

    if (authDisplayName.isNotEmpty) {
      return authDisplayName;
    }

    final session = Get.find<SessionService>();
    final profile = session.profile;
    if (profile == null) {
      return authEmailName;
    }

    try {
      switch (profile.role) {
        case UserRole.admin:
          return authEmailName;
        case UserRole.dsf:
          final dsfName = await _resolveDsfName(profile.uid);
          if (dsfName.isNotEmpty) return dsfName;
          return authEmailName;
        case UserRole.distributor:
          final distributorName = await _resolveDistributorName(
            profile.distributorId,
          );
          if (distributorName.isNotEmpty) return distributorName;
          return authEmailName;
      }
    } catch (_) {
      return authEmailName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _nameFuture,
      builder: (context, snapshot) {
        final resolved = (snapshot.data ?? '').trim();
        final name = resolved.isEmpty ? widget.fallback : resolved;
        return Text(
          '${widget.prefix}$name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        );
      },
    );
  }
}
