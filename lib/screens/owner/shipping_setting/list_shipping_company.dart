import 'package:flutter/material.dart';

class ListShippingCompanyScreen extends StatelessWidget {
  const ListShippingCompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn hãng vận chuyển')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.local_shipping),
            title: const Text('J&T Express'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/setting-j-and-t');
            },
          ),
        ],
      ),
    );
  }
}
