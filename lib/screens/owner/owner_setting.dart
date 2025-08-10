// lib/screens/owner/owner_setting.dart
import 'package:flutter/material.dart';

class OwnerSettingScreen extends StatelessWidget {
  const OwnerSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt chủ cửa hàng')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Cài đặt máy in'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/list-printer');
            },
          ),
          // Bạn có thể thêm các mục cài đặt khác ở đây
        ],
      ),
    );
  }
}
