import 'package:el_ahorrador/features/ledger/domain/entities.dart';

/// The four account groups of v3. Existing installs may have other group
/// names; they map by keyword, and card groups are liabilities.
enum AccountGroup {
  efectivo('Efectivo'),
  bancos('Bancos'),
  billeteras('Billeteras'),
  tarjetas('Tarjetas');

  const AccountGroup(this.label);

  final String label;

  bool get isLiability => this == tarjetas;

  static AccountGroup of(LedgerAccount a) {
    if (a.isLiability) return tarjetas;
    final text = '${a.groupName} ${a.name}'.toLowerCase();
    if (text.contains('efectivo') || text.contains('cash')) return efectivo;
    if ([
      'yape',
      'plin',
      'billetera',
      'tunki',
      'agora',
      'binance',
    ].any(text.contains)) {
      return billeteras;
    }
    if (text.contains('tarjeta') || text.contains('visa')) return tarjetas;
    return bancos;
  }
}
