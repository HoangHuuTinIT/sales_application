import 'package:ban_hang/services/owner_services/facebook_page_service.dart';
import 'package:flutter/material.dart';


class ChoseFacebookPageScreen extends StatefulWidget {
  const ChoseFacebookPageScreen({super.key});

  @override
  State<ChoseFacebookPageScreen> createState() => _ChoseFacebookPageScreenState();
}

class _ChoseFacebookPageScreenState extends State<ChoseFacebookPageScreen> {
  List<Map<String, dynamic>> pages = [];
  Map<String, dynamic>? fbAccount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    print("===> Facebook Page Screen arguments: $rawArgs"); // <- thêm dòng này

    fbAccount = rawArgs as Map<String, dynamic>?;
    if (fbAccount != null) {
      print("===> fbAccount: $fbAccount"); // <- và dòng này
      _loadPages();
    } else {
      print("===> fbAccount is null");
    }
  }


  Future<void> _loadPages() async {
    final result = await FacebookPageService().getPages(fbAccount!['accessToken']);
    setState(() {
      pages = result.where((p) => p['access_token'] != null).toList(); // bỏ page không hợp lệ
    });

  }

  void _confirmPage(Map<String, dynamic> pageData) {
    final nameController = TextEditingController(text: pageData['name']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xác nhận"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Lưu kênh Facebook này thành 1 kênh bán hàng"),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Tên hiển thị"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FacebookPageService().savePageToFirestore(
                fbUserId: fbAccount!['fbUserId'], // đổi từ uid → fbUserId
                pageData: pageData,
                displayName: nameController.text,
              );
              Navigator.pop(context); // đóng dialog
              Navigator.pop(context, true); // thoát màn và gửi tín hiệu
            },
            child: const Text("Xác nhận"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chọn fanpage")),
      body: pages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          return Card(
            child: ListTile(
              title: Text(page['name']),
              subtitle: Text("ID: ${page['id']}"),
              trailing: ElevatedButton(
                onPressed: () => _confirmPage(page),
                child: const Text("Chọn"),
              ),
            ),
          );
        },
      ),
    );
  }
}
