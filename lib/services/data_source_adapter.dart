/// Pluggable data-source adapter for the left-sidebar record picker.
///
/// Implement [DataSourceAdapter] and call [AdapterRegistry.register] to replace
/// the built-in mock with a real back-end (Appwrite, Firestore, REST, etc.).
library;

// ── Value types ───────────────────────────────────────────────────────────────

/// A single preview record with a human-readable label and a FLAT field map.
/// Flat keys follow the token convention: "product.name", "customer.email".
class DataRecord {
  final String displayName;
  final String subtitle;

  /// Flat key → value map. Keys must match template tokens exactly.
  final Map<String, dynamic> flat;

  const DataRecord({
    required this.displayName,
    required this.subtitle,
    required this.flat,
  });
}

// ── Adapter contract ──────────────────────────────────────────────────────────

abstract class DataSourceAdapter {
  /// Short machine-readable identifier, e.g. "mock", "appwrite", "firestore".
  String get id;

  /// Human-readable name shown in the UI.
  String get displayName;

  /// Returns the list of entity/collection names available on this source.
  Future<List<String>> listEntities();

  /// Fetches up to [limit] preview records for the given [entity].
  Future<List<DataRecord>> fetchRecords(String entity, {int limit = 10});
}

// ── Registry ──────────────────────────────────────────────────────────────────

class AdapterRegistry {
  AdapterRegistry._();

  static DataSourceAdapter _active = MockDataAdapter();

  static DataSourceAdapter get active => _active;

  /// Replace the active adapter. Call this at startup or in settings.
  static void register(DataSourceAdapter adapter) => _active = adapter;
}

// ── Mock adapter (default) ────────────────────────────────────────────────────

class MockDataAdapter implements DataSourceAdapter {
  @override
  String get id => 'mock';

  @override
  String get displayName => 'Sample Data';

  @override
  Future<List<String>> listEntities() async => ['orders', 'products', 'customers'];

  @override
  Future<List<DataRecord>> fetchRecords(String entity, {int limit = 10}) async {
    return _kMockRecords.take(limit).toList();
  }
}

// ── Stub adapters users can extend ───────────────────────────────────────────

/// Extend this and implement [fetchRecords] to wire up Appwrite.
/// Register with: AdapterRegistry.register(MyAppwriteAdapter());
abstract class AppwriteAdapterBase implements DataSourceAdapter {
  @override
  String get id => 'appwrite';

  @override
  String get displayName => 'Appwrite';
}

/// Extend this and implement [fetchRecords] to wire up Firestore.
abstract class FirestoreAdapterBase implements DataSourceAdapter {
  @override
  String get id => 'firestore';

  @override
  String get displayName => 'Firestore';
}

// ── Built-in mock data (mirrors _kMockRecords in left_sidebar.dart) ───────────

final _kMockRecords = [
  DataRecord(
    displayName: 'Aurora Lamp',
    subtitle: 'sku LMP-204',
    flat: {
      'product.name': 'Aurora Lamp',
      'product.description': 'Elegant ceramic floor lamp',
      'product.price': r'$48.00',
      'product.sku': 'LMP-204',
      'product.category': 'Lighting',
      'customer.name': 'Sophie Chen',
      'customer.company': 'Nordic Home',
      'customer.email': 'sophie@nordichome.com',
      'customer.phone': '+1 555-0201',
      'customer.address': '8 Birch Lane',
      'customer.city': 'Austin, TX 78701',
      'customer.zip': '78701',
      'order.number': 'INV-1856',
      'order.date': 'Jun 12, 2026',
      'order.quantity': '3',
      'order.subtotal': r'$144.00',
      'order.tax': r'$11.52',
      'order.total': r'$155.52',
      'order.status': 'Pending',
    },
  ),
  DataRecord(
    displayName: 'Field Notebook',
    subtitle: 'sku NB-011',
    flat: {
      'product.name': 'Field Notebook',
      'product.description': 'Hardcover ruled notebook',
      'product.price': r'$24.00',
      'product.sku': 'NB-011',
      'product.category': 'Stationery',
      'customer.name': 'Marcus Lee',
      'customer.company': 'Lumen Studio',
      'customer.email': 'marcus@lumenstudio.com',
      'customer.phone': '+1 555-0102',
      'customer.address': '14 Pearl Street',
      'customer.city': 'Brooklyn, NY 11201',
      'customer.zip': '11201',
      'order.number': 'INV-2042',
      'order.date': 'Jun 19, 2026',
      'order.quantity': '5',
      'order.subtotal': r'$120.00',
      'order.tax': r'$9.60',
      'order.total': r'$1,280.30',
      'order.status': 'Shipped',
    },
  ),
  DataRecord(
    displayName: 'Cedar Candle',
    subtitle: 'sku CC-033',
    flat: {
      'product.name': 'Cedar Candle',
      'product.description': 'Hand-poured soy candle',
      'product.price': r'$18.00',
      'product.sku': 'CC-033',
      'product.category': 'Home Decor',
      'customer.name': 'Jordan Park',
      'customer.company': 'Acme Corp',
      'customer.email': 'jordan@acme.com',
      'customer.phone': '+1 555-0303',
      'customer.address': '22 Maple Ave',
      'customer.city': 'Seattle, WA 98101',
      'customer.zip': '98101',
      'order.number': 'INV-2156',
      'order.date': 'Jun 21, 2026',
      'order.quantity': '10',
      'order.subtotal': r'$180.00',
      'order.tax': r'$14.40',
      'order.total': r'$194.40',
      'order.status': 'Processing',
    },
  ),
];
