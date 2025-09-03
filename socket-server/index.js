
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const app = express();
const server = http.createServer(app);

// 🔥 Khởi tạo socket.io
const io = new Server(server, {
  cors: {
    origin: "*", // cho phép tất cả (test)
  },
});

io.on("connection", (socket) => {
  console.log("✅ Client connected:", socket.id);

  socket.on("disconnect", () => {
    console.log("❌ Client disconnected:", socket.id);
  });
});

// ✅ Webhook Facebook (GET để verify)
app.get("/fbWebhook", (req, res) => {
  const VERIFY_TOKEN = process.env.FB_VERIFY_TOKEN;
  const mode = req.query["hub.mode"];
  const token = req.query["hub.verify_token"];
  const challenge = req.query["hub.challenge"];

  console.log("🕵️‍♀️ Verification attempt received:");
  console.log(`- Mode: ${mode}`);
  console.log(`- Received Token: ${token}`);
  console.log(`- Expected Token: ${VERIFY_TOKEN}`);

  if (mode && token && mode === "subscribe" && token === VERIFY_TOKEN) {
    console.log("✅ Webhook verified successfully");
    res.status(200).send(challenge);
  } else {
    // THÊM LOG LỖI VÀO ĐÂY
    console.error("❌ Webhook verification failed!");
    res.sendStatus(403);
  }
});
// ✅ Webhook Facebook (POST để nhận event)
// ✅ Webhook Facebook (POST để nhận event) - PHIÊN BẢN ĐÃ SỬA LỖI
app.post("/fbWebhook", express.json(), (req, res) => {
  const body = req.body;
  // Ghi lại toàn bộ payload nhận được để dễ dàng debug
  console.log("📩 Webhook received:", JSON.stringify(body, null, 2));

  try {
    if (body.object === "page") {
      for (const entry of body.entry) {
        const changes = entry.changes || [];
        for (const change of changes) {
          console.log(`Processing change with field: "${change.field}"`);

          let commentData = null;

          // ⭐ LOGIC MỚI: Xử lý cho cả livestream và bài viết thường
          if (change.field === 'live_videos') {
            // Đây là sự kiện từ Livestream
            // Thường thì comment_id sẽ nằm trong value
            console.log("Detected live_video change.");
            commentData = change.value;
          } else if (change.field === 'feed' && change.value?.item === 'comment') {
            // Đây là sự kiện từ bài viết thường
            console.log("Detected feed comment change.");
            commentData = change.value;
          }

          // Nếu đã xác định được có dữ liệu comment
          if (commentData) {
            console.log("💬 Emitting new_comment event with data:", commentData);
            // Gửi xuống client qua socket.io
            io.emit("new_comment", commentData);
          } else {
            console.log("Change did not contain relevant comment data. Skipping.");
          }
        }
      }
    }
    // Luôn trả về 200 OK để Facebook biết bạn đã nhận được
    res.sendStatus(200);
  } catch (err) {
    console.error("❌ Error processing webhook:", err);
    res.sendStatus(500); // Báo lỗi server nếu có vấn đề
}
});

// 🚀 Cloud Run yêu cầu listen đúng cổng PORT
console.log("PORT from env:", process.env.PORT);
const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
console.log(`🚀 Server is running on port ${PORT}`);
});
