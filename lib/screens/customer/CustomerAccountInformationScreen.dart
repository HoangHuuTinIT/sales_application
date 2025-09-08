import 'dart:io';
import 'package:ban_hang/services/customer_services/customer_account_information_services.dart';
import 'package:ban_hang/services/utilities/utilities_address.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerAccountInformationScreen extends StatefulWidget {
  const CustomerAccountInformationScreen({super.key});

  @override
  State<CustomerAccountInformationScreen> createState() =>
      _CustomerAccountInformationScreenState();
}

class _CustomerAccountInformationScreenState
    extends State<CustomerAccountInformationScreen> {
  final _auth = FirebaseAuth.instance;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final detailAddressController = TextEditingController();

  String? selectedProvince;
  String? selectedDistrict;
  String? selectedWard;
  String? gender;

  List<String> provinces = []; // <-- Phải là List<String>
  List<String> districts = []; // <-- Phải là List<String>
  List<String> wards = [];
  String? _imageUrl; // ảnh đang dùng
  File? _pickedImageFile; // ảnh tạm thời

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    provinces = AddressUtils.getProvinces();
    _loadUserData();
  }


  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return;

    setState(() {
      nameController.text = data['name'] ?? '';
      emailController.text = data['email'] ?? '';
      phoneController.text = data['phone'] ?? '';
      gender = data['gender'] ?? '';
      _imageUrl = data['avatarUrl'];

      final address = data['address'] as String? ?? '';

      // Sử dụng AddressUtils để phân tích địa chỉ
      final parsedAddress = AddressUtils.parseFullAddress(address);

      if (parsedAddress.isNotEmpty) {
        detailAddressController.text = parsedAddress['addressDetail'] ?? '';
        selectedProvince = parsedAddress['province'];

        if (selectedProvince != null) {
          // --- BỎ ÉP KIỂU SAI ---
          districts = AddressUtils.getDistricts(selectedProvince!);
          selectedDistrict = parsedAddress['district'];
        }

        if (selectedProvince != null && selectedDistrict != null) {
          // --- BỎ ÉP KIỂU SAI ---
          wards = AddressUtils.getWards(selectedProvince!, selectedDistrict!);
          selectedWard = AddressUtils.findWardByName(
            province: selectedProvince!,
            district: selectedDistrict!,
            wardName: parsedAddress['ward'] ?? '',
          );
        }
      }
    });
  }


  Future<void> _pickImage() async {
    final file =
    await CustomerAccountInformationServices().pickImageFile();
    if (file != null) {
      setState(() {
        _pickedImageFile = file;
      });
    }
  }

  void _changePhone() async {
    final newPhone =
    await CustomerAccountInformationServices().verifyAndChangePhone(context);
    if (newPhone != null) {
      final formattedPhone = message.formatVNPhone(newPhone);
      phoneController.text = formattedPhone;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'phone': formattedPhone,
        });
      }
    }
  }

  void _changeEmail() async {
    final newEmail =
    await CustomerAccountInformationServices().verifyAndChangeEmail(context);
    if (newEmail != null) {
      emailController.text = newEmail;
    }
  }

  Future<void> _handleSave() async {
    setState(() { isLoading = true; });

    String? finalAvatarUrl = _imageUrl;

    if (_pickedImageFile != null) {
      final url = await CustomerAccountInformationServices()
          .uploadAvatar(_pickedImageFile!);
      if (url != null) {
        finalAvatarUrl = url;
      }
    }

    // Logic lưu không đổi, vì service đã nhận vào là String
    await CustomerAccountInformationServices().updateAccountInfo(
      name: nameController.text.trim(),
      gender: gender ?? '',
      province: selectedProvince ?? '',
      district: selectedDistrict ?? '',
      ward: selectedWard ?? '', // Gửi cả mã nếu có
      detailAddress: detailAddressController.text.trim(),
    );

    if (finalAvatarUrl != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'avatarUrl': finalAvatarUrl});
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công')),
      );
    }

    setState(() {
      isLoading = false;
      _pickedImageFile = null;
      _imageUrl = finalAvatarUrl;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản của tôi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: InkWell(
                onTap: _pickImage,
                child: _pickedImageFile != null
                    ? CircleAvatar(
                  radius: 50,
                  backgroundImage: FileImage(_pickedImageFile!),
                )
                    : (_imageUrl != null
                    ? CachedNetworkImage(
                  imageUrl: _imageUrl!,
                  imageBuilder: (context, imageProvider) =>
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: imageProvider,
                      ),
                  placeholder: (context, url) =>
                  const CircularProgressIndicator(),
                  errorWidget: (context, url, error) =>
                  const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50)),
                )
                    : const CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.person, size: 50),
                )),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Họ tên'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Giới tính:'),
                Radio<String>(
                  value: 'Nam',
                  groupValue: gender,
                  onChanged: (value) => setState(() => gender = value),
                ),
                const Text('Nam'),
                Radio<String>(
                  value: 'Nữ',
                  groupValue: gender,
                  onChanged: (value) => setState(() => gender = value),
                ),
                const Text('Nữ'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email',
                suffixIcon: TextButton(
                  onPressed: _changeEmail,
                  child: const Text('Thay đổi'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Số điện thoại',
                suffixIcon: TextButton(
                  onPressed: _changePhone,
                  child: const Text('Thay đổi'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownSearch<String>(
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: "Tìm kiếm",
                    border: OutlineInputBorder(),
                  ),
                ),
                menuProps: MenuProps(
                  backgroundColor: Colors.white,
                ),
              ),
              items: provinces,
              selectedItem: selectedProvince,
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: "Tỉnh/Thành phố",
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (province) {
                setState(() {
                  selectedProvince = province;
                  selectedDistrict = null;
                  selectedWard = null;
                  districts = (province != null) ? AddressUtils.getDistricts(province) : [];
                  wards = [];
                });
              },
            ),

            const SizedBox(height: 12),

            // Quận/Huyện
            DropdownSearch<String>(
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: "Tìm kiếm",
                    border: OutlineInputBorder(),
                  ),
                ),
                menuProps: MenuProps(
                  backgroundColor: Colors.white,
                ),
              ),
              items: districts,
              selectedItem: selectedDistrict,
              enabled: selectedProvince != null, // Chỉ bật khi đã chọn tỉnh
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: "Quận/Huyện",
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (district) {
                setState(() {
                  selectedDistrict = district;
                  selectedWard = null;
                  wards = (selectedProvince != null && district != null)
                      ? AddressUtils.getWards(selectedProvince!, district)
                      : [];
                });
              },
            ),

            const SizedBox(height: 12),

            // Phường/Xã
            DropdownSearch<String>(
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: "Tìm kiếm",
                    border: OutlineInputBorder(),
                  ),
                ),
                menuProps: MenuProps(
                  backgroundColor: Colors.white,
                ),
              ),
              items: wards,
              selectedItem: selectedWard,
              enabled: selectedDistrict != null, // Chỉ bật khi đã chọn huyện
              // Hiển thị tên phường (bỏ mã)
              itemAsString: (ward) => ward?.split('-').first ?? '',
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: "Phường/Xã",
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (ward) {
                setState(() {
                  selectedWard = ward;
                });
              },
            ),

            const SizedBox(height: 12),
            TextField(
              controller: detailAddressController,
              decoration: const InputDecoration(
                  labelText: 'Thôn/Xóm/Ngõ/Số nhà',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _handleSave,
              child: isLoading
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Đang lưu...'),
                ],
              )
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
