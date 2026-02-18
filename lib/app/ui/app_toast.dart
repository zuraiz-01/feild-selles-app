import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

class AppToast {
  static void success(String title, {String? message}) {
    _show(title, message: message, type: ToastificationType.success);
  }

  static void info(String title, {String? message}) {
    _show(title, message: message, type: ToastificationType.info);
  }

  static void warning(String title, {String? message}) {
    _show(title, message: message, type: ToastificationType.warning);
  }

  static void error(String title, {String? message}) {
    _show(title, message: message, type: ToastificationType.error);
  }

  static void _show(
    String title, {
    String? message,
    required ToastificationType type,
  }) {
    final context = Get.context;
    if (context == null) {
      return;
    }

    final trimmedTitle = title.trim();
    final trimmedMessage = message?.trim();
    if (trimmedTitle.isEmpty) return;

    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flatColored,
      alignment: kIsWeb ? Alignment.topRight : Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: true,
      dragToClose: true,
      pauseOnHover: true,
      title: Text(trimmedTitle),
      description: (trimmedMessage != null && trimmedMessage.isNotEmpty)
          ? Text(trimmedMessage)
          : null,
    );
  }
}
