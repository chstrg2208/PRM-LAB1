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
        var nameParts = [surname, middleName, givenName].map(function(p) { return p ? p.trim() : ''; }).filter(function(p) { return p.length > 0; });
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

  // 5. Lấy danh sách lớp hợp lệ từ danh sách các Sheet thực tế trong Spreadsheet
  if (action === 'getClasses') {
    try {
      var sheets = ss.getSheets();
      var classes = [];
      var seen = {};

      for (var k = 0; k < sheets.length; k++) {
        var sheetItem = sheets[k];
        // Bỏ qua sheet bị ẩn
        if (typeof sheetItem.isSheetHidden === 'function' && sheetItem.isSheetHidden()) {
          continue;
        }

        var sheetName = sheetItem.getName() ? sheetItem.getName().trim() : '';
        if (!sheetName) continue;

        // Loại trừ sheet hệ thống / log / metadata
        var lowerName = sheetName.toLowerCase();
        if (lowerName === 'attendance_logs' || sheetName.indexOf('_') === 0 || sheetName.indexOf('.') === 0) {
          continue;
        }

        if (!seen[sheetName]) {
          seen[sheetName] = true;
          classes.push(sheetName);
        }
      }

      // Sắp xếp tăng dần theo thứ tự chữ cái (A-Z, tự nhiên)
      classes.sort(function(a, b) {
        return a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' });
      });

      return ContentService.createTextOutput(JSON.stringify({
        success: true,
        status: 'success',
        total: classes.length,
        data: classes
      })).setMimeType(ContentService.MimeType.JSON);
    } catch (err) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        status: 'error',
        error: 'Lỗi khi lấy danh sách lớp: ' + (err.message || err.toString()),
        message: 'Lỗi khi lấy danh sách lớp: ' + (err.message || err.toString())
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }

  return ContentService.createTextOutput(JSON.stringify({
    status: 'error',
    message: 'Yêu cầu GET không hợp lệ!'
  })).setMimeType(ContentService.MimeType.JSON);
}

