import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../providers/cart_provider.dart';
import '../../widgets/product_image.dart';
import 'checkout_screen.dart';
 
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    if (cart.isEmpty) {
      return const Center(
          child: Text('Your cart is empty.\nBrowse the Marketplace to add crafts.',
              textAlign: TextAlign.center));
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final item in cart.items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                              width: 70,
                              height: 70,
                              child: ProductImage(url: item.product.fullImageUrl)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('₹${item.product.price} each'),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => cart.setQuantity(
                                        item.product.productId,
                                        item.quantity - 1),
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text('${item.quantity}'),
                                  IconButton(
                                    onPressed: () => cart.setQuantity(
                                        item.product.productId,
                                        item.quantity + 1),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                  const Spacer(),
                                  Text('₹${item.subtotal}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => cart.remove(item.product.productId),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text('Total: ₹${cart.total}',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        CheckoutScreen(items: cart.items, fromCart: true),
                  )),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text('Checkout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}