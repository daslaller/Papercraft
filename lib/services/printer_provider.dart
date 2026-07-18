import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import '../models/template_model.dart';

/// A printer available for association with templates and for auto-print.
class PapercraftPrinter {
  /// Stable identifier. For local OS printers this is typically the name.
  final String id;

  /// Human-readable display name.
  final String name;

  /// `true` when discovered via the OS ([Printing.listPrinters]).
  /// `false` when provided by a host app (e.g. RepairX cloud/network printer).
  final bool isLocal;

  /// Optional host metadata (URL, driver hints, etc.).
  final Map<String, dynamic>? metadata;

  /// Underlying OS printer when [isLocal] is true.
  final Printer? osPrinter;

  const PapercraftPrinter({
    required this.id,
    required this.name,
    this.isLocal = true,
    this.metadata,
    this.osPrinter,
  });

  factory PapercraftPrinter.local(Printer printer) => PapercraftPrinter(
        id: printer.url.isNotEmpty ? printer.url : printer.name,
        name: printer.name,
        isLocal: true,
        osPrinter: printer,
      );

  factory PapercraftPrinter.external({
    required String id,
    required String name,
    Map<String, dynamic>? metadata,
  }) =>
      PapercraftPrinter(
        id: id,
        name: name,
        isLocal: false,
        metadata: metadata,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PapercraftPrinter &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Thrown when a template's associated printer cannot be resolved or used.
class PrinterUnavailableException implements Exception {
  final String? printerId;
  final String? printerName;
  final String message;

  const PrinterUnavailableException({
    this.printerId,
    this.printerName,
    this.message = 'Associated printer is unavailable',
  });

  @override
  String toString() =>
      'PrinterUnavailableException: $message'
      '${printerName != null ? ' ($printerName)' : ''}'
      '${printerId != null ? ' [$printerId]' : ''}';
}

/// Pluggable printer discovery + print execution.
///
/// The default ([LocalPrinterProvider]) uses OS printers via the `printing`
/// package. Host apps (e.g. RepairX) can register a custom provider — or a
/// [CompositePrinterProvider] that merges local + external lists.
abstract class PrinterProvider {
  /// List printers available for association / printing.
  Future<List<PapercraftPrinter>> listPrinters();

  /// Send [bytes] (PDF) to [printer].
  Future<void> printPdf(
    PapercraftPrinter printer,
    Uint8List bytes, {
    String? jobName,
  });

  /// Resolve a template's associated printer from the current list.
  /// Prefers [Template.printerId], then falls back to [Template.printerName].
  Future<PapercraftPrinter?> resolveAssociated(Template template) async {
    final printers = await listPrinters();
    return resolveFromList(template, printers);
  }

  /// Resolve against an already-fetched list.
  static PapercraftPrinter? resolveFromList(
    Template template,
    List<PapercraftPrinter> printers,
  ) {
    if (template.printerId != null) {
      final byId = printers.where((p) => p.id == template.printerId);
      if (byId.isNotEmpty) return byId.first;
    }
    if (template.printerName != null) {
      final byName = printers.where((p) => p.name == template.printerName);
      if (byName.isNotEmpty) return byName.first;
    }
    return null;
  }
}

/// Default provider — OS-discovered printers only.
class LocalPrinterProvider implements PrinterProvider {
  const LocalPrinterProvider();

  @override
  Future<List<PapercraftPrinter>> listPrinters() async {
    try {
      final list = await Printing.listPrinters();
      return list.map(PapercraftPrinter.local).toList();
    } catch (e, st) {
      debugPrint('LocalPrinterProvider.listPrinters failed: $e\n$st');
      return [];
    }
  }

  @override
  Future<void> printPdf(
    PapercraftPrinter printer,
    Uint8List bytes, {
    String? jobName,
  }) async {
    final os = printer.osPrinter;
    if (os == null) {
      throw PrinterUnavailableException(
        printerId: printer.id,
        printerName: printer.name,
        message: 'Local printer handle is missing',
      );
    }
    final ok = await Printing.directPrintPdf(
      printer: os,
      name: jobName ?? 'Papercraft',
      onLayout: (_) async => bytes,
    );
    if (!ok) {
      throw PrinterUnavailableException(
        printerId: printer.id,
        printerName: printer.name,
        message: 'Direct print failed',
      );
    }
  }

  @override
  Future<PapercraftPrinter?> resolveAssociated(Template template) async {
    final printers = await listPrinters();
    return PrinterProvider.resolveFromList(template, printers);
  }
}

/// Merges multiple providers (e.g. local OS + RepairX network printers).
class CompositePrinterProvider implements PrinterProvider {
  final List<PrinterProvider> providers;

  const CompositePrinterProvider(this.providers);

  @override
  Future<List<PapercraftPrinter>> listPrinters() async {
    final seen = <String>{};
    final out = <PapercraftPrinter>[];
    for (final p in providers) {
      for (final printer in await p.listPrinters()) {
        if (seen.add(printer.id)) out.add(printer);
      }
    }
    return out;
  }

  @override
  Future<void> printPdf(
    PapercraftPrinter printer,
    Uint8List bytes, {
    String? jobName,
  }) async {
    // Prefer the provider that listed this printer; try each until one succeeds.
    Object? lastError;
    for (final p in providers) {
      try {
        final list = await p.listPrinters();
        if (list.any((x) => x.id == printer.id)) {
          await p.printPdf(printer, bytes, jobName: jobName);
          return;
        }
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) {
      throw lastError;
    }
    throw PrinterUnavailableException(
      printerId: printer.id,
      printerName: printer.name,
      message: 'No provider could print to this printer',
    );
  }

  @override
  Future<PapercraftPrinter?> resolveAssociated(Template template) async {
    final printers = await listPrinters();
    return PrinterProvider.resolveFromList(template, printers);
  }
}

/// Host-supplied static list of external printers.
///
/// Print execution must be provided via [onPrintPdf]; if omitted, printing
/// throws [PrinterUnavailableException].
class ExternalPrinterProvider implements PrinterProvider {
  final Future<List<PapercraftPrinter>> Function() list;
  final Future<void> Function(
    PapercraftPrinter printer,
    Uint8List bytes, {
    String? jobName,
  })? onPrintPdf;

  ExternalPrinterProvider({
    required this.list,
    this.onPrintPdf,
  });

  @override
  Future<List<PapercraftPrinter>> listPrinters() => list();

  @override
  Future<void> printPdf(
    PapercraftPrinter printer,
    Uint8List bytes, {
    String? jobName,
  }) async {
    final handler = onPrintPdf;
    if (handler == null) {
      throw PrinterUnavailableException(
        printerId: printer.id,
        printerName: printer.name,
        message: 'External printer has no print handler',
      );
    }
    await handler(printer, bytes, jobName: jobName);
  }

  @override
  Future<PapercraftPrinter?> resolveAssociated(Template template) async {
    final printers = await listPrinters();
    return PrinterProvider.resolveFromList(template, printers);
  }
}

/// Global printer registry.
///
/// ```dart
/// PrinterRegistry.register(CompositePrinterProvider([
///   const LocalPrinterProvider(),
///   ExternalPrinterProvider(list: () async => repairXPrinters),
/// ]));
/// ```
class PrinterRegistry {
  PrinterRegistry._();

  static PrinterProvider _active = const LocalPrinterProvider();

  static PrinterProvider get active => _active;

  static void register(PrinterProvider provider) => _active = provider;

  /// Reset to the default local OS provider (useful in tests).
  static void reset() => _active = const LocalPrinterProvider();
}
