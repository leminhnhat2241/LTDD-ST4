# MÔ TẢ NGHIỆP VỤ  
## HỆ THỐNG ĐIỂM DANH NHÂN VIÊN CHO DOANH NGHIỆP SME

---

## 1. Mục tiêu nghiệp vụ

Hệ thống được xây dựng nhằm:
- Tự động hóa quy trình **check-in / check-out** của nhân viên
- Giảm gian lận điểm danh hộ
- Phù hợp với doanh nghiệp **quy mô nhỏ và vừa**
- Giảm chi phí triển khai (chỉ cần 1 thiết bị trung tâm)
- Dễ quản lý, dễ mở rộng

---

## 2. Phạm vi áp dụng

- Áp dụng cho doanh nghiệp có:
  - 1 hoặc nhiều phòng ban
  - Ca hành chính hoặc ca linh hoạt
- Điểm danh tập trung tại:
  - Cửa ra vào
  - Quầy lễ tân
  - Khu vực chung

---

## 3. Mô hình vận hành tổng thể

Hệ thống sử dụng **một thiết bị di động trung tâm** (Android) được đặt cố định tại nơi làm việc để thực hiện điểm danh cho toàn bộ nhân viên.

Thiết bị này hoạt động với **vai trò riêng biệt (Attendance Device)**, không đại diện cho cá nhân nào và chỉ thực hiện chức năng điểm danh.

---

## 4. Các vai trò trong hệ thống

### 4.1. Attendance Device (Thiết bị điểm danh)

- Là thiết bị trung tâm thực hiện:
  - Đọc thẻ NFC
  - Quét mã QR
- Không có quyền truy cập dữ liệu quản lý
- Chỉ gửi yêu cầu điểm danh đến hệ thống backend

---

### 4.2. Employee (Nhân viên)

- Là người lao động trong công ty
- Không trực tiếp thao tác trên thiết bị điểm danh
- Sử dụng tài khoản cá nhân để:
  - Xem lịch sử điểm danh của chính mình
  - Theo dõi ca làm việc
  - Gửi yêu cầu chỉnh sửa điểm danh khi cần

---

### 4.3. Manager (Quản lý)

- Quản lý một hoặc nhiều phòng ban
- Có quyền:
  - Theo dõi tình trạng điểm danh của nhân viên thuộc quyền
  - Phê duyệt hoặc từ chối các yêu cầu chỉnh sửa điểm danh
  - Xem báo cáo điểm danh theo nhóm

---

### 4.4. Admin (Quản trị hệ thống)

- Quản lý toàn bộ hệ thống
- Thiết lập cấu hình và chính sách điểm danh
- Quản lý người dùng, phòng ban, ca làm
- Quản lý thiết bị điểm danh và phương thức xác thực

---

## 5. Quy trình nghiệp vụ điểm danh (Check-in)

### Bước 1: Nhân viên đến nơi làm việc
- Nhân viên đến văn phòng trong thời gian làm việc
- Thiết bị điểm danh hiển thị trạng thái sẵn sàng

---

### Bước 2: Điểm danh bằng NFC (ưu tiên)
- Nhân viên đưa thẻ NFC cá nhân lại gần thiết bị
- Thiết bị đọc UID từ thẻ và gửi lên hệ thống

**Trường hợp hợp lệ:**
- Hệ thống xác định nhân viên
- Ghi nhận thời gian check-in
- Hiển thị kết quả thành công
---

### Bước 3: Điểm danh bằng QR Code (dự phòng)
- Nếu NFC không hoạt động hoặc không đọc được
- Thiết bị tự động chuyển sang chế độ quét QR
- Nhân viên đưa mã QR cá nhân hoặc QR do hệ thống cấp

**Trường hợp hợp lệ:**
- Hệ thống xác thực QR
- Ghi nhận check-in
- Ghi log phương thức dự phòng

---

### Bước 4: Phương án cuối (manual / fallback)
- Trong trường hợp cả NFC và QR đều không khả dụng
- Nhân viên có thể:
  - Nhập mã nhân viên
  - Nhờ quản lý xác nhận thủ công
- Hệ thống ghi nhận với trạng thái đặc biệt để kiểm soát

---

## 6. Quy trình nghiệp vụ điểm danh ra về (Check-out)

- Quy trình tương tự check-in
- Hệ thống kiểm tra:
  - Nhân viên đã check-in chưa
  - Tránh check-out trùng lặp
- Ghi nhận thời gian kết thúc ca làm

---

## 7. Quản lý và giám sát điểm danh

### Đối với Nhân viên
- Theo dõi lịch sử điểm danh cá nhân
- Biết được tình trạng đi muộn, về sớm

### Đối với Quản lý
- Theo dõi tình trạng điểm danh theo thời gian thực
- Phát hiện nhân viên chưa check-in
- Phê duyệt yêu cầu điều chỉnh

### Đối với Admin
- Tổng hợp dữ liệu toàn hệ thống
- Xuất báo cáo theo ngày/tháng
- Cấu hình chính sách điểm danh

---

## 8. Kiểm soát và bảo mật nghiệp vụ

- Mỗi lượt điểm danh được ghi nhận:
  - Thời gian
  - Thiết bị
  - Phương thức (NFC / QR / Manual)
- QR Code có thời hạn sử dụng
- Thẻ NFC có thể bị vô hiệu hóa khi cần
- Phân quyền rõ ràng giữa các vai trò

---

## 9. Giá trị mang lại cho doanh nghiệp

- Tăng tính minh bạch trong quản lý thời gian làm việc
- Giảm gian lận và sai sót thủ công
- Tiết kiệm chi phí đầu tư thiết bị
- Phù hợp với doanh nghiệp SME

---

## 10. Kết luận

Hệ thống điểm danh được thiết kế theo mô hình  
**thiết bị trung tâm + đa phương thức xác thực**,  
đáp ứng tốt nhu cầu vận hành của doanh nghiệp nhỏ và vừa,  
đồng thời đảm bảo tính linh hoạt, bảo mật và khả năng mở rộng trong tương lai.
