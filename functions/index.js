/**
 * 📌 index.js
 * Cloud Functions Gen 2 với PubSub Schedule
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
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
});
exports.facebookWebhook = onRequest((req, res) => {
  if (req.method === 'GET') {
    // Dùng để xác minh webhook với Facebook
    const VERIFY_TOKEN = 'webhook_comment_fb'; // 👉 bạn tự đặt
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode && token === VERIFY_TOKEN) {
      console.log('📥 Webhook verified!');
      res.status(200).send(challenge);
    } else {
      res.sendStatus(403);
    }
  }

  if (req.method === 'POST') {
    const body = req.body;

    console.log('📥 Nhận webhook từ Facebook:', JSON.stringify(body, null, 2));

    // TODO: Xử lý comment ở đây (ví dụ: lưu vào Firestore hoặc gửi thông báo...)
    res.status(200).send('EVENT_RECEIVED');
  }
});

