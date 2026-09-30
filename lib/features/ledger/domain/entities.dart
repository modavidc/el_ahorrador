/// Ledger entities: what the screens and use cases work with, independent
/// of how they are stored.
library;

enum MovementType { income, expense, transfer }

/// How a movement entered the app; every origin but [manual] shows its label
/// next to the row ("Compartido", "Captura", "Boleta", "Voz").
enum MovementOrigin {
  manual(null),
  shared('Compartido'),
  screenshot('Captura'),
  receipt('Boleta'),
  voice('Voz');

  const MovementOrigin(this.label);

  final String? label;

  /// Value stored in `captures.meta_json` → `origin`.
  String get key => name;

  static MovementOrigin fromKey(String? key) =>
      values.where((o) => o.key == key).firstOrNull ?? shared;
}

/// One row of the ledger: an income, an expense, or a transfer shown once.
/// What a payment receipt says about the other side, kept with the
/// movement it created (not shown yet; for "who did I pay most").
final class PaymentDetails {
  const PaymentDetails({
    this.counterpart,
    this.counterpartPhone,
    this.message,
    this.operation,
  });

  /// Person or merchant paid ("Andrez Qui").
  final String? counterpart;

  /// Last 3 digits of their phone ("281").
  final String? counterpartPhone;

  /// What was written with the payment ("pasaje bus").
  final String? message;

  /// Operation number of the receipt.
  final String? operation;

  bool get isEmpty =>
      counterpart == null &&
      counterpartPhone == null &&
      message == null &&
      operation == null;
}

final class Movement {
  const Movement({
    required this.id,
    required this.at,
    required this.type,
    required this.category,
    required this.subcategory,
    required this.note,
    required this.account,
    required this.amountCents,
    this.toAccount,
    this.method,
    this.ocrPercent,
    this.origin = MovementOrigin.manual,
    this.details = const PaymentDetails(),
  });

  final String id;
  final DateTime at;
  final MovementType type;
  final String category;
  final String subcategory;
  final String note;
  final String account;
  final String? toAccount;

  /// Always positive; [type] carries the direction.
  final int amountCents;

  /// Payment app shown as a chip ("Yape").
  final String? method;

  /// OCR confidence of the capture that created the movement.
  final int? ocrPercent;

  final MovementOrigin origin;

  /// Recipient, phone, message and operation of the receipt it came from.
  final PaymentDetails details;

  double get amount => amountCents / 100;

  DateTime get day => DateTime(at.year, at.month, at.day);
}

/// Account with its group and computed balance (starting balance plus every
/// movement, transfers included).
final class LedgerAccount {
  const LedgerAccount({
    required this.id,
    required this.name,
    required this.groupId,
    required this.groupName,
    required this.isLiability,
    required this.balanceCents,
    required this.order,
    this.description,
    this.creditLimitCents,
    this.isDefault = false,
    this.isHidden = false,
  });

  final String id;
  final String name;

  /// The account manual entries and unmatched captures fall back to.
  final bool isDefault;

  /// Hidden accounts do not add to the totals of Cuentas.
  final bool isHidden;
  final String? groupId;
  final String groupName;
  final bool isLiability;
  final int balanceCents;
  final int order;
  final String? description;
  final int? creditLimitCents;
}
