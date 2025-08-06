import 'package:ban_hang/screens/staff/shipping_company_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ShippingCompanyScreen extends StatelessWidget {
  const ShippingCompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn đơn vị vận chuyển'),
        backgroundColor: Colors.deepOrange,
      ),
      body: ListTile(
        leading: const Icon(Icons.local_shipping),
        title: const Text('Viettel Post'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShippingCompanySettingsScreen()),
          );
        },
      ),
    );
  }
}
