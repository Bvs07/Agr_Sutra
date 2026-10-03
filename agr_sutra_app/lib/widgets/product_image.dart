import 'package:flutter/material.dart';
 
class ProductImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const ProductImage({super.key, required this.url, this.fit = BoxFit.cover});
 
  @override
  Widget build(BuildContext context) {
    final address = url;
    if (address == null) {
      return const Center(child: Icon(Icons.image_not_supported));
    }
    return Image.network(
      address,
      fit: fit,
      errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image)),
    );
  }
}