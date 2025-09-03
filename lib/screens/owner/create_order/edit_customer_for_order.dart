import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:ban_hang/services/owner_services/customer_order_service.dart';
import 'package:ban_hang/services/utilities/utilities_address.dart';

class EditCustomerForOrderScreen extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> initialData;

  const EditCustomerForOrderScreen({
    super.key,
    required this.customerId,
    required this.initialData,
  });

  @override
  State<EditCustomerForOrderScreen> createState() =>
      _EditCustomerForOrderScreenState();
}

class _EditCustomerForOrderScreenState
    extends State<EditCustomerForOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _facebookController;
  late TextEditingController _emailController;
  late TextEditingController _userIdController;
  late TextEditingController _addressDetailController;

  List<String> _provinces = [];
  List<String> _districts = [];
  List<String> _wards = [];

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedWard;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadAddressData();
  }

  void _initControllers() {
    _userIdController = TextEditingController(text: widget.customerId);
    _nameController =
        TextEditingController(text: widget.initialData['name'] ?? '');
    _phoneController =
        TextEditingController(text: widget.initialData['phone'] ?? '');
    _facebookController =
        TextEditingController(text: widget.initialData['facebook'] ?? '');
    _emailController =
        TextEditingController(text: widget.initialData['email'] ?? '');
    _addressDetailController = TextEditingController();
  }

  Future<void> _loadAddressData() async {
    await AddressUtils.loadAddressJson();
    _provinces = AddressUtils.getProvinces();

    _initializeFormWithAddress();
    setState(() { _isLoading = false; });
  }

  void _initializeFormWithAddress() {
    final address = widget.initialData['address'] as String? ?? '';
    final parsed = AddressUtils.parseFullAddress(address);

    _addressDetailController.text = parsed['addressDetail'] ?? '';
    _selectedProvince = parsed['province'];
    _selectedDistrict = parsed['district'];

    if (_selectedProvince != null && _selectedDistrict != null) {
      _districts = AddressUtils.getDistricts(_selectedProvince!);
      _wards = AddressUtils.getWards(_selectedProvince!, _selectedDistrict!);

      _selectedWard = _wards.firstWhere(
            (w) => w.startsWith(parsed['ward'] ?? ''),
        orElse: () => '',
      );
      if (_selectedWard!.isEmpty) _selectedWard = null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProvince == null ||
        _selectedDistrict == null ||
        _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đầy đủ địa chỉ')),
      );
      return;
    }

    final addressFull = AddressUtils.buildFullAddress(
      addressDetail: _addressDetailController.text.trim(),
      province: _selectedProvince!,
      district: _selectedDistrict!,
      ward: _selectedWard!,
    );

    final formData = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'facebook': _facebookController.text.trim(),
      'email': _emailController.text.trim(),
      'address': addressFull,
    };

    await CustomerOrderServiceLive()
        .updateFacebookCustomerById(widget.customerId, formData);


    Navigator.pop(context, formData);
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.initialData['status'] ?? '';
    final statusColor = status == 'Bình thường' ? Colors.green : Colors.grey;

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa thông tin khách hàng')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  if (widget.initialData['avatarUrl'] != null)
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(
                          widget.initialData['avatarUrl']),
                    )
                  else
                    const CircleAvatar(
                        radius: 40, child: Icon(Icons.person)),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                  controller: _userIdController,
                  readOnly: true,
                  decoration: _dropdownDecoration('Mã người dùng')),
              const SizedBox(height: 12),
              TextField(
                  controller: _nameController,
                  decoration: _dropdownDecoration('Tên')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _dropdownDecoration('Điện thoại'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập số điện thoại';
                  }
                  if (value.length < 9) {
                    return 'Số điện thoại không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _facebookController,
                  decoration: _dropdownDecoration('Facebook')),
              const SizedBox(height: 12),
              TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dropdownDecoration('Email')),
              const SizedBox(height: 16),
              Text('Địa chỉ',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              // Dropdown Tỉnh/Thành phố
              DropdownSearch<String>(
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm tỉnh/thành...',
                    ),
                  ),
                ),
                items: _provinces,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration:
                  _dropdownDecoration('Tỉnh/Thành phố'),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedProvince = value;
                    _selectedDistrict = null;
                    _selectedWard = null;
                    _districts = value != null
                        ? AddressUtils.getDistricts(value)
                        : [];
                    _wards = [];
                  });
                },
                selectedItem: _selectedProvince,
                validator: (value) =>
                value == null ? 'Vui lòng chọn tỉnh' : null,
              ),
              const SizedBox(height: 12),

              // Dropdown Quận/Huyện
              DropdownSearch<String>(
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm quận/huyện...',
                    ),
                  ),
                ),
                items: _districts,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration:
                  _dropdownDecoration('Quận/Huyện'),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedDistrict = value;
                    _selectedWard = null;
                    _wards = (value != null && _selectedProvince != null)
                        ? AddressUtils.getWards(
                        _selectedProvince!, value)
                        : [];
                  });
                },
                selectedItem: _selectedDistrict,
                enabled: _selectedProvince != null,
                validator: (value) =>
                value == null ? 'Vui lòng chọn quận/huyện' : null,
              ),
              const SizedBox(height: 12),

              // Dropdown Xã/Phường
              DropdownSearch<String>(
                itemAsString: (String? item) =>
                item?.split('-').first ?? '',
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm xã/phường...',
                    ),
                  ),
                ),
                items: _wards,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration:
                  _dropdownDecoration('Xã/Phường'),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedWard = value;
                  });
                },
                selectedItem: _selectedWard,
                enabled: _selectedDistrict != null,
                validator: (value) =>
                value == null ? 'Vui lòng chọn xã/phường' : null,
              ),
              const SizedBox(height: 12),

              // Địa chỉ chi tiết
              TextFormField(
                controller: _addressDetailController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ chi tiết',
                  hintText: 'Ví dụ: Số nhà, tên đường...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập địa chỉ chi tiết';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
