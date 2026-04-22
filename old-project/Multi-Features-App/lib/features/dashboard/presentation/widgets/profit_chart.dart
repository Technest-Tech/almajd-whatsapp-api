import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfitChart extends StatelessWidget {
  final Map<String, dynamic> profitByCurrency;

  const ProfitChart({super.key, required this.profitByCurrency});

  @override
  Widget build(BuildContext context) {
    if (profitByCurrency.isEmpty) {
      return Card(
        elevation: 2,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 48,
                  color: Theme.of(context).hintColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد بيانات ربح متاحة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final entries = profitByCurrency.entries.toList();
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الربح حسب العملة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: List.generate(
                    entries.length,
                    (index) {
                      final entry = entries[index];
                      final total = profitByCurrency.values
                          .map((v) => (v as num).toDouble())
                          .reduce((a, b) => a + b);
                      final percentage = ((entry.value as num).toDouble() / total) * 100;

                      return PieChartSectionData(
                        value: (entry.value as num).toDouble(),
                        title: '${entry.key}\n${percentage.toStringAsFixed(1)}%',
                        color: colors[index % colors.length],
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: entries.asMap().entries.map((entry) {
                final index = entry.key;
                final currencyEntry = entry.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${currencyEntry.key}: ${(currencyEntry.value as num).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

