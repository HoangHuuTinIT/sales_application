
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
app.post("/fbWebhook", express.json(), (req, res) => {
  const body = req.body;
  console.log("📩 Webhook received:", JSON.stringify(body, null, 2));
  try {
    if (body.object === "page") {
      for (const entry of body.entry) {
        const changes = entry.changes || [];
        for (const change of changes) {

          // ⭐ LOGIC ĐÚNG: Chỉ cần tập trung vào "feed" cho cả bài viết thường và livestream
          if (change.field === 'feed') {
            const feedEvent = change.value;

            // Kiểm tra xem đây có phải là một bình luận MỚI không
            if (feedEvent && feedEvent.item === 'comment' && feedEvent.verb === 'add') {
              console.log("💬 Emitting new_comment event with data:", feedEvent);
              // Gửi dữ liệu bình luận xuống client qua socket.io
              io.emit("new_comment", feedEvent);
            } else {
              // Ghi log các sự kiện khác trong feed để debug (ví dụ: like, edit comment, new post)
              console.log(`Skipping feed event: item='${feedEvent.item}', verb='${feedEvent.verb}'`);
            }
          }
          // Không cần xử lý 'live_videos' để lấy comment
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
