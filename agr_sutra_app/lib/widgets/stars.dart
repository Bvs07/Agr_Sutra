import 'package:flutter/material.dart';
 
/// Shows a rating like ★★★★☆ 4.2 (12).
class StarDisplay extends StatelessWidget {
  final double rating;
  final int? count;
  final double size;
  const StarDisplay({super.key, required this.rating, this.count, this.size = 16});
 
  @override
  Widget build(BuildContext context) {
    final stars = <Widget>[];
    for (var i = 1; i <= 5; i++) {
      IconData icon;
      if (rating >= i) {
        icon = Icons.star;
      } else if (rating >= i - 0.5) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
      stars.add(Icon(icon, size: size, color: Colors.amber.shade700));
    }
    final label = count == null
        ? ''
        : (count == 0 ? ' No ratings yet' : ' ${rating.toStringAsFixed(1)} ($count)');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...stars,
        if (label.isNotEmpty)
          Text(label, style: TextStyle(fontSize: size * 0.8)),
      ],
    );
  }
}
 
/// Five tappable stars.
class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const StarPicker({super.key, required this.value, required this.onChanged});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final n = i + 1;
        return IconButton(
          onPressed: () => onChanged(n),
          icon: Icon(n <= value ? Icons.star : Icons.star_border,
              color: Colors.amber.shade700, size: 34),
        );
      }),
    );
  }
}