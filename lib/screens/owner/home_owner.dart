import 'package:ban_hang/screens/auth/signin.dart';
import 'package:ban_hang/screens/staff/order_management.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/screens/staff/categories_management.dart';
import 'package:ban_hang/screens/staff/product_management.dart';
import 'package:ban_hang/screens/staff/statistics_screen.dart';
import 'account_management/approval_account.dart';
import 'create_order/chose_customer_for_order.dart';


class HomeOwnerScreen extends StatelessWidget {
  const HomeOwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ chủ cửa hàng'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                      (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Text('Đăng xuất'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildSection(
                  context,
                  icon: Icons.inventory,
                  title: 'Quản lý sản phẩm',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ProductManagementScreen(),
                    ));
                  },
                ),
                _buildSection(
                  context,
                  icon: Icons.category,
                  title: 'Quản lý loại sản phẩm',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const CategoriesManagementScreen(),
                    ));
                  },
                ),
                _buildSection(
                  context,
                  icon: Icons.bar_chart,
                  title: 'Quản lý doanh thu',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const StatisticsScreen(),
                    ));
                  },
                ),
                _buildSection(
                  context,
                  icon: Icons.facebook,
                  title: 'Bán hàng Facebook',
                  onTap: () {
                    Navigator.pushNamed(context, '/facebook-sales');
                  },
                ),
                _buildSection(
                  context,
                  icon: Icons.manage_accounts,
                  title: 'Quản lý tài khoản',
                  onTap: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.check_circle),
                          title: const Text('Xét duyệt tài khoản'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ApprovalAccountScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Chỉnh sửa tài khoản'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/edit-accounts');
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_add),
                          title: const Text('Cấp tài khoản quản lý'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/create-management-account');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                _buildSection(
                  context,
                  icon: Icons.receipt_long,
                  title: 'Tạo hóa đơn bán hàng',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChoseCustomerForOrderScreen(),
                      ),
                    );
                  },
                ),
                // 🔹 Thêm mục mới "Đơn đặt hàng"
                _buildSection(
                  context,
                  icon: Icons.shopping_cart,
                  title: 'Đơn đặt hàng',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrderManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildSection(
                  context,
                  icon: Icons.settings,
                  title: 'Cài đặt',
                  onTap: () {
                    Navigator.pushNamed(context, '/owner-setting');
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context,
      {required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ListTile(
        leading: Icon(icon, size: 32, color: Colors.indigo),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
