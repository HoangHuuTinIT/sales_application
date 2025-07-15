import 'package:ban_hang/firebase_options.dart';
import 'package:ban_hang/screens/customer/CustomerAccountInformationScreen.dart';
import 'package:ban_hang/screens/customer/customer_order.dart';
import 'package:ban_hang/screens/customer/home_customer.dart';
import 'package:ban_hang/screens/customer/buy_products.dart';
import 'package:ban_hang/screens/customer/cartitems_screen.dart';
import 'package:ban_hang/screens/customer/product_customer_chose.dart';
import 'package:ban_hang/screens/customer/purchased_products.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/fixdart.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quân đoàn mua sắm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFE3F2FD),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      routes: {
        '/ordered_products': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return BuyProductsScreen(
            selectedItems: args['selectedItems'],
          );
        },
        '/product_detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ProductCustomerChoseScreen(productId: args['productId']);
        },
        '/cart': (_) => const CartItemsScreen(),
        '/my_orders': (_) => const CustomerOrderScreen(),
        '/purchased_products': (_) => const PurchasedProductsScreen(),
        '/customer_account_information': (_) => const CustomerAccountInformationScreen(),
      },
      home: const HomeCustomer(),
    );

  }
  // fix.dart


}
