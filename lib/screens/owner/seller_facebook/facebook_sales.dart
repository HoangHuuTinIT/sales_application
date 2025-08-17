
import 'package:ban_hang/services/owner_services/facebook_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FacebookSalesScreen extends StatefulWidget {
  const FacebookSalesScreen({super.key});

  @override
  State<FacebookSalesScreen> createState() => _FacebookSalesScreenState();
}

class _FacebookSalesScreenState extends State<FacebookSalesScreen> {
  List<Map<String, dynamic>> accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    print("====> Reloading accounts");
    final rawAccounts = await FacebookAuthService().loadConnectedAccounts();
    accounts = await Future.wait(rawAccounts.map((account) async {
      print("Account11111: ${account['name']}, connected1111: ${account['connected']}");
      if (account['connected'] == true) {
        final future = _getConnectedPages(account['fbUserId']);
        account['pagesFuture'] = future;
        print("Set future for ${account['fbUserId']}");
      }
      return account;
    }));
    setState(() {});

  }


  void _showConnectDialog(Map<String, dynamic> account) {
    final nameController = TextEditingController(text: account['name']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Lưu kênh Facebook này thành 1 kênh bán hàng"),
            const SizedBox(height: 8),
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
              await FacebookAuthService().connectAccount(account['fbUserId'], nameController.text);
              Navigator.pop(context);
              _loadAccounts();
            },
            child: const Text("Xác nhận"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = accounts.where((e) => e['connected'] == true).toList();
    final notConnected = accounts.where((e) => e['connected'] == false).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Bán hàng Facebook")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ElevatedButton(
            onPressed: () async {
              await FacebookAuthService().signInWithFacebook(context);
              _loadAccounts();
            },
            child: const Text("Đăng nhập Facebook"),
          ),
          const SizedBox(height: 20),
          if (notConnected.isNotEmpty)
            const Text("Tài khoản đã đăng nhập", style: TextStyle(fontWeight: FontWeight.bold)),
          ...notConnected.map((account) => Card(
            child: ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(account['picture'])),
              title: Text(account['name']),
              trailing: Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => _showConnectDialog(account),
                    child: const Text("Kết nối"),
                  ),
                  TextButton(
                    onPressed: () async {
                      await FacebookAuthService().logout(account['fbUserId']);
                      _loadAccounts();
                    },
                    child: const Text("Đăng xuất"),
                  ),
                ],
              ),
            ),
          )),
          const SizedBox(height: 20),
          if (connected.isNotEmpty)
            const Text("Kênh đã kết nối", style: TextStyle(fontWeight: FontWeight.bold)),

          ...connected.map((account) => FutureBuilder<List<Map<String, dynamic>>>(
            future: account['pagesFuture'],
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text("Lỗi: ${snapshot.error}");
              }
              final pages = snapshot.data ?? [];
              return Card(
                child: ExpansionTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(account['picture'])),
                  title: Text(account['name']),
                  subtitle: const Text("Kênh đã kết nối"),
                  trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'add_page') {
                          final result = await Navigator.pushNamed(context, '/chose-facebook-page', arguments: account);
                          if (result == true) {
                            _loadAccounts(); // Chỉ load lại nếu thực sự có thêm
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'add_page',
                        child: Text("Thêm trang mới"),
                      ),
                    ],
                  ),
                  children: pages.map((page) => ListTile(
                    title: Text(page['name']),
                    subtitle: Text("Page ID: ${page['pageId']}"),
                    onTap: () {
                      Navigator.pushNamed(context, '/list-livestreams', arguments: page);
                    },
                  )).toList(),
                ),
              );
            },
          )),
        ],
      ),

    );
  }Future<List<Map<String, dynamic>>> _getConnectedPages(String fbUserId) async {
    print("===> Loading connected pages for: $fbUserId");
    final snapshot = await FirebaseFirestore.instance
        .collection('page_facebook_live')
        .where('fbUserId', isEqualTo: fbUserId)
        .get();
    print("===> fbUserId: $fbUserId (${fbUserId.runtimeType})");
    print("===> Found ${snapshot.docs.length} pages for user: $fbUserId Id");
    snapshot.docs.forEach((doc) {
      print("Page Data: ${doc.data()}");
    });
    return snapshot.docs.map((doc) => doc.data()).toList();
  }


}
