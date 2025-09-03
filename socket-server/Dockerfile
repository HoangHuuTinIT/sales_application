# Sử dụng Node.js 18 (hoặc 20)
FROM node:18

# Set thư mục làm việc
WORKDIR /usr/src/app

# Copy file package.json và package-lock.json
COPY package*.json ./

# Cài dependencies
RUN npm install

# Copy toàn bộ code
COPY . .

# Expose port 8080 (Cloud Run mặc định)
EXPOSE 8080

# Chạy server
CMD ["node", "index.js"]
