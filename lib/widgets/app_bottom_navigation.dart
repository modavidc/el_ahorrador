import 'package:flutter/material.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const destinations = [
    (Icons.article_outlined, 'Trans.'),
    (Icons.bar_chart_outlined, 'Stats'),
    (Icons.storage_rounded, 'Accounts'),
    (Icons.more_horiz, 'More'),
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xfffbf9fd),
    elevation: 3,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: List.generate(destinations.length, (index) {
            final destination = destinations[index];
            final selected = index == currentIndex;
            final color = selected
                ? const Color(0xffd65f5d)
                : const Color(0xff929292);
            return Expanded(
              child: Semantics(
                selected: selected,
                button: true,
                label: destination.$2,
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(destination.$1, size: 24, color: color),
                      const SizedBox(height: 2),
                      Text(
                        destination.$2,
                        style: TextStyle(fontSize: 11, color: color),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
