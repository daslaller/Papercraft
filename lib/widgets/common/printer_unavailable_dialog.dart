import 'package:flutter/material.dart';

import '../../services/printer_provider.dart';
import '../../theme/app_colors.dart';

/// Shows a themed dialog explaining that the template's associated printer
/// could not be resolved (e.g. a local printer not present on this machine).
Future<void> showPrinterUnavailableDialog(
  BuildContext context,
  PrinterUnavailableException error,
) {
  final label = error.printerName ?? error.printerId ?? 'the associated printer';
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Printer unavailable',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.foreground,
        ),
      ),
      content: Text(
        'Cannot print — $label is not available on this device.\n\n'
        '${error.message}',
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.foregroundSecond,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
