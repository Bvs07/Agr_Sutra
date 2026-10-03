import 'package:flutter/material.dart';
 
Color statusColor(String status) {
  switch (status) {
    case 'New':
      return Colors.blue;
    case 'Processing':
      return Colors.orange;
    case 'Completed':
      return Colors.green;
    case 'Cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
 
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});
 
  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}