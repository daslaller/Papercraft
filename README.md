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

See **[WIDGET_API.md](WIDGET_API.md)** for the full embedding, storage, printer, headless print/render, token contract, line-items table, and the row/col DSL used to author RepairX's seven default templates (`kRepairXDefaultTemplates`).

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

Mirrors RepairX's own split: **Anchor** is the colour scheme
(`lib/theme/app_colors.dart` — slate neutrals, blue-600 accent), **Rail** is
the component geometry (`lib/theme/app_tokens.dart` — spacing/radius scale,
type ramp; `lib/theme/app_theme.dart` builds `ThemeData` from both). Rail
replaced Papercraft's original serif-headline treatment with a single tight
Inter ramp, thinner borders, and flatter elevation (a hairline border plus a
shadow you have to look for, not Material elevation). Shared chrome
primitives — the uppercase field label, the sentence-case section label, the
tinted status badge — live in `lib/widgets/common/paper_chrome.dart`
(`PaperFieldLabel` / `PaperSectionLabel` / `PaperBadge`); use these instead
of a new inline `TextStyle` copy. Prefer all of the above over hardcoded
colors, spacing, or radii. Dark mode from older specs is deferred.
