# Papercraft

Flutter label and document template designer — embeddable as a package for host apps such as RepairX.

## Use as a package

```yaml
# your_app/pubspec.yaml
dependencies:
  papercraft:
    path: ../papercraft
```

```dart
import 'package:papercraft/papercraft.dart';

void main() {
  // Optional: persist templates in your backend
  StorageRegistry.register(MyTemplateStorage());

  // Optional: merge OS printers with host-managed printers
  PrinterRegistry.register(CompositePrinterProvider([
    const LocalPrinterProvider(),
    ExternalPrinterProvider(list: () async => myCloudPrinters),
  ]));

  // Optional: live records for the data sidebar
  AdapterRegistry.register(MyDataAdapter());

  runApp(MyApp());
}
```

See **[WIDGET_API.md](WIDGET_API.md)** for the full embedding, storage, printer, headless print/render, and token contract.

## Standalone app

```bash
flutter pub get
flutter run -d chrome   # or windows / your device
```

Dev entry (skips login, seeds a sample template):

```bash
flutter run -t lib/main_dev.dart
```

## Design system

Light UI tokens live in `lib/theme/app_colors.dart` and `lib/theme/app_theme.dart`. Prefer these over hardcoded colors. Dark mode from older specs is deferred.
