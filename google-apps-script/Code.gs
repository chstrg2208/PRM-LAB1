/**
 * =====================================================================
 *  FAP ATTENDANCE ASSISTANT - GOOGLE APPS SCRIPT BACKEND DATABASE
 *  Dự án: Lab 1 Desktop Application - Môn PRM - Trường Đại học FPT
 * =====================================================================
 * 
 * HƯỚNG DẪN TRIỂN KHAI NHANH TRONG 1 PHÚT:
 * 1. Mở Google Sheets mới tại: https://sheet.new
 * 2. Trên menu chọn: Tiện ích mở rộng (Extensions) > Apps Script
 * 3. Xóa code mặc định, dán toàn bộ file này vào và bấm Ctrl + S để lưu
 * 4. Bấm nút "Triển khai" (Deploy) ở góc trên bên phải > Chọn "Tùy chọn triển khai mới" (New deployment)
 * 5. Chọn loại: "Ứng dụng web" (Web app)
 *    - Mô tả: "PRM FAP Attendance DB"
 *    - Thực thi dưới dạng (Execute as): "Tôi" (Me)
 *    - Ai có quyền truy cập (Who has access): "Bất kỳ ai" (Anyone)  <-- BẮT BUỘC để Desktop App gọi được API
 * 6. Bấm "Triển khai" (Deploy) > Cấp quyền truy cập Google Account
 * 7. Sao chép "URL ứng dụng web" (Web app URL) và dán vào mục Cài đặt trong PRM Desktop App!
 */

// Xử lý yêu cầu HTTP GET
function doGet(e) {
  var action = (e && e.parameter && e.parameter.action) ? e.parameter.action : 'test';
  var ss = SpreadsheetApp.getActiveSpreadsheet();

  // Test kết nối
  if (action === 'test') {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      message: 'Kết nối thành công đến Google Sheet Database!',
      sheetName: ss.getName(),
      timestamp: new Date().toISOString()
    })).setMimeType(ContentService.MimeType.JSON);
  }

  // Lấy danh sách sinh viên theo lớp
  if (action === 'getStudents') {
    var className = e.parameter.className || 'SE1801';
    var sheet = ss.getSheetByName(className);
    
    // Nếu chưa có sheet cho lớp này, tự tạo mẫu
    if (!sheet) {
      sheet = _createSampleClassSheet(ss, className);
    }

    var data = sheet.getDataRange().getValues();
    var students = [];

    for (var i = 1; i < data.length; i++) {
      var row = data[i];
      if (row[0] && row[0].toString().trim() !== '') {
        students.push({
          rollNumber: row[0].toString().trim(),
          fullName: row[1] ? row[1].toString().trim() : '',
          email: row[2] ? row[2].toString().trim() : '',
          className: className,
          totalSlots: row[3] ? parseInt(row[3]) : 20,
          absentSlots: row[4] ? parseInt(row[4]) : 0
        });
      }
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      className: className,
      total: students.length,
      data: students
    })).setMimeType(ContentService.MimeType.JSON);
  }

  // Lấy lịch sử điểm danh theo buổi
  if (action === 'getAttendance') {
    var cName = e.parameter.className || 'SE1801';
    var date = e.parameter.date || '';
    var slot = e.parameter.slot ? parseInt(e.parameter.slot) : 1;

    var logSheet = ss.getSheetByName('Attendance_Logs');
    var records = [];

    if (logSheet) {
      var logData = logSheet.getDataRange().getValues();
      for (var j = 1; j < logData.length; j++) {
        var r = logData[j];
        // Cột: [0] Timestamp, [1] Lớp, [2] Ngày, [3] Slot, [4] RollNumber, [5] Status, [6] Note
        if (r[1] === cName && r[2] === date && parseInt(r[3]) === slot) {
          records.push({
            rollNumber: r[4],
            className: cName,
            date: date,
            slot: slot,
            status: r[5],
            note: r[6] || ''
          });
        }
      }
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      data: records
    })).setMimeType(ContentService.MimeType.JSON);
  }

  return ContentService.createTextOutput(JSON.stringify({
    status: 'error',
    message: 'Yêu cầu GET không hợp lệ!'
  })).setMimeType(ContentService.MimeType.JSON);
}

