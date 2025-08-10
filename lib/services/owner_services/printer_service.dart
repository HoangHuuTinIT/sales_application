import 'package:cloud_firestore/cloud_firestore.dart';

class PrinterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  PrinterService(this.userId);

  CollectionReference get _printerCollection =>
      _firestore.collection('printer');

  Stream<QuerySnapshot> streamPrinters() {
    return _printerCollection.where('id_user_setting_printer', isEqualTo: userId).snapshots();
  }

  Future<void> addPrinter({
    required String namePrinter,
    required String ip,
    required int port,
  }) async {
    // Kiểm tra xem user đã có máy in nào chưa
    final existingPrinters = await _printerCollection
        .where('id_user_setting_printer', isEqualTo: userId)
        .get();

    final isDefault = existingPrinters.docs.isEmpty;

    final doc = _printerCollection.doc();
    await doc.set({
      'name_printer': namePrinter,
      'IP': ip,
      'Port': port,
      'id_user_setting_printer': userId,
      'default': isDefault, // mặc định true nếu chưa có máy in nào
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePrinter({
    required String id,
    required String namePrinter,
    required String ip,
    required int port,
  }) async {
    await _printerCollection.doc(id).update({
      'name_printer': namePrinter,
      'IP': ip,
      'Port': port,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePrinter(String id) async {
    await _printerCollection.doc(id).delete();
  }

  Future<void> setDefaultPrinter(String id) async {
    // 1. Lấy tất cả máy in của user
    final printersSnapshot = await _printerCollection
        .where('id_user_setting_printer', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();

    for (var doc in printersSnapshot.docs) {
      final isDefault = doc.id == id;
      batch.update(doc.reference, {'default': isDefault});
    }

    await batch.commit();
  }

  Future<Map<String, dynamic>?> getDefaultPrinter() async {
    final query = await _printerCollection
        .where('id_user_setting_printer', isEqualTo: userId)
        .where('default', isEqualTo: true)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.data() as Map<String, dynamic>;
    }
    return null;
  }

  // Kiểm tra xem có máy in mặc định không
  Future<bool> hasDefaultPrinter() async {
    final defaultPrinter = await getDefaultPrinter();
    return defaultPrinter != null;
  }

  Future<Map<String, dynamic>?> getDefaultPrinterForBill() async {
    final query = await _printerCollection
        .where('id_user_setting_printer', isEqualTo: userId)
        .where('default', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data() as Map<String, dynamic>;
    }
    return null;
  }


}
