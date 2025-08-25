// lib/screens/owner/create_order_for_customer.dart
import 'dart:async';
import 'package:ban_hang/screens/owner/create_order/setting_shipping_company_for_order.dart';
import 'package:ban_hang/screens/owner/home_owner.dart';
import 'package:ban_hang/services/owner_services/customer_order_service.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_customer_for_order.dart';
import 'edit_address_for_order.dart';

class CreateOrderForCustomerScreen extends StatefulWidget {
  final Map<String, dynamic> customerData;
  const CreateOrderForCustomerScreen({super.key, required this.customerData});
  @override
  State<CreateOrderForCustomerScreen> createState() =>
      _CreateOrderForCustomerScreenState();
}
class _CreateOrderForCustomerScreenState
    extends State<CreateOrderForCustomerScreen> {
  bool isLoading = false;
  late Map<String, dynamic> customerData;
  Map<String, dynamic>? selectedProduct;
  int quantity = 1;
  double totalPrice = 0;
  List<Map<String, dynamic>> selectedProducts = [];
  Timer? _debounce;
  int totalQuantity = 0;
  double totalWeight = 0; // Khối lượng tính theo số lượng sản phẩm
  String sellerName = '';
  String? selectedShippingPartner;
  double? codAmount;
  String? shippingNote;
  Map<String, dynamic>? temporaryShippingInfo;

  // Thêm biến lưu địa chỉ giao hàng tạm thời
  Map<String, dynamic>? temporaryShippingAddress;

  // Phương thức thanh toán
  String paymentMethod = 'Tiền mặt';

  @override
  void initState() {
    super.initState();
    customerData = widget.customerData; // Không cần .data() nữa
    _getSellerName();
    temporaryShippingAddress = {
      'phone': customerData['phone'] ?? 'Chưa có số điện thoại',
      'name': customerData['name'] ?? 'Chưa có tên',
      'address': customerData['address'] ?? 'Chưa có địa chỉ',
    };
    if (customerData['products'] != null) {
      selectedProducts = List<Map<String, dynamic>>.from(customerData['products']);
      _calculateTotal();
    }
  }
  Future<void> _getSellerName() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    if (doc.exists) {
      setState(() {
        sellerName = doc.data()?['name'] ?? 'Chưa có tên';
      });
    }
  }

  void _selectProduct() async {
    final products = await Navigator.pushNamed(context, '/chose_product_for_order');
    if (products != null && products is List<Map<String, dynamic>>) {
      List<Map<String, dynamic>> loadedProducts = [];
      for (var p in products) {
        final doc = await FirebaseFirestore.instance
            .collection('Products')
            .doc(p['id'])
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          loadedProducts.add({
            ...p,
            'quantity': 1,
            'imageUrls': data['imageUrls'],
            'price': (data['price'] ?? 0).toDouble(),
            'stockQuantity': data['stockQuantity'] ?? 0,
            'weight': (data['weight'] ?? 0).toDouble(),
          });
        }
      }
      setState(() {
        selectedProducts = loadedProducts;
        _calculateTotal();

        // ✅ Reset lại shipping info khi đổi sản phẩm
        selectedShippingPartner = null;
        codAmount = null;
        shippingNote = null;
        temporaryShippingInfo = null;
      });
    }
  }
  void _calculateTotal() {
    totalPrice = 0;
    totalQuantity = 0;
    totalWeight = 0;
    for (var p in selectedProducts) {
      int qty = p['quantity'] ?? 1;
      double price = (p['price'] ?? 0).toDouble();
      double weight = (p['weight'] ?? 0).toDouble();
      totalPrice += price * qty;
      totalQuantity += qty;
      totalWeight += weight * qty;
    }
  }


  Color _statusColor(String status) {
    if (status == 'Bình thường') return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = customerData['avatarUrl'] as String?;
    final name = (customerData['name'] as String?)?.isNotEmpty == true
        ? customerData['name']
        : 'Chưa có tên';
    final status = (customerData['status'] as String?) ?? '';
    final phone = (customerData['phone'] as String?)?.isNotEmpty == true
        ? customerData['phone']
        : 'Chưa có số điện thoại';
    final address = (customerData['address'] as String?)?.isNotEmpty == true
        ? customerData['address']
        : 'Chưa có địa chỉ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo đơn cho khách hàng'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            message.showConfirmDialog(
              context: context,
              title: "Xác nhận",
              content: "Bạn có muốn bỏ quá trình tạo đơn không?",
              confirmText: "Có",
              cancelText: "Không",
              onConfirm: () {
                // chuyển thẳng về HomeOwnerScreen và xóa stack
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeOwnerScreen()),
                      (route) => false,
                );
              },
            );
          },
        ),

      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Thông tin khách hàng ---
            Container(
              width: double.infinity,
              color: Colors.white70,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      avatarUrl != null
                          ? CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(avatarUrl))
                          : const CircleAvatar(
                          radius: 40, child: Icon(Icons.person)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(name,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditCustomerForOrderScreen(
                                          customerId: customerData['id'],
                                          initialData: customerData,
                                        ),
                                      ),
                                    ).then((updatedData) {
                                      if (updatedData != null && updatedData is Map<String, dynamic>) {
                                        setState(() {
                                          customerData = {...customerData, ...updatedData};
                                        });
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(status,
                                  style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$phone-$address'),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 8, color: Colors.grey[200]),
            // --- Sản phẩm ---
            Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: _selectProduct,
                child: const Text('Chọn sản phẩm khác'),
              ),
            ),
            if (selectedProducts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                children: selectedProducts.map((product) {
                  Widget imageWidget;
                  if (product['imageUrls'] != null &&
                      product['imageUrls'] is List &&
                      (product['imageUrls'] as List).isNotEmpty) {
                    imageWidget = Image.network(
                      product['imageUrls'][0],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    );
                  } else {
                    imageWidget = _buildFallbackAvatar(product['name']);
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageWidget,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product['name'] ?? 'Tên sản phẩm',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(height: 4),
                              Text(
                                'Giá: ${(product['price'] ?? 0).toStringAsFixed(0)} đ',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tồn kho: ${product['stockQuantity'] ?? 0}',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                if (product['quantity'] > 1) {
                                  setState(() {
                                    product['quantity']--;
                                    _calculateTotal();
                                  });
                                }
                              },
                            ),
                            SizedBox(
                              width: 50,
                              height: 35,
                              child: TextField(
                                controller: TextEditingController(
                                  text: product['quantity'].toString(),
                                ),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                onChanged: (value) {
                                  final qty = int.tryParse(value) ?? 1;
                                  final maxStock = product['stockQuantity'] ?? 0;

                                  setState(() {
                                    if (qty > maxStock) {
                                      product['quantity'] = maxStock;
                                      message.showSnackbarfalse(context, 'Không được vượt quá tồn kho ($maxStock)');
                                    } else if (qty < 1) {
                                      product['quantity'] = 1;
                                    } else {
                                      product['quantity'] = qty;
                                    }
                                    _calculateTotal();
                                  });
                                },

                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                final maxStock = product['stockQuantity'] ?? 0;
                                if (product['quantity'] < maxStock) {
                                  setState(() {
                                    product['quantity']++;
                                    _calculateTotal();
                                  });
                                } else {
                                  message.showSnackbarfalse(context, 'Không được vượt quá tồn kho ($maxStock)');
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(right: 10.0), // Thêm margin bên phải
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Tổng cộng: ${message.formatCurrency(totalPrice)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Số lượng: $totalQuantity',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Khối lượng: ${totalWeight.toStringAsFixed(2)} kg',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            ],
            const SizedBox(height: 12),

            // --- Thông tin thanh toán ---
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment,color: Colors.green,),
                      const Text(
                        'Thông tin thanh toán',
                        style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Phương thức thanh toán',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Tiền mặt', child: Text('Tiền mặt')),
                      DropdownMenuItem(
                          value: 'Chuyển khoản',
                          child: Text('Chuyển khoản')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          paymentMethod = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8, ),
                  Text(
                    'Tổng cộng: ${message.formatCurrency(totalPrice)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),


                ],
              ),
            ),
            const SizedBox(height: 12),
            // --- Đơn vị giao hàng và phí ---
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.local_shipping, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            'Đơn vị giao hàng và phí',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: selectedProducts.isEmpty ? Colors.grey : Colors.blue,
                        ),
                        onPressed: selectedProducts.isEmpty
                            ? () {
                          message.showSnackbarfalse(context, "Vui lòng chọn sản phẩm trước!");
                        }
                            : () {
                          // ✅ Kiểm tra địa chỉ giao hàng trước
                          final address = temporaryShippingAddress?['address'] ?? "";
                          if (address.isEmpty || address == "Chưa có địa chỉ") {
                            message.showSnackbarfalse(context, "Hãy chọn địa chỉ người nhận!");
                            return;
                          }

                          // ✅ Nếu có địa chỉ thì mới cho chọn đơn vị giao hàng
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingShippingCompanyForOrderScreen(
                                totalPrice: totalPrice,
                                totalWeight: totalWeight,
                                initialData: temporaryShippingInfo,
                                receiverAddress: temporaryShippingAddress?['address'],
                              ),
                            ),
                          ).then((result) {
                            if (result != null && mounted) {
                              setState(() {
                                selectedShippingPartner = result['partnerName'];
                                codAmount = result['codAmount'];
                                shippingNote = result['note'];
                                temporaryShippingInfo = result;
                                totalWeight = result['weight'] ?? totalWeight;
                                temporaryShippingInfo?['shippingFee'] =
                                    result['shippingFee'] ?? 0;
                                temporaryShippingInfo?['prePaid'] =
                                    result['prePaid'] ?? 0;
                                temporaryShippingInfo?['partnerShippingFee'] =
                                    result['partnerShippingFee'] ?? 0;
                              });
                            }
                          });
                        },
                      ),


                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đối tác: ${selectedShippingPartner ?? "Chưa chọn"}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tiền thu hộ: ${message.formatCurrency(codAmount ?? totalPrice)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // --- Địa chỉ giao hàng ---
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.map, color: Colors.green,),
                          const Text(
                            'Địa chỉ giao hàng',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blue),
                        onPressed: () async {
                          final updatedAddress =
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditAddressForOrderScreen(
                                    initialData:
                                    temporaryShippingAddress ??
                                        {
                                          'phone': phone,
                                          'name': name,
                                          'address': address,
                                        },
                                  ),
                            ),
                          );
                          if (updatedAddress != null && mounted) {
                            setState(() {
                              temporaryShippingAddress =
                                  updatedAddress;
                            });
                            print('update address: $updatedAddress');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Text(
                  //   '${temporaryShippingAddress?['name'] ?? name}|${temporaryShippingAddress?['phone'] ?? phone}',
                  //   style: const TextStyle(fontSize: 16),
                  // ),
                  Text(
                    '${temporaryShippingAddress?['address'] ?? address}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12,),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error , color: Colors.green,),
                      const Text(
                        'Thông tin khác',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold ,),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ngày hóa đơn: ${DateTime.now().day.toString().padLeft(2, '0')}/'
                        '${DateTime.now().month.toString().padLeft(2, '0')}/'
                        '${DateTime.now().year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Người bán: $sellerName',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ghi chú: ${shippingNote ?? "Không có"}',
                    style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            icon: isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.check),
            label: Text(isLoading ? "Đang tạo đơn..." : "Tạo đơn"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.green,
            ),
            onPressed: isLoading
                ? null
                : () async {
              try {
                setState(() => isLoading = true);

                final currentUserId =
                    FirebaseAuth.instance.currentUser?.uid;

                if (currentUserId == null) {
                  message.showSnackbarfalse(
                      context, "Bạn chưa đăng nhập!");
                  return;
                }
                if (customerData['phone'] == null ||
                    (customerData['phone'] as String).trim().isEmpty ||
                    customerData['phone'] == "Chưa có số điện thoại") {
                  message.showSnackbarfalse(context, "Hãy thêm thông tin khách hàng (số điện thoại) trước khi tạo đơn!");
                  return;
                }
                if (selectedShippingPartner == null) {
                  message.showSnackbarfalse(
                      context, "Vui lòng chọn đơn vị giao hàng!");
                  return;
                }

                // ✅ Chỉ gọi API khi là J&T
                if (selectedShippingPartner == "J&T") {
                  await CustomerOrderServiceLive().createJTOrder(
                    context: context,
                    userId: currentUserId,
                    shippingPartner: selectedShippingPartner,
                    customerData: customerData,
                    temporaryShippingAddress: temporaryShippingAddress,
                    products: selectedProducts,
                    totalPrice: totalPrice,
                    totalQuantity: totalQuantity,
                    totalWeight: totalWeight,
                    codAmount: codAmount ?? totalPrice,
                    remark: shippingNote ?? "",
                    shippingFee: temporaryShippingInfo?['shippingFee'] ?? 0,
                    prePaid: temporaryShippingInfo?['prePaid'] ?? 0,
                    partnerShippingFee: temporaryShippingInfo?['partnerShippingFee'] ?? 0,
                  );
                  message.showSnackbartrue(context, "Tạo đơn thành công!");
                  Navigator.pop(context, customerData);
                } else {
                  message.showSnackbarfalse(
                      context, "Chỉ hỗ trợ tạo đơn với đối tác J&T!");
                }
              } catch (e) {
                message.showSnackbarfalse(
                    context, "Lỗi tạo đơn: $e");
              } finally {
                if (mounted) setState(() => isLoading = false);
              }
            },

          ),
        ),
      ),
    );
  }
  Widget _buildFallbackAvatar(String? productName) {
    return Container(
      width: 60,
      height: 60,
      color: Colors.blue[100],
      child: Center(
        child: Text(
          (productName?.isNotEmpty == true
              ? productName![0]
              : 'S')
              .toUpperCase(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