// Xử lý yêu cầu HTTP POST
function doPost(e) {
  var lock = LockService.getScriptLock();
  var hasLock = false;

  try {
    // 1. Chống xung đột đồng thời bằng ScriptLock (timeout 30 giây)
    hasLock = lock.tryLock(30000);
    if (!hasLock) {
      return ContentService.createTextOutput(JSON.stringify({
        status: 'error',
        message: 'Hệ thống đang bận xử lý yêu cầu khác, vui lòng thử lại sau giây lát!'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    if (!e || !e.postData || !e.postData.contents) {
      return ContentService.createTextOutput(JSON.stringify({
        status: 'error',
        message: 'Dữ liệu yêu cầu rỗng!'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    var contents = e.postData.contents;
    var body = JSON.parse(contents);
    var action = body.action;
    var ss = SpreadsheetApp.getActiveSpreadsheet();

    // 1. Lưu điểm danh vào bảng Attendance_Logs (Idempotent theo className + date + slot)
    if (action === 'saveAttendance') {
      var className = (body.className || '').toString().trim();
      var date = (body.date || '').toString().trim();
      var slot = parseInt(body.slot, 10);
      var records = body.records;

      // Validation các trường bắt buộc
      if (!className) {
        return ContentService.createTextOutput(JSON.stringify({
          status: 'error',
          message: 'Thiếu thông tin lớp học (className)!'
        })).setMimeType(ContentService.MimeType.JSON);
      }
      if (!date) {
        return ContentService.createTextOutput(JSON.stringify({
          status: 'error',
          message: 'Thiếu thông tin ngày học (date)!'
        })).setMimeType(ContentService.MimeType.JSON);
      }
      if (isNaN(slot) || slot < 1 || slot > 6) {
        return ContentService.createTextOutput(JSON.stringify({
          status: 'error',
          message: 'Slot học không hợp lệ (phải từ 1 đến 6)!'
        })).setMimeType(ContentService.MimeType.JSON);
      }
      if (!records || !Array.isArray(records)) {
        return ContentService.createTextOutput(JSON.stringify({
          status: 'error',
          message: 'Danh sách bản ghi điểm danh không hợp lệ (records)!'
        })).setMimeType(ContentService.MimeType.JSON);
      }

      var logSheet = ss.getSheetByName('Attendance_Logs');
      var headerRow = ['Thời gian ghi nhận', 'Lớp', 'Ngày học', 'Slot', 'Mã Sinh Viên (MEMBER)', 'Trạng thái', 'Ghi chú'];
      if (!logSheet) {
        logSheet = ss.insertSheet('Attendance_Logs');
        logSheet.appendRow(headerRow);
        var headerRange = logSheet.getRange(1, 1, 1, 7);
        headerRange.setBackground('#F36F21');
        headerRange.setFontColor('#FFFFFF');
        headerRange.setFontWeight('bold');
      }

      // Đọc toàn bộ dữ liệu hiện tại để loại bỏ các bản ghi cũ của đúng buổi học này (Idempotent)
      var existingData = logSheet.getDataRange().getValues();
      var preservedRows = [];

      if (existingData.length > 0) {
        headerRow = existingData[0];
        for (var i = 1; i < existingData.length; i++) {
          var row = existingData[i];
          var rClass = (row[1] || '').toString().trim().toUpperCase();
          var rDate = (row[2] || '').toString().trim();
          var rSlot = parseInt(row[3], 10);

          // Nếu cùng className, date, slot thì BỎ QUA dòng cũ này để thay thế bằng dòng mới
          if (rClass === className.toUpperCase() && rDate === date && rSlot === slot) {
            continue;
          }
          preservedRows.push(row);
        }
      }

      // Chuẩn bị dữ liệu log mới
      var now = new Date();
      var newRows = [];
      for (var j = 0; j < records.length; j++) {
        var rec = records[j];
        var member = (rec.rollNumber || rec.member || '').toString().trim().toUpperCase();
        if (!member) continue;

        var status = (rec.status || 'present').toString().trim().toLowerCase();
        var note = (rec.note || '').toString().trim();

        newRows.push([
          now,
          className,
          date,
          slot,
          member,
          status,
          note
        ]);
      }

      // Ghi đè lại Attendance_Logs một cách an toàn
      var allRows = [headerRow].concat(preservedRows).concat(newRows);
      logSheet.clearContents();
      if (allRows.length > 0) {
        logSheet.getRange(1, 1, allRows.length, 7).setValues(allRows);
      }

      // Cập nhật lại format header sau khi clearContents
      var hRange = logSheet.getRange(1, 1, 1, 7);
      hRange.setBackground('#F36F21');
      hRange.setFontColor('#FFFFFF');
      hRange.setFontWeight('bold');

      // Tính lại chính xác số buổi vắng (ABSENT) từ Attendance_Logs cho sheet lớp
      _recalculateClassAbsentCount(ss, className, logSheet);

      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        message: 'Đã lưu ' + newRows.length + ' bản ghi điểm danh vào Google Sheet!',
        className: className,
        date: date,
        slot: slot,
        recordsCount: newRows.length
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
  } finally {
    if (hasLock) {
      try {
        lock.releaseLock();
      } catch (_) {}
    }
  }
}

// Tính lại chính xác số buổi vắng (ABSENT) từ bảng Attendance_Logs cho từng sinh viên của lớp
function _recalculateClassAbsentCount(ss, className, logSheet) {
  try {
    var classSheet = ss.getSheetByName(className);
    if (!classSheet) return;

    if (!logSheet) {
      logSheet = ss.getSheetByName('Attendance_Logs');
    }
    if (!logSheet) return;

    // 1. Đếm số buổi vắng thực tế từ Attendance_Logs cho lớp này
    var logData = logSheet.getDataRange().getValues();
    var absentCountsByMember = {};

    for (var i = 1; i < logData.length; i++) {
      var row = logData[i];
      var rClass = (row[1] || '').toString().trim().toUpperCase();
      if (rClass === className.toUpperCase()) {
        var status = (row[5] || '').toString().trim().toLowerCase();
        if (status === 'absent' || status === 'vắng') {
          var member = (row[4] || '').toString().trim().toUpperCase();
          if (member) {
            absentCountsByMember[member] = (absentCountsByMember[member] || 0) + 1;
          }
        }
      }
    }

    // 2. Cập nhật cột ABSENT trong sheet lớp tương ứng
    var classData = classSheet.getDataRange().getValues();
    if (classData.length <= 1) return;

    var header = classData[0];
    var memberColIdx = 0;
    var absentColIdx = 6; // Mặc định cột 7 (index 6: ABSENT)

    for (var h = 0; h < header.length; h++) {
      var colName = (header[h] || '').toString().trim().toUpperCase();
      if (colName === 'MEMBER' || colName === 'ROLLNUMBER') {
        memberColIdx = h;
      }
      if (colName === 'ABSENT' || colName === 'VẮNG') {
        absentColIdx = h;
      }
    }

    var absentValues = [];
    for (var s = 1; s < classData.length; s++) {
      var sMember = (classData[s][memberColIdx] || '').toString().trim().toUpperCase();
      var realAbsent = sMember ? (absentCountsByMember[sMember] || 0) : 0;
      absentValues.push([realAbsent]);
    }

    if (absentValues.length > 0) {
      classSheet.getRange(2, absentColIdx + 1, absentValues.length, 1).setValues(absentValues);
    }
  } catch (_) {}
}

// Giữ lại để tương thích ngược nếu có lời gọi ngoài
function _updateStudentAbsentCount(ss, className, records) {
  var logSheet = ss.getSheetByName('Attendance_Logs');
  _recalculateClassAbsentCount(ss, className, logSheet);
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
