# PRM Lab 1: Desktop Application - Hỗ trợ Điểm Danh FAP (Google Sheet DB)

Ứng dụng **Flutter Desktop (Windows)** phục vụ bài tập **Lab 1 môn PRM (FPT University)** với đề tài: **Hỗ trợ điểm danh sinh viên kết nối cổng FAP và sử dụng Google Sheet làm Database**.

---

## 🌟 Tính Năng Nổi Bật

1. **Giao diện Desktop hiện đại (Material 3 & FPT Branding):**
   - Thanh điều hướng Sidebar chuẩn Desktop với tone màu cam FPT (`#F36F21`) và Navy (`#0F172A`).
   - Tối ưu kích thước màn hình máy tính, hiển thị danh sách sinh viên trực quan dạng bảng.
2. **Google Sheet làm Database:**
   - Kết nối với Google Sheet thông qua **Google Apps Script Web App REST API**.
   - Miễn phí 100%, bảo mật, không cần cấu hình Google Cloud Console phức tạp.
   - Lưu trữ theo thời gian thực lịch sử điểm danh (`Attendance_Logs`) và danh sách sinh viên theo lớp.
3. **Kết nối & Đồng bộ với cổng FAP (fap.fpt.edu.vn):**
   - **Nhập dữ liệu từ FAP:** Dán mã nguồn HTML bảng điểm danh hoặc text từ FAP để tự động bóc tách Mã SV (SE..., HE...), Họ tên, Email.
   - **Tự động điền điểm danh lên FAP (FAP Auto-fill Bridge):** Ứng dụng tự động sinh mã Script JavaScript để người dùng chỉ cần dán vào F12 Console hoặc Bookmarklet của trang FAP, hệ thống sẽ tự động tick chọn toàn bộ các radio button Present/Absent tương ứng và tô màu highlight.
4. **Cảnh báo chuyên cần theo Quy chế FPT:**
   - Tự động tính tỷ lệ vắng của từng sinh viên.
   - Hiển thị badge cảnh báo cho sinh viên vắng từ **15% đến 20%**.
   - Cảnh báo **CẤM THI** khi sinh viên vắng **>= 20%** tổng số slot học.
5. **Chế độ Ngoại tuyến (Offline Mode):**
   - Lưu trữ cấu hình và bộ nhớ đệm (Cache) cục bộ bằng file JSON thuần (`dart:io`), tự động fallback dữ liệu mẫu khi chưa cấu hình Google Sheet.

---

## 📁 Cấu Trúc Mã Nguồn

```
LAB 1 - PRM/
├── lib/
│   ├── models/
│   │   ├── student.dart            # Model Sinh viên FPT & logic tính % vắng
│   │   ├── attendance_record.dart  # Model Bản ghi điểm danh & Enum trạng thái
│   │   └── class_session.dart      # Model Buổi học & Thông tin Slot (1-6)
│   ├── services/
│   │   ├── google_sheet_service.dart # Giao tiếp REST API với Google Apps Script
│   │   ├── fap_service.dart        # Parser dữ liệu FAP & sinh script auto-fill
│   │   └── storage_service.dart    # Lưu trữ cài đặt & cache offline
│   ├── screens/
│   │   ├── main_desktop_screen.dart # Container điều hướng Sidebar chính
│   │   ├── dashboard_view.dart     # Bảng điều khiển tổng quan & cảnh báo
│   │   ├── attendance_view.dart    # Bảng điểm danh, chọn Slot, ngày, lớp
│   │   ├── students_view.dart      # Quản lý danh sách sinh viên theo lớp
│   │   ├── reports_view.dart       # Báo cáo chuyên cần cả kỳ
│   │   └── settings_view.dart      # Cấu hình URL Google Sheet & mã Apps Script
│   ├── widgets/
│   │   ├── status_badge.dart       # Badge hiển thị trạng thái điểm danh & cấm thi
│   │   ├── fap_sync_dialog.dart    # Dialog sinh script FAP 1-click
│   │   └── import_fap_dialog.dart  # Dialog nhập danh sách từ FAP
│   └── main.dart                   # Entry point của ứng dụng Desktop
├── google-apps-script/
│   └── Code.gs                     # Mã nguồn backend chạy trên Google Sheet
├── test/
│   └── widget_test.dart            # Unit tests và widget tests
└── pubspec.yaml                    # Cấu hình dependencies
```

---

## 🚀 Hướng Dẫn Chạy Ứng Dụng

### 1. Khởi chạy trên Windows Desktop
Mở terminal PowerShell trong thư mục này và chạy:
```powershell
flutter run -d windows
```

### 2. Kiểm tra chất lượng mã nguồn & Unit Tests
```powershell
flutter analyze
flutter test
```

---

## 📊 Hướng Dẫn Thiết Lập Google Sheet DB (1 Phút)

1. Mở trang Google Sheet mới tại: [https://sheet.new](https://sheet.new)
2. Trên thanh menu, chọn: **Tiện ích mở rộng (Extensions)** > **Apps Script**.
3. Xóa code có sẵn, mở file `google-apps-script/Code.gs` và copy toàn bộ nội dung dán vào.
4. Bấm **Lưu (Ctrl + S)**.
5. Bấm nút **Triển khai (Deploy)** ở góc trên bên phải > chọn **Tùy chọn triển khai mới (New deployment)**:
   - Loại: **Ứng dụng web (Web app)**
   - Mô tả: `PRM FAP Attendance DB`
   - Thực thi dưới dạng: **Tôi (Me)**
   - Ai có quyền truy cập: **Bất kỳ ai (Anyone)** *(Bắt buộc để Desktop App kết nối được)*
6. Bấm **Triển khai (Deploy)** > Cấp quyền tài khoản Google > Sao chép **URL ứng dụng web**.
7. Mở ứng dụng Desktop > Vào mục **Cài đặt kết nối DB** > Dán URL vào và bấm **Kiểm tra & Lưu**.
