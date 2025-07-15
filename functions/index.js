/**
 * 📌 index.js
 * Cloud Functions Gen 2 với PubSub Schedule
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

// ✅ Khởi tạo Admin SDK bên trong function
exports.autoUpdateOrderStatus = onSchedule(
  {
    schedule: 'every 24 hours',
    timeZone: 'Asia/Ho_Chi_Minh',
  },
  async (event) => {
    // 👇 Initialize App bên trong
    initializeApp();

    const db = getFirestore();
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const snapshot = await db
      .collection('OrderedProducts')
      .where('status', '==', 'Đang chờ xác nhận')
      .where('createdAt', '<=', Timestamp.fromDate(oneDayAgo))
      .get();

    if (snapshot.empty) {
      console.log('✅ Không có đơn hàng nào cần cập nhật.');
      return null;
    }

    const batch = db.batch();
    snapshot.forEach((doc) => {
      batch.update(doc.ref, { status: 'Đã xác nhận' });
    });

    await batch.commit();
    console.log(`✅ Đã cập nhật ${snapshot.size} đơn hàng.`);

    return null;
  }
);
