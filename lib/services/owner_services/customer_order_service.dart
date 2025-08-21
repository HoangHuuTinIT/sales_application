import 'dart:convert';
import 'dart:math';
import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:vietnam_provinces/vietnam_provinces.dart';

class CustomerOrderServiceLive {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  /// Lấy danh sách khách hàng của user hiện tại, role = 'customer'
  Future<List<Map<String, dynamic>>> fetchCustomers(String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('creatorId', isEqualTo: currentUserId)
          .where('role', isEqualTo: 'customer')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Lỗi khi lấy danh sách khách hàng: $e');
    }
  }
  Future<List<Map<String, dynamic>>> fetchCustomersByShopIdFromRef() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("Chưa đăng nhập");

      // 1. Lấy shopId của user hiện tại
      final userSnap = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userSnap.exists) throw Exception("Không tìm thấy user");
      final shopId = userSnap.data()?['shopid'];
      if (shopId == null) throw Exception("User không có shopId");

      // 2. Lấy danh sách shop_facebook_customer theo shopId
      final shopCustomerSnap = await _firestore
          .collection('shop_facebook_customer')
          .where('shopid', isEqualTo: shopId)
          .get();

      // 3. Từ mỗi customerRef, lấy dữ liệu facebook_customer
      List<Map<String, dynamic>> customers = [];
      for (var doc in shopCustomerSnap.docs) {
        final ref = doc.data()['customerRef'];
        if (ref is DocumentReference) {
          final customerSnap = await ref.get();
          if (customerSnap.exists) {
            final data = customerSnap.data() as Map<String, dynamic>;
            data['id'] = customerSnap.id;
            customers.add(data);
          }
        }
      }
      return customers;
    } catch (e) {
      throw Exception("Lỗi khi lấy danh sách khách hàng từ ref: $e");
    }
  }

  /// Cập nhật hoặc tạo mới thông tin khách hàng trong bảng users
  Future<void> updateCustomerInfo(String userId, Map<String, dynamic> updatedData) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Cập nhật thông tin
        await docRef.update(updatedData);
      } else {
        // Tạo mới nếu chưa tồn tại
        await docRef.set(updatedData);
      }
    } catch (e) {
      throw Exception('Lỗi khi cập nhật thông tin khách hàng: $e');
    }
  }


  /// Kiểm tra user hiện tại có sản phẩm nào không
  Future<bool> hasProducts(String currentUserId) async {
    final snapshot = await _firestore
        .collection('Products')
        .where('creatorId', isEqualTo: currentUserId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Lấy danh sách sản phẩm của user hiện tại
  Future<List<Map<String, dynamic>>> fetchProducts(String currentUserId) async {
    final snapshot = await _firestore
        .collection('Products')
        .where('creatorId', isEqualTo: currentUserId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Thêm sản phẩm mới cho user
  Future<void> addProduct(String currentUserId, Map<String, dynamic> productData) async {
    productData['creatorId'] = currentUserId;
    await _firestore.collection('Products').add(productData);
  }
  Future<List<String>> fetchCategories() async {
    final snapshot = await _firestore.collection('Categories').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return data['name'] as String? ?? 'Không tên';
    }).toList();
  }

  Future<void> updateProduct(String productId, String creatorId, Map<String, dynamic> data) async {
    final docRef = _firestore.collection('Products').doc(productId);
    final doc = await docRef.get();
    if (doc.exists && doc.data()?['creatorId'] == creatorId) {
      await docRef.update(data);
    } else {
      throw Exception('Sản phẩm không tồn tại hoặc không thuộc về bạn');
    }
  }

  /// Xóa sản phẩm theo productId và creatorId
  Future<void> deleteProduct(String productId, String creatorId) async {
    final docRef = _firestore.collection('Products').doc(productId);
    final doc = await docRef.get();
    if (doc.exists && doc.data()?['creatorId'] == creatorId) {
      await docRef.delete();
    } else {
      throw Exception('Sản phẩm không tồn tại hoặc không thuộc về bạn');
    }
  }
  Future<List<Map<String, dynamic>>> loadProducts(String uid) async {
    final list = await fetchProducts(uid);
    return list.map((p) {
      final imageUrls = p['imageUrls'] as List<dynamic>?;
      return {
        ...p,
        'imageUrls': imageUrls?.cast<String>() ?? [],
      };
    }).toList();
  }
  Future<List<Map<String, dynamic>>> loadProductsForCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("User chưa đăng nhập");
    }

    final uid = currentUser.uid;
    final list = await fetchProducts(uid);

    return list.map((p) {
      final imageUrls = p['imageUrls'] as List<dynamic>?;
      return {
        ...p,
        'imageUrls': imageUrls?.cast<String>() ?? [],
      };
    }).toList();
  }

  // --- Hàm tìm kiếm sản phẩm ---
  List<Map<String, dynamic>> searchProducts(
      List<Map<String, dynamic>> allProducts,
      String query,
      ) {
    if (query.isEmpty) return List.from(allProducts);
    return allProducts
        .where((p) => (p['name'] ?? '')
        .toString()
        .toLowerCase()
        .contains(query.toLowerCase()))
        .toList();
  }

  // --- Hàm chọn hoặc bỏ chọn sản phẩm ---
  List<Map<String, dynamic>> toggleSelection(
      List<Map<String, dynamic>> selectedProducts,
      Map<String, dynamic> product,
      bool selected,
      ) {
    if (selected) {
      return [...selectedProducts, product];
    } else {
      return selectedProducts.where((p) => p['id'] != product['id']).toList();
    }
  }

  // --- Hàm xác nhận (ở service chỉ trả dữ liệu, UI tự Navigator.pop) ---
  List<Map<String, dynamic>> confirmSelection(
      List<Map<String, dynamic>> selectedProducts,
      ) {
    return selectedProducts;
  }

  // Hàm fetchProducts sẵn có không thay đổi
  Future<List<Map<String, dynamic>>> fetchProductsForSearchProducts(String currentUserId) async {
    final snapshot = await _firestore
        .collection('Products')
        .where('creatorId', isEqualTo: currentUserId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
  Future<void> updateFacebookCustomerByFbid(String fbid, Map<String, dynamic> formData) async {
    try {
      if (fbid.isEmpty) throw Exception("Thiếu fbid");

      // 1. Lấy document theo fbid
      final querySnapshot = await _firestore
          .collection('facebook_customer')
          .where('fbid', isEqualTo: fbid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("Không tìm thấy khách hàng với fbid này");
      }

      final docRef = querySnapshot.docs.first.reference;
      final currentData = querySnapshot.docs.first.data();

      // 2. So sánh và chỉ update các trường thay đổi
      final Map<String, dynamic> updatedData = {};

      void checkAndUpdate(String key, dynamic newValue) {
        if (newValue != null && newValue.toString().trim().isNotEmpty && newValue != currentData[key]) {
          updatedData[key] = newValue;
        }
      }

      checkAndUpdate('name', formData['name']);
      checkAndUpdate('phone', formData['phone']);
      checkAndUpdate('facebook', formData['facebook']);
      checkAndUpdate('email', formData['email']);
      checkAndUpdate('address', formData['address']);

      // Thêm updatedAt để biết lúc nào sửa
      updatedData['updatedAt'] = FieldValue.serverTimestamp();

      // 3. Cập nhật (merge giữ nguyên các trường khác)
      await docRef.set(updatedData, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Lỗi khi cập nhật facebook_customer: $e");
    }
  }
  Future<List<Map<String, dynamic>>> loadProductsForCurrentUserByShopId() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("User chưa đăng nhập");
    }

    // Lấy shopid của user hiện tại
    final userSnap = await _firestore.collection('users').doc(currentUser.uid).get();
    if (!userSnap.exists) throw Exception("Không tìm thấy user");
    final shopId = userSnap.data()?['shopid'];
    if (shopId == null) throw Exception("User không có shopid");

    // Lấy sản phẩm có shopid trùng
    final snapshot = await _firestore
        .collection('Products')
        .where('shopid', isEqualTo: shopId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      final imageUrls = data['imageUrls'] as List<dynamic>?;
      data['imageUrls'] = imageUrls?.cast<String>() ?? [];
      return data;
    }).toList();
  }


  Future<List<Province>> initLocationData() async {
    await _authService.initLocations();
    return _authService.getProvinces();
  }

  Map<String, dynamic> parseAddressParts(String address, List<Province> provinces) {
    List<String> parts = address.split('-').map((e) => e.trim()).toList();

    if (parts.length < 4) {
      return {
        'detailAddress': address,
        'province': null,
        'districts': <District>[],
        'district': null,
        'wards': <Ward>[],
        'ward': null,
      };
    }

    String wardName = parts[1];
    String districtName = parts[2];
    String provinceName = parts[3];

    Province? selectedProvince = provinces.firstWhere(
          (p) => p.name == provinceName,
      orElse: () => provinces.first,
    );
    List<District> districts = _authService.getDistricts(selectedProvince.code);

    District? selectedDistrict = districts.firstWhere(
          (d) => d.name == districtName,
      orElse: () => districts.first,
    );
    List<Ward> wards = _authService.getWards(
      selectedProvince.code,
      selectedDistrict.code,
    );

    Ward? selectedWard = wards.firstWhere(
          (w) => w.name == wardName,
      orElse: () => wards.first,
    );

    return {
      'detailAddress': parts.first,
      'province': selectedProvince,
      'districts': districts,
      'district': selectedDistrict,
      'wards': wards,
      'ward': selectedWard,
    };
  }


  Future<void> createJTOrder({
    required BuildContext context,
    required String userId,
    required String? shippingPartner,
    required Map<String, dynamic> customerData,
    required Map<String, dynamic>? temporaryShippingAddress,
    required List<Map<String, dynamic>> products,
    required double totalPrice,
    required int totalQuantity,
    required double totalWeight,
    required double codAmount,
    required String remark,
    double shippingFee = 0,   // 👈 thêm
    double prePaid = 0,       // 👈 thêm
    double partnerShippingFee = 0,
  }) async {
    if (shippingPartner != "J&T") {
      throw "Chỉ hỗ trợ J&T hiện tại";
    }

    // Lấy shopid từ user
    final userDoc = await _firestore.collection("users").doc(userId).get();
    final shopId = userDoc.data()?["shopid"];
    if (shopId == null) throw "Người dùng chưa có shopid";

    // Query JT_setting theo shopid
    final settingSnap = await _firestore
        .collection("JT_setting")
        .where(FieldPath.documentId, isEqualTo: shopId)
        .limit(1)
        .get();

    if (settingSnap.docs.isEmpty) {
      throw "Không tìm thấy cấu hình J&T cho shopid này";
    }

    final jt = settingSnap.docs.first.data();

    // Tạo password = MD5(key + "jadada369t3")
    final key = jt["key"];
    final rawPass = utf8.encode("$key" "jadada369t3");
    final md5Pass = md5.convert(rawPass).toString().toUpperCase();

    // --- Ưu tiên dùng địa chỉ giao hàng tạm nếu có ---
    final receiverData = temporaryShippingAddress ?? customerData;

    // Parse địa chỉ người nhận
    Map<String, String> recvAddr = parseAddressString(receiverData["address"]);

    // Sinh txlogisticId
    final now = DateTime.now();
    final rand = _randomString(4);
    final txlogisticId = "ODR-${_formatDate(now)}-${_formatTime(now)}-$rand";

    // Debug log
    print("Người gửi: ${jt["name"]}, ${jt["mobile"]}, "
        "${jt["prov"]}-${jt["city"]}-${jt["area"]}, ${jt["address"]}");
    print("Người nhận: ${receiverData["name"]}, ${receiverData["phone"]}, "
        "${recvAddr["prov"]}-${recvAddr["city"]}-${recvAddr["area"]}, ${recvAddr["address"]}");

    // BizContent
    final bizContent = {
      "customerCode": jt["customerCode"],
      "txlogisticId": txlogisticId,
      "password": md5Pass,
      "orderType": jt["orderType"],
      "serviceType": jt["serviceType"],

      "sender": {
        "name": jt["name"],
        "mobile": jt["mobile"],
        "prov": jt["prov"],
        "city": jt["city"],
        "area": jt["area"],
        "address": jt["address"],
      },
      "receiver": {
        "name": receiverData["name"],
        "mobile": receiverData["phone"],
        "prov": recvAddr["prov"],
        "city": recvAddr["city"],
        "area": recvAddr["area"],
        "address": recvAddr["address"],
      },
      "payType": jt["payType"],
      "goodsType": jt["goodsType"],
      "goodsValue": totalPrice,
      "codMoney": codAmount,
      "remark": remark,
      "productType": jt["productType"],
      "isInsured": jt["isInsured"],
      "deliveryType": jt["deliveryType"],
      "packageInfo": {"weight": totalWeight.toString()},
      "itemsValue": totalPrice,
      "totalQuantity": totalQuantity,
    };

    final bizContentStr = jsonEncode(bizContent);
print('bizconten ne: $bizContentStr');
    // Digest
    var privateKey = dotenv.env['PRIVATE_KEY'];
    final digestSrc = utf8.encode(bizContentStr + privateKey!);
    final md5Digest = md5.convert(digestSrc).bytes;
    final digest = base64Encode(md5Digest);

    // Timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Gửi request
    final url =
        "https://demoopenapi.jtexpress.vn/webopenplatformapi/api/order/addOrder";
    final res = await http.post(
      Uri.parse(url),
      headers: {
        "digest": digest,
        "timestamp": "$timestamp",
        "apiAccount": jt["apiAccount"],
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: {"bizContent": bizContentStr},
    );

    print("trường apiAccount: ${jt["apiAccount"]}");
    print("thông số jt:$jt");

    if (res.statusCode != 200) {
      throw "API lỗi: ${res.body}";
    }
    final respData = jsonDecode(res.body);
    print("J&T Response: $respData");
    final billCode = respData["data"]?["billCode"];
    if (billCode == null || billCode.toString().isEmpty) {
      throw "Không lấy được mã vận đơn từ J&T";
    }
    // Lấy thông tin user
    final userData = userDoc.data();
    final createdByName = userData?["name"]; // 👈 lấy tên người tạo
    if (shopId == null) throw "Người dùng chưa có shopid";

    await _firestore.collection("Order").add({
      "billCode": billCode, // mã vận đơn
      "txlogisticId": txlogisticId, // mã đơn hàng
      "invoiceDate": DateTime.now(), // ngày hóa đơn
      "customerName": customerData["name"] ?? "",
      "customerPhone": customerData["phone"] ?? "",
      "shippingNote": remark,
      "shippingAddress": (temporaryShippingAddress != null)
          ? temporaryShippingAddress["address"]
          : customerData["address"],
      "shippingPartner": shippingPartner,
      "productType": jt["productType"], // dịch vụ
      "isInsured": jt["isInsured"], // khai giá hàng hóa
      "totalWeight": totalWeight,
      "shippingFee": shippingFee,
      "codAmount": codAmount,
      "createdAt": FieldValue.serverTimestamp(),
      "createdBy": createdByName ?? "Không rõ",
      "totalAmount":totalPrice ,
      "shopid":shopId,
      "customerCode":jt["customerCode"],
      "key" :jt["key"],
      "customerId": customerData['id'],
      "fbid": customerData['fbid']??null,
      "partnerShippingFee": partnerShippingFee,
    });
  }

  // Helpers
  static Map<String, String> parseAddressString(String fullAddress) {
    final parts = fullAddress.split(' - ');
    return {
      "address": parts.isNotEmpty ? parts[0].trim() : '',
      "area": parts.length > 1 ? parts[1].trim() : '',   // lấy cả tên + code
      "city": parts.length > 2 ? parts[2].trim() : '',
      "prov": parts.length > 3 ? parts[3].trim() : '',
    };
  }

  String _randomString(int len) {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final rnd = Random();
    return String.fromCharCodes(
        Iterable.generate(len, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  String _formatDate(DateTime dt) =>
      "${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}";
  String _formatTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}";

  static Future<Map<String, dynamic>?> checkJTShippingFee({
    required BuildContext context,
    required double weight,
    required String? receiverAddress,
    required Map<String, dynamic>? partnerInfo,
    required double? codMoney,
    required double? goodsValue
  }) async {
    try {
      if (receiverAddress == null || partnerInfo == null) return null;

      // --- Tách địa chỉ nhận ---
      // Ví dụ: "thôn nà ní - Xã Ninh Quới-291HHD04 - Huyện Hồng Dân - Bạc Liêu"
      final parts = receiverAddress.split(" - ");
      if (parts.length < 3) return null;

      final receiverArea = parts[1];  // Xã Ninh Quới-291HHD04
      final receiverCity = parts[2];  // Huyện Hồng Dân
      final receiverProv = parts.last; // Bạc Liêu

      // --- Lấy dữ liệu từ JT_setting (ở partnerInfo) ---
      final customerCode = partnerInfo['customerCode'];
      final key = partnerInfo['key'];
      final goodsType = partnerInfo['goodsType'];
      final productType = partnerInfo['productType'];
      final senderProv = partnerInfo['prov'];
      final senderCity = partnerInfo['city'];
      final senderArea = partnerInfo['area'];

      // --- Password ---
      final rawPass = "$key" "jadada369t3";
      final passMd5 = md5.convert(utf8.encode(rawPass)).toString().toUpperCase();

      // --- BizContent ---
      final bizContent = {
        "customerCode": customerCode,
        "password": passMd5,
        "weight": weight,
        "productType": productType,
        "goodsType": goodsType,
        "goodsValue":goodsValue,
        "codMoney":codMoney,
        "sender": {
          "prov": senderProv,
          "city": senderCity,
          "area": senderArea,
        },
        "receiver": {
          "prov": receiverProv,
          "city": receiverCity,
          "area": receiverArea,
        }
      };

      final bizJson = json.encode(bizContent);

      // --- Digest ---
      final privateKey = dotenv.env['PRIVATE_KEY'] ?? "";
      final digestStr = bizJson + privateKey;
      final digestMd5 = md5.convert(utf8.encode(digestStr));
      final digestBase64 = base64.encode(digestMd5.bytes);

      // --- Headers ---
      final headers = {
        "digest": digestBase64,
        "timestamp": DateTime.now().millisecondsSinceEpoch.toString(),
        "apiAccount": dotenv.env['API_ACCOUNT'] ?? "",
      };

      final url = "https://demoopenapi.jtexpress.vn/webopenplatformapi/api/spmComCost/getComCost";
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: {"bizContent": bizJson},
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        print("Json body ne:$body");
        final data = body['data'];
        if (data != null) {
          final standardTotalFee = (data['standardTotalFee'] ?? 0).toDouble();
          return {
            "standardTotalFee":standardTotalFee,
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint("checkJTShippingFee error: $e");
      return null;
    }
  }
}

