import 'package:ban_hang/services/utilities/utilities_address.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/services/owner_services/setting_j_and_t_services.dart';

class SettingJAndTScreen extends StatefulWidget {
  const SettingJAndTScreen({super.key});

  @override
  State<SettingJAndTScreen> createState() => _SettingJAndTScreenState();
}

class _SettingJAndTScreenState extends State<SettingJAndTScreen> {
  bool isDefaultTab = true;

  // form controllers
  final apiAccountController = TextEditingController();
  final customerCodeController = TextEditingController();
  final keyController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final addressController = TextEditingController();

  // THAY ĐỔI 1: Sử dụng String để lưu tên, thay vì int code
  String? selectedProvinceName;
  String? selectedDistrictName;
  String? selectedWardName; // Sẽ lưu chuỗi "Tên Phường-Mã"

  // nâng cao
  String orderType = "1";
  String serviceType = "1";
  String payType = "CC_CASH";
  String productType = "EXPRESS";
  String goodsType = "bm000010";
  String deliveryType = "1";
  String isInsured = "0";

  bool _isLoading = true;

  @override
  void dispose() {
    apiAccountController.dispose();
    customerCodeController.dispose();
    keyController.dispose();
    passwordController.dispose();
    nameController.dispose();
    mobileController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await AddressUtils.loadAddressJson();
    await _loadConfig();
    setState(() {
      _isLoading = false;
    });
  }

  // THAY ĐỔI 2: Cập nhật hàm load để dùng AddressUtils và biến String
  Future<void> _loadConfig() async {
    final data = await SettingJAndTServices.getConfig();
    if (data == null) return;

    setState(() {
      customerCodeController.text = data["customerCode"] ?? "";
      keyController.text = data["key"] ?? "";
      passwordController.text = data["password"] ?? "";
      nameController.text = data["name"] ?? "";
      mobileController.text = data["mobile"] ?? "";
      addressController.text = data["address"] ?? "";
      selectedProvinceName = data["prov"];
      selectedDistrictName = data["city"];
      selectedWardName = data["area"];

      // if (data["prov"] != null && data["city"] != null && data["area"] != null) {
      //   selectedWardName = AddressUtils.findWardByName(
      //     province: data["prov"],
      //     district: data["city"],
      //     wardName: data["area"],
      //   );
      // }

      orderType = data["orderType"] ?? orderType;
      serviceType = data["serviceType"] ?? serviceType;
      payType = data["payType"] ?? payType;
      productType = data["productType"] ?? productType;
      goodsType = data["goodsType"] ?? goodsType;
      deliveryType = data["deliveryType"] ?? deliveryType;
      isInsured = data["isInsured"] ?? isInsured;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cài đặt J&T Express")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text("Mặc định"),
                selected: isDefaultTab,
                onSelected: (selected) {
                  setState(() => isDefaultTab = true);
                },
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text("Nâng cao"),
                selected: !isDefaultTab,
                onSelected: (selected) {
                  setState(() => isDefaultTab = false);
                },
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isDefaultTab ? _buildDefaultForm() : _buildAdvancedForm(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Lưu cấu hình mặc định
              await SettingJAndTServices.saveDefaultConfig(
                apiAccount: apiAccountController.text,
                customerCode: customerCodeController.text,
                key: keyController.text,
                password: passwordController.text,
                name: nameController.text,
                mobile: mobileController.text,
                prov: selectedProvinceName,
                city: selectedDistrictName,
                area: selectedWardName, // lưu nguyên "Tên-Mã"
                address: addressController.text,
              );

              // Lưu cấu hình nâng cao
              await SettingJAndTServices.saveAdvancedConfig(
                orderType: orderType,
                serviceType: serviceType,
                payType: payType,
                productType: productType,
                goodsType: goodsType,
                deliveryType: deliveryType,
                isInsured: isInsured,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Đã lưu cấu hình thành công")),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Lỗi khi lưu cấu hình: $e")),
              );
            }
          },

