import 'package:ban_hang/services/owner_services/customer_order_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddProductForOrderScreen extends StatefulWidget {
  const AddProductForOrderScreen({super.key});

  @override
  State<AddProductForOrderScreen> createState() => _AddProductForOrderScreenState();
}

class _AddProductForOrderScreenState extends State<AddProductForOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _priceController = TextEditingController();
  final _weightController = TextEditingController();
  final _stockController = TextEditingController();

  String? _selectedType;
  String? _selectedCategory;

  final List<String> _types = ['Hàng hóa', 'Giấy tờ'];
  List<String> _categories = [];

  final CustomerOrderServiceLive _service = CustomerOrderServiceLive();

  String? productId; // id sản phẩm nếu sửa
  Map<String, dynamic>? _productToEdit; // Lưu tạm product để load sau khi categories xong

  @override
  void initState() {
    super.initState();
    _loadCategories();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        _productToEdit = args;
        // Nếu categories đã load rồi thì load luôn product
        if (_categories.isNotEmpty) {
          _loadProductToEdit(_productToEdit!);
          _productToEdit = null;
        }
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _service.fetchCategories();
      setState(() {
        _categories = categories;
        // Nếu có sản phẩm chờ load thì bây giờ set giá trị cho dropdown
        if (_productToEdit != null) {
          _loadProductToEdit(_productToEdit!);
          _productToEdit = null;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải danh sách nhóm sản phẩm: $e')),
      );
    }
  }

  void _loadProductToEdit(Map<String, dynamic> product) {
    productId = product['id'];
    _nameController.text = product['name'] ?? '';
    _codeController.text = product['code'] ?? '';

    // Kiểm tra _types có chứa type không, nếu không thì null
    final productType = product['type'];
    if (_types.contains(productType)) {
      _selectedType = productType;
    } else {
      _selectedType = null;
    }

    // Kiểm tra _categories có chứa category không, nếu không thì null
    final productCategory = product['category'];
    if (_categories.contains(productCategory)) {
      _selectedCategory = productCategory;
    } else {
      _selectedCategory = null;
    }

    _weightController.text = (product['weight'] ?? '').toString();
    _priceController.text = (product['price'] ?? '').toString();
    _stockController.text = (product['stock'] ?? '').toString();

    setState(() {});
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final productData = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'type': _selectedType,
      'category': _selectedCategory,
      'weight': double.tryParse(_weightController.text.trim()) ?? 0,
      'price': double.tryParse(_priceController.text.trim()) ?? 0,
      'stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'creatorId': currentUserId,
    };

    try {
      if (productId != null) {
        // Update sản phẩm
        await _service.updateProduct(productId!, currentUserId, productData);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật sản phẩm thành công')));
      } else {
        // Thêm mới sản phẩm
        await _service.addProduct(currentUserId, productData);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm sản phẩm thành công')));
      }
      Navigator.pop(context, true); // Trả về true để reload danh sách
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu sản phẩm: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(productId == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên sản phẩm *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên sản phẩm' : null,
              ),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Mã sản phẩm'),
              ),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v),
                decoration: const InputDecoration(labelText: 'Loại sản phẩm'),
                validator: (v) => v == null || v.isEmpty ? 'Vui lòng chọn loại sản phẩm' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                decoration: const InputDecoration(labelText: 'Nhóm sản phẩm'),
                validator: (v) => v == null || v.isEmpty ? 'Vui lòng chọn nhóm sản phẩm' : null,
              ),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Khối lượng (kg) *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập khối lượng';
                  final w = double.tryParse(v);
                  if (w == null || w <= 0) return 'Khối lượng phải lớn hơn 0';
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Giá bán *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá bán';
                  final p = double.tryParse(v);
                  if (p == null || p <= 0) return 'Giá bán phải lớn hơn 0';
                  return null;
                },
              ),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Tồn kho'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProduct,
                child: Text(productId == null ? 'Lưu' : 'Cập nhật'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

