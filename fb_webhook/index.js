const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// 👇 Route để Facebook xác minh webhook
app.get('/webhook', (req, res) => {
  const VERIFY_TOKEN = "webhook_live";

  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode && token === VERIFY_TOKEN) {
    console.log('✅ Webhook xác minh thành công');
    res.status(200).send(challenge);
  } else {
    console.log('❌ Xác minh webhook thất bại');
    res.sendStatus(403);
  }
});

// 👇 Route để nhận message từ Facebook (kiểu POST)
app.post('/webhook', (req, res) => {
  console.log('📩 Nhận webhook:', JSON.stringify(req.body, null, 2));
  res.sendStatus(200);
});

app.listen(PORT, () => {
  console.log(`🚀 Server đang chạy tại cổng ${PORT}`);
});