          child: const Text("Lưu"),
        ),
      ),
    );
  }

  /// FORM MẶC ĐỊNH
  Widget _buildDefaultForm() {
    // Luôn lấy dữ liệu từ AddressUtils
    final provinces = AddressUtils.getProvinces();
    final districts = selectedProvinceName != null
        ? AddressUtils.getDistricts(selectedProvinceName!)
        : <String>[];
    final wards = (selectedProvinceName != null && selectedDistrictName != null)
        ? AddressUtils.getWards(selectedProvinceName!, selectedDistrictName!)
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: customerCodeController, decoration: const InputDecoration(labelText: "Customer Code")),
        TextField(controller: keyController, decoration: const InputDecoration(labelText: "Key") , obscureText: true,),
        // TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
        const SizedBox(height: 12),
        TextField(controller: nameController, decoration: const InputDecoration(labelText: "Tên người gửi")),
        TextField(controller: mobileController, decoration: const InputDecoration(labelText: "SĐT người gửi")),
        const SizedBox(height: 12),

        // THAY ĐỔI 4: Cập nhật DropdownSearch để dùng biến String
        DropdownSearch<String>(
          popupProps: const PopupProps.menu(showSearchBox: true, title: Text('Chọn Tỉnh/Thành phố')),
          items: provinces,
          selectedItem: selectedProvinceName,
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(labelText: "Tỉnh/Thành"),
          ),
          onChanged: (value) {
            if (value == null || value == selectedProvinceName) return;
            setState(() {
              selectedProvinceName = value;
              selectedDistrictName = null;
              selectedWardName = null;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownSearch<String>(
          popupProps: const PopupProps.menu(showSearchBox: true, title: Text('Chọn Quận/Huyện')),
          items: districts,
          selectedItem: selectedDistrictName,
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(labelText: "Quận/Huyện"),
          ),
          onChanged: (value) {
            if (value == null || value == selectedDistrictName) return;
            setState(() {
              selectedDistrictName = value;
              selectedWardName = null;
            });
          },
          enabled: selectedProvinceName != null,
        ),
        const SizedBox(height: 12),
        DropdownSearch<String>(
          popupProps: const PopupProps.menu(
              showSearchBox: true, title: Text('Chọn Xã/Phường')),
          items: wards,
          // wards là List<String> như "Phường Long Thạnh Mỹ-028TPT19"
          selectedItem: selectedWardName,
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(labelText: "Xã/Phường"),
          ),
          onChanged: (value) {
            setState(() {
              selectedWardName = value; // lưu nguyên "Tên-Mã" vào biến
            });
          },
          enabled: selectedDistrictName != null,
        ),
        const SizedBox(height: 12),
        TextField(controller: addressController, decoration: const InputDecoration(labelText: "Địa chỉ chi tiết")),
      ],
    );
  }

  // ... hàm _buildAdvancedForm không đổi
  Widget _buildAdvancedForm() {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField(
              value: orderType,
              decoration: const InputDecoration(labelText: "Loại đơn đặt"),
              items: const [
                DropdownMenuItem(value: "1", child: Text("Đơn bình thường")),
                DropdownMenuItem(value: "2", child: Text("Đơn chuyển hoàn")),
              ],
              onChanged: (val) => setState(() => orderType = val!),
            ),
            DropdownButtonFormField(
              value: serviceType,
              decoration: const InputDecoration(labelText: "Loại dịch vụ"),
              items: const [
                DropdownMenuItem(value: "1", child: Text("Pickup")),
                DropdownMenuItem(value: "6", child: Text("Drop off")),
              ],
              onChanged: (val) => setState(() => serviceType = val!),
            ),
            DropdownButtonFormField(
              value: payType,
              decoration: const InputDecoration(labelText: "Phương thức thanh toán"),
              items: const [
                DropdownMenuItem(value: "PP_PM", child: Text("Thanh toán cuối tháng")),
                DropdownMenuItem(value: "PP_CASH", child: Text("Người gửi thanh toán")),
                DropdownMenuItem(value: "CC_CASH", child: Text("Người nhận thanh toán")),
              ],
              onChanged: (val) => setState(() => payType = val!),
            ),
            DropdownButtonFormField(
              value: productType,
              decoration: const InputDecoration(labelText: "Loại vận chuyển"),
              items: const [
                DropdownMenuItem(value: "EXPRESS", child: Text("EXPRESS")),
                DropdownMenuItem(value: "FAST", child: Text("FAST")),
                DropdownMenuItem(value: "SUPER", child: Text("SUPER")),
              ],
              onChanged: (val) => setState(() => productType = val!),
            ),
            DropdownButtonFormField(
              value: goodsType,
              decoration: const InputDecoration(labelText: "Loại hàng hóa"),
              items: const [
                DropdownMenuItem(value: "bm000001", child: Text("Tài liệu")),
                DropdownMenuItem(value: "bm000010", child: Text("Hàng hóa")),
                DropdownMenuItem(value: "bm000011", child: Text("Hàng tươi sống")),
              ],
              onChanged: (val) => setState(() => goodsType = val!),
            ),
            DropdownButtonFormField(
              value: deliveryType,
              decoration: const InputDecoration(labelText: "Loại phát hàng"),
              items: const [
                DropdownMenuItem(value: "1", child: Text("Phát bình thường")),
                DropdownMenuItem(value: "2", child: Text("Khách hàng tự đến lấy")),
              ],
              onChanged: (val) => setState(() => deliveryType = val!),
            ),
            DropdownButtonFormField(
              value: isInsured,
              decoration: const InputDecoration(labelText: "Khai giá"),
              items: const [
     DropdownMenuItem(value: "0", child: Text("Không")),
                DropdownMenuItem(value: "1", child: Text("Có")),
              ],
              onChanged: (val) => setState(() => isInsured = val!),
            ),
          ],
        );
  }
}