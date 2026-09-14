/**
 * =====================================================================
 *  FAP ATTENDANCE ASSISTANT - GOOGLE APPS SCRIPT BACKEND DATABASE
 *  Dự án: Lab 1 Desktop Application - Môn PRM - Trường Đại học FPT
 *  Hỗ trợ cấu trúc cột: MEMBER, CODE, SURNAME, MIDDLE NAME, GIVEN NAME
 *  Tích hợp AI Analytics: Phân tích Slot nghỉ, Thứ nghỉ, Fail attendance
 * =====================================================================
 */

// Xử lý yêu cầu HTTP GET
function doGet(e) {
  var action = (e && e.parameter && e.parameter.action) ? e.parameter.action : 'test';
  var ss = SpreadsheetApp.getActiveSpreadsheet();

  // 1. Test kết nối
  if (action === 'test') {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      message: 'Kết nối thành công đến Google Sheet Database!',
      sheetName: ss.getName(),
      timestamp: new Date().toISOString()
    })).setMimeType(ContentService.MimeType.JSON);
  }

  // 2. Lấy danh sách sinh viên theo lớp (Cấu trúc: MEMBER, CODE, SURNAME, MIDDLE NAME, GIVEN NAME)
  if (action === 'getStudents') {
    var className = e.parameter.className || 'SE1801';
    var sheet = ss.getSheetByName(className);
    
    // Nếu chưa có sheet cho lớp này, tự động khởi tạo sheet chuẩn
    if (!sheet) {
      sheet = _createSampleClassSheet(ss, className);
    }

    var data = sheet.getDataRange().getValues();
    var students = [];

    // Bỏ qua dòng tiêu đề (index 0)
    for (var i = 1; i < data.length; i++) {
      var row = data[i];
      if (row[0] && row[0].toString().trim() !== '') {
        var member = row[0].toString().trim();
        var code = row[1] ? row[1].toString().trim() : '';
        var surname = row[2] ? row[2].toString().trim() : '';
        var middleName = row[3] ? row[3].toString().trim() : '';
        var givenName = row[4] ? row[4].toString().trim() : '';
        
        // Tạo fullName tự động từ các trường họ tên
        var nameParts = [code, surname, middleName, givenName].filter(function(p) { return p && p.length > 0; });
        var fullName = nameParts.join(' ');
        if (!fullName || fullName.trim() === '') {
          fullName = 'Sinh viên ' + member;
        }

        var totalSlots = row[5] ? parseInt(row[5]) : 20;
        var absentSlots = row[6] ? parseInt(row[6]) : 0;
        var email = row[7] ? row[7].toString().trim() : (member.toLowerCase() + '@fpt.edu.vn');

        students.push({
          member: member,
          rollNumber: member,
          code: code,
          surname: surname,
          middleName: middleName,
          givenName: givenName,
          fullName: fullName,
          email: email,
          className: className,
          totalSlots: totalSlots,
          absentSlots: absentSlots
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

  // 3. Lấy dữ liệu điểm danh theo lớp, ngày, slot
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
        if (r[1] === cName && r[2] === date && parseInt(r[3]) === slot) {
          records.push({
            rollNumber: r[4],
            member: r[4],
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

  // 4. API phân tích chuyên sâu cho AI (AI Analytics Data)
  if (action === 'getAnalyticsData') {
    var targetClass = e.parameter.className || 'SE1801';
    var logSheet = ss.getSheetByName('Attendance_Logs');
    var logs = [];

    if (logSheet) {
      var allLogs = logSheet.getDataRange().getValues();
      for (var m = 1; m < allLogs.length; m++) {
        var l = allLogs[m];
        if (!targetClass || l[1] === targetClass) {
          logs.push({
            timestamp: l[0],
            className: l[1],
            date: l[2],
            slot: parseInt(l[3]),
            rollNumber: l[4],
            status: l[5],
            note: l[6] || ''
          });
        }
      }
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      className: targetClass,
      totalRecords: logs.length,
      logs: logs
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

    // 1. Lưu điểm danh vào bảng Attendance_Logs
    if (action === 'saveAttendance') {
      var className = body.className || 'SE1801';
      var date = body.date;
      var slot = body.slot;
      var records = body.records || [];

      var logSheet = ss.getSheetByName('Attendance_Logs');
      if (!logSheet) {
        logSheet = ss.insertSheet('Attendance_Logs');
        logSheet.appendRow(['Thời gian ghi nhận', 'Lớp', 'Ngày học', 'Slot', 'Mã Sinh Viên (MEMBER)', 'Trạng thái', 'Ghi chú']);
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
          rec.rollNumber || rec.member,
          rec.status,
          rec.note || ''
        ]);
      }

      if (newRows.length > 0) {
        logSheet.getRange(logSheet.getLastRow() + 1, 1, newRows.length, 7).setValues(newRows);
      }

      // Cập nhật số buổi vắng vào sheet lớp
      _updateStudentAbsentCount(ss, className, records);

      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        message: 'Đã lưu ' + records.length + ' bản ghi điểm danh vào Google Sheet!'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // 2. Đồng bộ danh sách sinh viên theo 4-5 trường: MEMBER, CODE, SURNAME, MIDDLE NAME, GIVEN NAME
    if (action === 'syncStudents') {
      var cls = body.className || 'SE1801';
      var students = body.students || [];

      var stdSheet = ss.getSheetByName(cls) || ss.insertSheet(cls);
      stdSheet.clear();

      // Tiêu đề cột chuẩn hóa theo ảnh yêu cầu
      var headers = ['MEMBER', 'CODE', 'SURNAME', 'MIDDLE NAME', 'GIVEN NAME', 'TOTAL SLOTS', 'ABSENT', 'EMAIL'];
      stdSheet.appendRow(headers);
      
      var hRange = stdSheet.getRange(1, 1, 1, headers.length);
      hRange.setBackground('#6366F1'); // Màu xanh tím hiện đại
      hRange.setFontColor('#FFFFFF');
      hRange.setFontWeight('bold');

      var sRows = [];
      for (var k = 0; k < students.length; k++) {
        var st = students[k];
        sRows.push([
          st.member || st.rollNumber,
          st.code || '',
          st.surname || '',
          st.middleName || '',
          st.givenName || '',
          st.totalSlots || 20,
          st.absentSlots || 0,
          st.email || ''
        ]);
      }

      if (sRows.length > 0) {
        stdSheet.getRange(2, 1, sRows.length, headers.length).setValues(sRows);
      }

      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        message: 'Đã cập nhật ' + students.length + ' sinh viên cho lớp ' + cls + ' theo cấu trúc chuẩn!'
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

// Cập nhật số buổi vắng vào sheet lớp
function _updateStudentAbsentCount(ss, className, records) {
  try {
    var sheet = ss.getSheetByName(className);
    if (!sheet) return;

    var data = sheet.getDataRange().getValues();
    for (var i = 0; i < records.length; i++) {
      var r = records[i];
      if (r.status === 'absent') {
        var roll = (r.rollNumber || r.member || '').toUpperCase();
        for (var row = 1; row < data.length; row++) {
          if (data[row][0] && data[row][0].toString().toUpperCase() === roll) {
            var currentAbsent = parseInt(data[row][6]) || 0;
            sheet.getRange(row + 1, 7).setValue(currentAbsent + 1);
            break;
          }
        }
      }
    }
  } catch (_) {}
}

// Tự tạo sheet mẫu cho lớp với cấu trúc theo đúng ảnh
function _createSampleClassSheet(ss, className) {
  var sheet = ss.insertSheet(className);
  var headers = ['MEMBER', 'CODE', 'SURNAME', 'MIDDLE NAME', 'GIVEN NAME', 'TOTAL SLOTS', 'ABSENT', 'EMAIL'];
  sheet.appendRow(headers);

  var hRange = sheet.getRange(1, 1, 1, headers.length);
  hRange.setBackground('#6366F1');
  hRange.setFontColor('#FFFFFF');
  hRange.setFontWeight('bold');

  // Dữ liệu mẫu thực tế, bao gồm CE190585 Lâm Quốc Minh từ ảnh yêu cầu
  var sampleData = [
    ['CE190585', 'Lâm', 'Quốc', 'Minh', '', 20, 1, 'minhlqce190585@fpt.edu.vn'],
    ['SE170123', 'Nguyễn', 'Văn', 'An', '', 20, 2, 'annvse170123@fpt.edu.vn'],
    ['SE170456', 'Trần', 'Thị', 'Bình', '', 20, 0, 'binhttse170456@fpt.edu.vn'],
    ['SE170789', 'Lê', 'Hoàng', 'Cường', '', 20, 3, 'cuonglhse170789@fpt.edu.vn'],
    ['SE171012', 'Phạm', 'Minh', 'Đức', '', 20, 5, 'ducpmse171012@fpt.edu.vn'], // 5/20 = 25% -> FAIL ATTENDANCE (CẤM THI)
    ['SE171345', 'Vũ', 'Hải', 'Đăng', '', 20, 4, 'dangvhse171345@fpt.edu.vn'], // 4/20 = 20% -> FAIL ATTENDANCE (CẤM THI)
    ['HE160234', 'Đỗ', 'Thùy', 'Linh', '', 20, 0, 'linhdthe160234@fpt.edu.vn'],
    ['HE160567', 'Ngô', 'Quốc', 'Nam', '', 20, 1, 'namnqhe160567@fpt.edu.vn'],
    ['IA160890', 'Hoàng', 'Mai', 'Phương', '', 20, 6, 'phuonghmia160890@fpt.edu.vn'] // 6/20 = 30% -> FAIL ATTENDANCE
  ];

  sheet.getRange(2, 1, sampleData.length, headers.length).setValues(sampleData);
  return sheet;
}
