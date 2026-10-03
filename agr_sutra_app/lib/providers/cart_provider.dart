import 'dart:math' as math;
 
import 'package:flutter/foundation.dart';
 
import '../models/product.dart';
 
class CartItem {
  final Product product;
  int quantity;
  CartItem(this.product, this.quantity);
 
  int get subtotal => product.price * quantity;
}
 
class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
 
  List<CartItem> get items => _items.values.toList();
  bool get isEmpty => _items.isEmpty;
  int get count => _items.values.fold(0, (sum, i) => sum + i.quantity);
  int get total => _items.values.fold(0, (sum, i) => sum + i.subtotal);
 
  void add(Product product, int quantity) {
    if (product.stock <= 0) return;
    final current = _items[product.productId]?.quantity ?? 0;
    final next = math.min(current + quantity, product.stock);
    _items[product.productId] = CartItem(product, next);
    notifyListeners();
  }
 
  void setQuantity(String productId, int quantity) {
    final item = _items[productId];
    if (item == null) return;
    item.quantity = math.max(1, math.min(quantity, item.product.stock));
    notifyListeners();
  }
 
  void remove(String productId) {
    _items.remove(productId);
    notifyListeners();
  }
 
  void clear() {
    _items.clear();
    notifyListeners();
  }
}