// Xử lý yêu cầu HTTP POST
function doPost(e) {
  try {
    var contents = e.postData.contents;
    var body = JSON.parse(contents);
    var action = body.action;
    var ss = SpreadsheetApp.getActiveSpreadsheet();

    // 1. Lưu điểm danh
    if (action === 'saveAttendance') {
      var className = body.className || 'SE1801';
      var date = body.date;
      var slot = body.slot;
      var records = body.records || [];

      var logSheet = ss.getSheetByName('Attendance_Logs');
      if (!logSheet) {
        logSheet = ss.insertSheet('Attendance_Logs');
        logSheet.appendRow(['Thời gian ghi nhận', 'Lớp', 'Ngày học', 'Slot', 'Mã Sinh Viên', 'Trạng thái', 'Ghi chú']);
        var headerRange = logSheet.getRange(1, 1, 1, 7);
        headerRange.setBackground('#F36F21');
        headerRange.setFontColor('#FFFFFF');
        headerRange.setFontWeight('bold');
      }

      var now = new Date();
      var newRows = [];
      for (var i = 0; i < records.length; i++) {
        var rec = records[i];
        newRows.push([
          now,
          className,
          date,
          slot,
          rec.rollNumber,
          rec.status,
          rec.note || ''
        ]);
      }

      if (newRows.length > 0) {
        logSheet.getRange(logSheet.getLastRow() + 1, 1, newRows.length, 7).setValues(newRows);
      }

      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        message: 'Đã lưu thành công ' + records.length + ' bản ghi điểm danh vào Google Sheet!'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // 2. Đồng bộ danh sách sinh viên
    if (action === 'syncStudents') {
      var cls = body.className || 'SE1801';
      var students = body.students || [];

      var stdSheet = ss.getSheetByName(cls) || ss.insertSheet(cls);
      stdSheet.clear();

      stdSheet.appendRow(['Mã SV', 'Họ và tên', 'Email', 'Tổng Slot', 'Vắng']);
      var hRange = stdSheet.getRange(1, 1, 1, 5);
      hRange.setBackground('#2563EB');
      hRange.setFontColor('#FFFFFF');
      hRange.setFontWeight('bold');

      var sRows = [];
      for (var k = 0; k < students.length; k++) {
        var st = students[k];
        sRows.push([
          st.rollNumber,
          st.fullName,
          st.email,
          st.totalSlots || 20,
          st.absentSlots || 0
        ]);
      }

      if (sRows.length > 0) {
        stdSheet.getRange(2, 1, sRows.length, 5).setValues(sRows);
      }

      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        message: 'Đã cập nhật ' + students.length + ' sinh viên cho lớp ' + cls
      })).setMimeType(ContentService.MimeType.JSON);
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: 'Hành động không xác định: ' + action
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: 'Lỗi xử lý POST: ' + err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// Hàm khởi tạo sheet sinh viên mẫu
function _createSampleClassSheet(ss, className) {
  var sheet = ss.insertSheet(className);
  sheet.appendRow(['Mã SV', 'Họ và tên', 'Email', 'Tổng Slot', 'Vắng']);
  var hRange = sheet.getRange(1, 1, 1, 5);
  hRange.setBackground('#2563EB');
  hRange.setFontColor('#FFFFFF');
  hRange.setFontWeight('bold');

  var sampleData = [
    ['SE170123', 'Nguyễn Văn An', 'annvse170123@fpt.edu.vn', 20, 1],
    ['SE170456', 'Trần Thị Bình', 'binhttse170456@fpt.edu.vn', 20, 0],
    ['SE170789', 'Lê Hoàng Cường', 'cuonglhse170789@fpt.edu.vn', 20, 3],
    ['SE171012', 'Phạm Minh Đức', 'ducpmse171012@fpt.edu.vn', 20, 4],
    ['SE171345', 'Vũ Hải Đăng', 'dangvhse171345@fpt.edu.vn', 20, 2],
    ['HE160234', 'Đỗ Thùy Linh', 'linhdthe160234@fpt.edu.vn', 20, 0],
    ['HE160567', 'Ngô Quốc Nam', 'namnqhe160567@fpt.edu.vn', 20, 1],
    ['IA160890', 'Hoàng Mai Phương', 'phuonghmia160890@fpt.edu.vn', 20, 5]
  ];

  sheet.getRange(2, 1, sampleData.length, 5).setValues(sampleData);
  return sheet;
}
