import 'package:flutter/material.dart';
 
import 'stars.dart';
 
class ReviewInput {
  final int rating;
  final String comment;
  ReviewInput(this.rating, this.comment);
}
 
/// Asks for a 1-5 star rating and an optional comment. Returns null if cancelled.
Future<ReviewInput?> showReviewDialog(BuildContext context, String title) {
  final controller = TextEditingController();
  var rating = 5;
  return showDialog<ReviewInput>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StarPicker(value: rating, onChanged: (v) => setState(() => rating = v)),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: 'Comment (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, ReviewInput(rating, controller.text.trim())),
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
}