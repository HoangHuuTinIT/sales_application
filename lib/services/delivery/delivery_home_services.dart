import 'package:flutter/material.dart';
import 'package:ban_hang/screens/delivery/packaged_product.dart';
import 'package:ban_hang/screens/delivery/delivery_products.dart';

class DeliveryHomeServices {
  void goToPackagedProducts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PackagedProductScreen()),
    );
  }

  void goToDeliveryProducts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeliveryProductsScreen()),
    );
  }
}
