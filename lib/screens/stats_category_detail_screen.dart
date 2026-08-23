import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/daos.dart';

class StatsCategoryDetailScreen extends StatelessWidget {
  final AppDatabase db;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final DateTimeRange range;
  final bool isIncome;

  const StatsCategoryDetailScreen({
    super.key,
    required this.db,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.range,
    required this.isIncome,
  });

  static const accent = Color(0xffef706d);

  String amount(int cents) => 'S/. ${(cents.abs() / 100).toStringAsFixed(2)}';

  String dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.chevron_left, size: 32, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Text(categoryIcon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              categoryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    ),
    body: StreamBuilder<List<Expense>>(
      stream: db.watchExpenses(),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <Expense>[]).where((item) {
          final date = DateTime.fromMillisecondsSinceEpoch(item.date);
          final categoryMatches =
              item.categoryId == categoryId ||
              (categoryName == 'Otro' && item.categoryId == null);
          return categoryMatches &&
              date.compareTo(range.start) >= 0 &&
              date.compareTo(range.end) <= 0 &&
              (item.amountCents >= 0) == isIncome;
        }).toList()..sort((a, b) => b.date.compareTo(a.date));

        final total = items.fold<int>(
          0,
          (sum, item) => sum + item.amountCents.abs(),
        );
        return Column(
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xffeeeeee)),
                  bottom: BorderSide(color: Color(0xffdddddd)),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    isIncome ? 'Income' : 'Expenses',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xff777777),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    amount(total),
                    style: TextStyle(
                      fontSize: 18,
                      color: isIncome ? const Color(0xff3294c0) : accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'No data available.',
                        style: TextStyle(
                          fontSize: 20,
                          color: Color(0xffa3a3a3),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xffdddddd)),
                      itemBuilder: (context, index) => _buildItem(items[index]),
                    ),
            ),
          ],
        );
      },
    ),
  );

  Widget _buildItem(Expense item) {
    final date = DateTime.fromMillisecondsSinceEpoch(item.date);
    final description = (item.description ?? item.vendor ?? '').trim();
    final account = (item.account ?? '').trim();
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              dateLabel(date),
              style: const TextStyle(fontSize: 14, color: Color(0xff858585)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description.isEmpty ? categoryName : description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xff4e4e4e),
                  ),
                ),
                if (account.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    account,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xff929292),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount(item.amountCents),
            style: TextStyle(
              fontSize: 17,
              color: isIncome ? const Color(0xff3294c0) : accent,
            ),
          ),
        ],
      ),
    );
  }
}
