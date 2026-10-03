import 'package:flutter/material.dart';
 
/// A simple horizontal bar chart: one row per item.
class BarList extends StatelessWidget {
  final List<MapEntry<String, int>> items;
  final String prefix;
  const BarList({super.key, required this.items, this.prefix = ''});
 
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No data yet.');
    var maxValue = 0;
    for (final i in items) {
      if (i.value > maxValue) maxValue = i.value;
    }
    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(i.key,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('$prefix${i.value}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxValue <= 0 ? 0 : i.value / maxValue,
                    minHeight: 10,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}