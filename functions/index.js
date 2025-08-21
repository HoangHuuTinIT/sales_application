/**
 * 📌 index.js
 * Cloud Functions Gen 2 với PubSub Schedule
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
require('dotenv').config();
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY); // 🔑 Thay bằng secret key thật của bạn

initializeApp(); // ✅ Gọi 1 lần duy nhất ở đầu file

// 🕒 Tự động cập nhật đơn hàng
exports.autoUpdateOrderStatus = onSchedule(
  {
    schedule: 'every 24 hours',
    timeZone: 'Asia/Ho_Chi_Minh',
  },
  async (event) => {
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

// 💳 Stripe PaymentIntent API
exports.createPaymentIntent = onRequest(async (req, res) => {
  try {
    const { amount } = req.body;

    const customer = await stripe.customers.create();

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customer.id },
      { apiVersion: '2024-04-10' }
    );

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: 'vnd',
      customer: customer.id,
      automatic_payment_methods: { enabled: true },
    });

    res.send({
      clientSecret: paymentIntent.client_secret,
      customer: customer.id,
      ephemeralKey: ephemeralKey.secret,
    });
  } catch (err) {
    console.error('❌ Stripe error:', err);
    res.status(500).send({ error: err.message });
  }
}
);

// 📦 Webhook J&T

const querystring = require("querystring");

exports.jtWebhook = onRequest(async (req, res) => {
  try {
    const db = getFirestore();

    // Parse x-www-form-urlencoded
    const parsedBody = querystring.parse(req.rawBody.toString());

    // bizContent là JSON string trong body
    const bizContent = JSON.parse(parsedBody.bizContent);

    const billCode = bizContent.billCode;
    const details = bizContent.details || [];

    if (!billCode) {
      return res.status(400).json({ code: "0", msg: "Missing billCode", data: null });
    }

    // Lấy bản ghi Order có billCode trùng
    const snapshot = await db
      .collection("Order")
      .where("billCode", "==", billCode)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      const orderDoc = snapshot.docs[0];

      // Chỉ cập nhật status từ scanTypeName mới nhất
      const latestStatus = details.length > 0 ? details[details.length - 1].scanTypeName : "Chưa có thông tin";

      await orderDoc.ref.update({ status: latestStatus });

      console.log(`✅ Updated Order ${billCode} status to: ${latestStatus}`);
    } else {
      console.log(`⚠️ Không tìm thấy Order với billCode: ${billCode}`);
    }

    // Trả về cho J&T theo đúng yêu cầu
    res.status(200).json({ code: "1", msg: "success", data: null });

  } catch (err) {
    console.error("❌ Webhook error:", err);
    res.status(500).json({ code: "0", msg: err.message, data: null });
  }
});



