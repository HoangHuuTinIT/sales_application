import 'dart:io';
import 'package:ban_hang/utils/message.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ban_hang/services/staff_services/product_service.dart';
import 'package:ban_hang/services/staff_services/category_service.dart';
import 'package:intl/intl.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockQuantityController = TextEditingController();
  List<String> _existingImageUrls = [];
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categoryOptions = [];
  List<File> _pickedImages = [];
  bool _isSaving = false;
  List<Map<String, dynamic>> _products = [];
  String? _filterCategoryId;
  bool _isLoadingProducts = true;
  String? _editingProductId;
  Set<String> _selectedProductIds = {};
  bool _selectionMode = false;
  final _discountController = TextEditingController();
  DateTime? _discountStartDate;
  DateTime? _discountEndDate;
  final _weightController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCategories().then((_) => _fetchProducts());
    _discountController.clear();
    _discountStartDate = null;
    _discountEndDate = null;
  }
  double parsePriceInput(String raw) {
    final cleaned = raw.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(cleaned) ?? 0;
  }
  void _fetchProducts() async {
    setState(() => _isLoadingProducts = true);
    final service = ProductService();
    final products = await service.fetchProducts(categoryId: _filterCategoryId);
    setState(() {
      _products = products;
      _isLoadingProducts = false;
    });
  }

  Future<void> _fetchCategories() async {
    final service = CategoryService();
    final categories = await service.fetchAllCategories();
    setState(() {
      _categoryOptions = categories;
    });
  }

  void _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _pickedImages = pickedFiles.map((e) => File(e.path)).toList();
      });
    }
  }

  void _updateProduct() async {
    if (_editingProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hãy chọn sản phẩm cần sửa')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final discountText = _discountController.text.trim();
    final hasDiscount = discountText.isNotEmpty && double.tryParse(discountText) != null && double.parse(discountText) > 0;
    if (hasDiscount) {
      if (_discountStartDate == null || _discountEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hãy chọn khoảng thời gian giảm giá')),
        );
        return;
      }
      if (_discountStartDate!.isAfter(_discountEndDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thời gian giảm giá không hợp lệ')),
        );
        return;
      }
    }
    setState(() => _isSaving = true);

    final service = ProductService();
    List<String> imageUrls = List.from(_existingImageUrls);
    if (_pickedImages.isNotEmpty) {
      final newUrls = await service.uploadMultipleImages(_pickedImages);
      imageUrls.addAll(newUrls);
      if (imageUrls.isEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi upload ảnh')));
        return;
      }
    }

    final error = await service.updateProduct(
      productId: _editingProductId!,
      name: _productNameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: parsePriceInput(_priceController.text.trim()),
      stockQuantity: int.parse(_stockQuantityController.text.trim()),
      categoryId: _selectedCategoryId!,
      imageUrls: imageUrls,
      discount: hasDiscount ? double.parse(discountText) : 0.0,
      discountStartDate: hasDiscount ? _discountStartDate! : DateTime(1970),
      discountEndDate: hasDiscount ? _discountEndDate! : DateTime(1970),
      weight: double.parse(_weightController.text.trim()),
      code: _codeController.text.trim(),
    );


    setState(() {
      _isSaving = false;
      _editingProductId = null;
      _pickedImages = [];
      _existingImageUrls = [];
      _formKey.currentState!.reset();
      _productNameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _stockQuantityController.clear();
      _discountController.clear();
      _discountStartDate = null;
      _discountEndDate = null;
      _selectedCategoryId = null;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sửa sản phẩm thành công')));
      _fetchProducts();
    }
  }

  void _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ảnh')));
      return;
    }
    // 👉 Kiểm tra logic giảm giá
    final discountText = _discountController.text.trim();
    final hasDiscount = discountText.isNotEmpty && double.tryParse(discountText) != null && double.parse(discountText) > 0;
    if (hasDiscount) {
      if (_discountStartDate == null || _discountEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hãy chọn khoảng thời gian giảm giá')),
        );
        return;
      }
      if (_discountStartDate!.isAfter(_discountEndDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thời gian giảm giá không hợp lệ')),
        );
        return;
      }
    }
    setState(() => _isSaving = true);
    final service = ProductService();
    final imageUrls = await service.uploadMultipleImages(_pickedImages);
    if (imageUrls.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi upload ảnh')));
      return;
    }
    final error = await service.addProduct(
      name: _productNameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: parsePriceInput(_priceController.text.trim()),
      stockQuantity: int.parse(_stockQuantityController.text.trim()),
      categoryId: _selectedCategoryId!,
      imageUrls: imageUrls,
      discount: hasDiscount ? double.parse(discountText) : 0.0,
      discountStartDate: hasDiscount ? _discountStartDate! : DateTime(1970),
      discountEndDate: hasDiscount ? _discountEndDate! : DateTime(1970),
      weight: double.parse(_weightController.text.trim()),
      code: _codeController.text.trim(),
    );


    setState(() => _isSaving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm sản phẩm thành công')));
      _formKey.currentState!.reset();
      _productNameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _stockQuantityController.clear();
      _discountController.clear();
      _discountStartDate = null;
      _discountEndDate = null;
      setState(() {
        _pickedImages = [];
        _selectedCategoryId = null;
        _fetchProducts();
      });
    }
  }

  void _deleteSelectedProducts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa ${_selectedProductIds.length} sản phẩm không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm == true) {
      final service = ProductService();
      for (final id in _selectedProductIds) {
        await service.deleteProduct(id);
      }
      message.showSnackbartrue(context, 'Đã xóa ${_selectedProductIds.length} sản phẩm');
      setState(() {
        _selectedProductIds.clear();
        _selectionMode = false;
      });
      _fetchProducts();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý sản phẩm'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Ô chọn ảnh vuông bo góc ở trên cùng bên trái
              // Phần trên cùng: Ô chọn ảnh + ảnh đã chọn
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Ô vuông chọn ảnh
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.camera_alt, size: 28, color: Colors.grey),
                                SizedBox(width: 4),
                                Icon(Icons.add, size: 24, color: Colors.grey),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Thêm ảnh',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Hiển thị ảnh đã chọn hoặc ảnh có sẵn
                    ..._existingImageUrls.map((url) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _existingImageUrls.remove(url);
                                  });
                                },
                                child: const Icon(Icons.cancel, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    ..._pickedImages.map((file) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                file,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _pickedImages.remove(file);
                                  });
                                },
                                child: const Icon(Icons.cancel, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Các trường nhập liệu chuyển sang TextField (không có validator)
              buildTextField(
                controller: _productNameController,
                label: 'Tên sản phẩm',
              ),
              const SizedBox(height: 8),
              buildTextField(
                controller: _descriptionController,
                label: 'Mô tả',
              ),
              const SizedBox(height: 8),
              buildTextField(
                controller: _priceController,
                label: 'Giá',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              buildTextField(
                controller: _stockQuantityController,
                label: 'Số lượng tồn kho',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),

              if (_priceController.text.isNotEmpty &&
                  double.tryParse(_priceController.text) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: Text(
                    'Giá hiển thị: ${message.formatCurrency(double.parse(_priceController.text))}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                items: _categoryOptions.map((category) {
                  return DropdownMenuItem(
                    value: category['id'] as String,
                    child: Text(category['name']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategoryId = value),
                decoration: const InputDecoration(labelText: 'Loại hàng'),
                validator: (value) => value == null ? 'Vui lòng chọn loại hàng' : null,
              ),
              const SizedBox(height: 8),

              // Trường giảm giá cũng chuyển thành TextField không validator
              TextField(
                controller: _discountController,
                decoration: const InputDecoration(labelText: 'Giảm giá (%)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (value.trim().isEmpty || parsed == null || parsed <= 0) {
                    setState(() {
                      _discountStartDate = null;
                      _discountEndDate = null;
                    });
                  } else {
                    setState(() {}); // rebuild nút
                  }
                },
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_discountController.text.trim().isNotEmpty &&
                          double.tryParse(_discountController.text.trim()) != null &&
                          double.parse(_discountController.text.trim()) > 0)
                          ? () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _discountStartDate = picked;
                          });
                        }
                      }
                          : null,
                      child: Text(_discountStartDate == null
                          ? 'Chọn ngày bắt đầu'
                          : 'Từ: ${DateFormat('dd/MM/yyyy').format(_discountStartDate!)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_discountController.text.trim().isNotEmpty &&
                          double.tryParse(_discountController.text.trim()) != null &&
                          double.parse(_discountController.text.trim()) > 0)
                          ? () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _discountEndDate = picked;
                          });
                        }
                      }
                          : null,
                      child: Text(_discountEndDate == null
                          ? 'Chọn ngày kết thúc'
                          : 'Đến: ${DateFormat('dd/MM/yyyy').format(_discountEndDate!)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              buildTextField(
                controller: _codeController,
                label: 'Mã sản phẩm',
              ),
              const SizedBox(height: 8),
              buildTextField(
                controller: _weightController,
                label: 'Khối lượng (kg)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitProduct,
                      child: _isSaving
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Lưu sản phẩm'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _updateProduct,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('Sửa sản phẩm'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text('📦 Danh sách sản phẩm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

              DropdownButton<String>(
                value: _filterCategoryId ?? 'all',
                hint: const Text('Chọn loại để lọc'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Tất cả'),
                  ),
                  ..._categoryOptions.map((c) => DropdownMenuItem(
                    value: c['id'],
                    child: Text(c['name']),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterCategoryId = value == 'all' ? null : value;
                    _fetchProducts();
                  });
                },
              ),

              const SizedBox(height: 12),

              _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                  ? const Text('Không có sản phẩm nào.')
                  : Column(
                children: [
                  if (_selectedProductIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ElevatedButton.icon(
                        onPressed: _deleteSelectedProducts,
                        icon: const Icon(Icons.delete),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        label: Text('Xóa ${_selectedProductIds.length} sản phẩm đã chọn'),
                      ),
                    ),
                  ..._products.map((product) {
                    final imageUrls = product['imageUrls'];
                    final firstImage = (imageUrls != null && imageUrls is List && imageUrls.isNotEmpty)
                        ? imageUrls[0]
                        : 'https://via.placeholder.com/150';
                    final productId = product['productId'];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        onLongPress: () {
                          setState(() {
                            _selectionMode = true;
                            _selectedProductIds.add(productId);
                          });
                        },
                        onTap: () {
                          if (_selectionMode) {
                            setState(() {
                              if (_selectedProductIds.contains(productId)) {
                                _selectedProductIds.remove(productId);
                                if (_selectedProductIds.isEmpty) {
                                  _selectionMode = false;
                                }
                              } else {
                                _selectedProductIds.add(productId);
                              }
                            });
                          } else {
                            setState(() {
                              _editingProductId = productId;
                              _productNameController.text = product['name'] ?? '';
                              _descriptionController.text = product['description'] ?? '';
                              _priceController.text = product['price'].toString();
                              _stockQuantityController.text = product['stockQuantity'].toString();
                              _selectedCategoryId = _categoryOptions.firstWhere(
                                    (c) => c['name'] == product['categoryName'],
                                orElse: () => {'id': null},
                              )['id'];
                              _pickedImages = [];
                              _existingImageUrls = List<String>.from(product['imageUrls'] ?? []);
                              _discountController.text = (product['discount'] ?? 0).toString();
                              _discountStartDate = product['discountStartDate'] is DateTime ? product['discountStartDate'] : null;
                              _discountEndDate = product['discountEndDate'] is DateTime ? product['discountEndDate'] : null;
                              _weightController.text = product['weight']?.toString() ?? '';
                              _codeController.text = product['code'] ?? '';
                            });
                          }
                        },
                        leading: Checkbox(
                          value: _selectedProductIds.contains(productId),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedProductIds.add(productId);
                              } else {
                                _selectedProductIds.remove(productId);
                              }
                            });
                          },
                        ),
                        trailing: Image.network(
                          firstImage,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                        title: Text(product['name']),
                        subtitle: Text(
                          '${product['categoryName']} • ${message.formatCurrency(product['price'])}\nTồn kho: ${product['stockQuantity']}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
    );
  }

}