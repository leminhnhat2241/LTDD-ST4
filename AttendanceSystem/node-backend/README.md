# Attendance System - Node.js Backend

Backend API cho hệ thống điểm danh nhân viên sử dụng QR Code, NFC, và Mã nhân viên.

## Tính năng

- ✅ Xác thực JWT
- ✅ Quản lý nhân viên (CRUD)
- ✅ Điểm danh bằng QR Code
- ✅ Điểm danh bằng NFC
- ✅ Điểm danh bằng mã nhân viên
- ✅ Theo dõi thời gian làm việc
- ✅ Báo cáo và thống kê
- ✅ Phân quyền (Admin, Manager, Employee)

## Cấu trúc dự án

```
node-backend/
├── src/
│   ├── config/
│   │   └── database.js          # Cấu hình MongoDB
│   ├── controllers/
│   │   ├── authController.js    # Xử lý đăng nhập/đăng ký
│   │   ├── employeeController.js # Quản lý nhân viên
│   │   └── attendanceController.js # Xử lý điểm danh
│   ├── middleware/
│   │   └── auth.js              # Middleware xác thực
│   ├── models/
│   │   ├── Employee.js          # Schema nhân viên
│   │   └── Attendance.js        # Schema điểm danh
│   ├── routes/
│   │   ├── authRoutes.js        # Routes xác thực
│   │   ├── employeeRoutes.js    # Routes nhân viên
│   │   └── attendanceRoutes.js  # Routes điểm danh
│   └── server.js                # Entry point
├── uploads/                     # Thư mục lưu file upload
├── .env                         # Biến môi trường
├── .gitignore
└── package.json
```

## Cài đặt

1. Cài đặt dependencies:
```bash
npm install
```

2. Cấu hình file `.env`:
```env
PORT=3000
MONGODB_URI=mongodb://localhost:27017/attendance_system
JWT_SECRET=your_jwt_secret_key_change_this_in_production
NODE_ENV=development
```

3. Cài đặt và chạy MongoDB:
- Download MongoDB từ: https://www.mongodb.com/try/download/community
- Hoặc sử dụng MongoDB Atlas (cloud)

## Chạy server

Development mode (với nodemon):
```bash
npm run dev
```

Production mode:
```bash
npm start
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Đăng ký nhân viên mới
- `POST /api/auth/login` - Đăng nhập
- `GET /api/auth/profile` - Lấy thông tin profile (cần token)

### Employees
- `GET /api/employees` - Lấy danh sách nhân viên (Admin/Manager)
- `GET /api/employees/:id` - Lấy thông tin 1 nhân viên
- `PUT /api/employees/:id` - Cập nhật nhân viên (Admin)
- `DELETE /api/employees/:id` - Xóa nhân viên (Admin)
- `POST /api/employees/:id/regenerate-qr` - Tạo lại QR code (Admin)

### Attendance
- `POST /api/attendance/check-in` - Điểm danh vào (Public)
- `POST /api/attendance/check-out` - Điểm danh ra (Public)
- `GET /api/attendance/my-records` - Lấy lịch sử điểm danh của mình
- `GET /api/attendance/today` - Trạng thái điểm danh hôm nay
- `GET /api/attendance/statistics` - Thống kê điểm danh
- `GET /api/attendance` - Lấy tất cả bản ghi (Admin/Manager)

## Ví dụ sử dụng

### 1. Đăng ký nhân viên
```bash
POST /api/auth/register
{
  "employeeId": "NV001",
  "fullName": "Nguyễn Văn A",
  "email": "nva@company.com",
  "password": "123456",
  "phone": "0123456789",
  "department": "IT",
  "position": "Developer",
  "role": "employee"
}
```

### 2. Đăng nhập
```bash
POST /api/auth/login
{
  "email": "nva@company.com",
  "password": "123456"
}
```

### 3. Điểm danh bằng QR Code
```bash
POST /api/attendance/check-in
{
  "employeeId": "NV001",
  "method": "qr",
  "location": {
    "latitude": 10.762622,
    "longitude": 106.660172,
    "address": "123 Nguyễn Huệ, Q1, TP.HCM"
  }
}
```

### 4. Điểm danh bằng NFC
```bash
POST /api/attendance/check-in
{
  "nfcId": "ABC123XYZ",
  "method": "nfc",
  "location": {
    "latitude": 10.762622,
    "longitude": 106.660172
  }
}
```

## Models

### Employee Schema
- employeeId (String, unique)
- fullName (String)
- email (String, unique)
- password (String, hashed)
- phone (String)
- department (String)
- position (String)
- role (admin/manager/employee)
- avatar (String)
- qrCode (String)
- nfcId (String, unique)
- isActive (Boolean)

### Attendance Schema
- employee (ObjectId, ref Employee)
- employeeId (String)
- checkInTime (Date)
- checkOutTime (Date)
- checkInMethod (qr/nfc/manual/employee_id)
- checkOutMethod (qr/nfc/manual/employee_id)
- checkInLocation (Object)
- checkOutLocation (Object)
- workDuration (Number, minutes)
- status (on-time/late/early-leave/absent)
- date (String, YYYY-MM-DD)

## Bảo mật

- Passwords được hash bằng bcryptjs
- JWT tokens để xác thực
- Middleware kiểm tra quyền truy cập
- CORS được cấu hình

## License

ISC
