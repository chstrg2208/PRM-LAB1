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

  // 2. Lấy danh sách sinh viên theo lớp (Hỗ trợ cấu trúc Metadata Dòng 1-4 và Dynamic Column Mapping)
  if (action === 'getStudents') {
    var reqName = (e.parameter.className || e.parameter.tabName || 'SE1801').toString().trim();
    var sheet = ss.getSheetByName(reqName);

    // Nếu chưa tìm thấy chính xác, thử tìm sheet bắt đầu bằng reqName + '_' (ví dụ SE1801 -> SE1801_PRM393)
    if (!sheet) {
      var allSheets = ss.getSheets();
      for (var sIdx = 0; sIdx < allSheets.length; sIdx++) {
        var sName = allSheets[sIdx].getName();
        if (sName.toLowerCase() === reqName.toLowerCase() ||
            sName.toLowerCase().indexOf(reqName.toLowerCase() + '_') === 0 ||
            reqName.toLowerCase().indexOf(sName.toLowerCase() + '_') === 0) {
          sheet = allSheets[sIdx];
          break;
        }
      }
    }

    // Nếu chưa có sheet cho lớp này, báo lỗi rõ ràng thay vì tự tiện tạo tab mới
    if (!sheet) {
      return ContentService.createTextOutput(JSON.stringify({
        status: 'error',
        message: 'Lớp ' + reqName + ' không tồn tại trong Google Sheet!'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    var data = sheet.getDataRange().getValues();
    var students = [];
    var meta = {
      subject: '',
      room: '',
      days: '',
      slot: 1,
      slotTime: '',
      startDate: '',
      currentSession: 1,
      totalSessions: 20,
      nextDate: '',
      sessionStatus: 'Chưa điểm danh'
    };

    // 1. Tìm dòng Header chính xác:
    // Ưu tiên dòng chứa cột định danh sinh viên (MSSV/MEMBER/ROLLNUMBER) VÀ cột tên/email/vắng
    var headerRowIdx = -1;
    for (var r = 0; r < Math.min(data.length, 10); r++) {
      var rowStr = data[r].map(function(c) { return (c || '').toString().trim().toUpperCase(); }).join(' ');
      var hasId = (rowStr.indexOf('MSSV') >= 0 || rowStr.indexOf('ROLLNUMBER') >= 0 || rowStr.indexOf('MEMBER') >= 0 || rowStr.indexOf('STUDENT ID') >= 0);
      var hasDetails = (rowStr.indexOf('HỌ') >= 0 || rowStr.indexOf('TÊN') >= 0 || rowStr.indexOf('SURNAME') >= 0 || rowStr.indexOf('GIVEN') >= 0 || rowStr.indexOf('EMAIL') >= 0 || rowStr.indexOf('STT') >= 0 || rowStr.indexOf('VẮNG') >= 0);
      if (hasId && hasDetails) {
        headerRowIdx = r;
        break;
      }
    }

    // Fallback: dòng chỉ chứa MSSV hoặc ROLLNUMBER
    if (headerRowIdx < 0) {
      for (var r = 0; r < Math.min(data.length, 10); r++) {
        var rowStr = data[r].map(function(c) { return (c || '').toString().trim().toUpperCase(); }).join(' ');
        if (rowStr.indexOf('MSSV') >= 0 || rowStr.indexOf('ROLLNUMBER') >= 0 || rowStr.indexOf('MEMBER') >= 0 || rowStr.indexOf('MÃ SV') >= 0 || rowStr.indexOf('STUDENT ID') >= 0) {
          headerRowIdx = r;
          break;
        }
      }
    }

    // 2. Nếu dòng Header nằm ở dòng > 0 (ví dụ dòng 5, index 4): Đọc metadata từ các dòng trước
    if (headerRowIdx > 0) {
      for (var mRow = 0; mRow < headerRowIdx; mRow++) {
        var rData = data[mRow];
        for (var c = 0; c < rData.length; c++) {
          var label = (rData[c] || '').toString().trim().toUpperCase();
          var val = (rData[c + 1] !== undefined) ? rData[c + 1].toString().trim() : '';

          if (label.indexOf('MÔN HỌC') >= 0 || label.indexOf('SUBJECT') >= 0) {
            meta.subject = val;
          } else if (label.indexOf('LỊCH') >= 0 || label.indexOf('SLOT') >= 0) {
            var dMatch = val.match(/(T[2-7]-T[2-7])/i);
            if (dMatch) meta.days = dMatch[1].toUpperCase();
            var sMatch = val.match(/Slot\s*([1-6])/i);
            if (sMatch) meta.slot = parseInt(sMatch[1]);
            var tMatch = val.match(/\(([^)]+)\)/);
            if (tMatch) meta.slotTime = tMatch[1];
          } else if (label.indexOf('PHÒNG') >= 0 || label.indexOf('ROOM') >= 0) {
            meta.room = val;
          } else if (label.indexOf('NGÀY BẮT ĐẦU') >= 0 || label.indexOf('START DATE') >= 0) {
            meta.startDate = val;
          } else if (label.indexOf('BUỔI HIỆN TẠI') >= 0 || label.indexOf('CURRENT SESSION') >= 0) {
            var currMatch = val.match(/(\d+)/);
            if (currMatch) meta.currentSession = parseInt(currMatch[1]);
          } else if (label.indexOf('TỔNG SỐ BUỔI') >= 0 || label.indexOf('TOTAL SESSIONS') >= 0) {
            var totMatch = val.match(/(\d+)/);
            if (totMatch) meta.totalSessions = parseInt(totMatch[1]);
          } else if (label.indexOf('NGÀY HỌC TIẾP THEO') >= 0 || label.indexOf('NEXT DATE') >= 0 || label.indexOf('NEXT CLASS') >= 0) {
            meta.nextDate = val;
          } else if (label.indexOf('TRẠNG THÁI') >= 0 || label.indexOf('STATUS') >= 0) {
            meta.sessionStatus = val;
          }
        }
      }
    } else {
      headerRowIdx = 0; // Legacy sheet format
    }

    // 3. Dynamic Column Header Mapping trên dòng tiêu đề
    var headerRow = data[headerRowIdx] || [];
    var colMap = {
      mssv: -1,
      member: -1,
      code: -1,
      surname: -1,
      middleName: -1,
      givenName: -1,
      fullName: -1,
      email: -1,
      totalSlots: -1,
      absentSlots: -1,
      slots20: {} // map 1..20
    };

    for (var colIdx = 0; colIdx < headerRow.length; colIdx++) {
      var colName = (headerRow[colIdx] || '').toString().trim().toUpperCase();
      if (!colName) continue;

      if (colName === 'MSSV' || colName === 'MÃ SINH VIÊN' || colName === 'MÃ SV' || colName === 'ROLLNUMBER' || colName === 'MEMBER' || colName === 'STUDENT ID' || colName === 'STUDENTCODE' || colName === 'CODE') {
        if (colMap.mssv === -1) colMap.mssv = colIdx;
        if (colMap.member === -1) colMap.member = colIdx;
        if (colMap.code === -1) colMap.code = colIdx;
      } else if (colName === 'HỌ' || colName === 'SURNAME' || colName === 'HO' || colName === 'LAST NAME') {
        colMap.surname = colIdx;
      } else if (colName === 'TÊN ĐỆM' || colName === 'MIDDLE NAME' || colName === 'TEN DEM' || colName === 'MIDDLENAME') {
        colMap.middleName = colIdx;
      } else if ((colName === 'TÊN' || colName === 'GIVEN NAME' || colName === 'FIRST NAME' || colName === 'TEN' || colName === 'GIVENNAME') && colName !== 'TÊN ĐỆM') {
        colMap.givenName = colIdx;
      } else if (colName === 'HỌ VÀ TÊN' || colName === 'FULL NAME' || colName === 'FULLNAME' || colName === 'NAME') {
        colMap.fullName = colIdx;
      } else if (colName === 'EMAIL' || colName === 'THƯ ĐIỆN TỬ' || colName === 'MAIL') {
        colMap.email = colIdx;
      } else if (colName === 'TỔNG BUỔI' || colName === 'TOTAL SLOTS' || colName === 'TOTAL' || colName === 'TỔNG TIẾT') {
        colMap.totalSlots = colIdx;
      } else if (colName === 'VẮNG' || colName === 'ABSENT' || colName === 'ABSENT SLOTS' || colName === 'SỐ BUỔI VẮNG') {
        colMap.absentSlots = colIdx;
      }

      // Check slot column B1..B20 hoặc SLOT 1..SLOT 20
      var bMatch = colName.match(/^B([1-9]|1[0-9]|20)$/i);
      if (bMatch) {
        colMap.slots20[parseInt(bMatch[1])] = colIdx;
      } else {
        var slotMatch = colName.match(/^SLOT\s*([1-9]|1[0-9]|20)$/i);
        if (slotMatch) {
          colMap.slots20[parseInt(slotMatch[1])] = colIdx;
        }
      }
    }

    if (colMap.mssv === -1) {
      // Nếu không tìm thấy cột MSSV rõ ràng, tìm cột đầu tiên chứa chuỗi dạng SE/IA/HE/CE/QE/SA/SS...
      for (var cCheck = 0; cCheck < headerRow.length; cCheck++) {
        var hName = (headerRow[cCheck] || '').toString().trim().toUpperCase();
        if (hName !== 'STT') {
          colMap.mssv = cCheck;
          break;
        }
      }
      if (colMap.mssv === -1) colMap.mssv = 1;
    }

    // 4. Đọc từng dòng dữ liệu sinh viên
    for (var i = headerRowIdx + 1; i < data.length; i++) {
      var row = data[i];
      var mssv = (colMap.mssv >= 0 && row[colMap.mssv] !== undefined) ? row[colMap.mssv].toString().trim() : '';
      var code = (colMap.code >= 0 && row[colMap.code] !== undefined) ? row[colMap.code].toString().trim() : mssv;
      var member = (colMap.member >= 0 && row[colMap.member] !== undefined) ? row[colMap.member].toString().trim() : mssv;
      if (!mssv) mssv = code || member;
      if (!code) code = mssv;
      if (!member) member = mssv;
      if (!mssv) continue;

      // Bỏ qua nếu dòng này là metadata lịch học hoặc dòng header phụ
      if (_isInvalidStudentRollNumber(mssv) || _isInvalidStudentRollNumber(code) || _isInvalidStudentRollNumber(member)) {
        continue;
      }

      var surname = (colMap.surname >= 0 && row[colMap.surname] !== undefined) ? row[colMap.surname].toString().trim() : '';
      var middleName = (colMap.middleName >= 0 && row[colMap.middleName] !== undefined) ? row[colMap.middleName].toString().trim() : '';
      var givenName = (colMap.givenName >= 0 && row[colMap.givenName] !== undefined) ? row[colMap.givenName].toString().trim() : '';
      var rawFullName = (colMap.fullName >= 0 && row[colMap.fullName] !== undefined) ? row[colMap.fullName].toString().trim() : '';

      var fullName = '';
      if (surname || middleName || givenName) {
        var nameParts = [surname, middleName, givenName].filter(function(p) { return p && p.length > 0; });
        fullName = nameParts.join(' ');
      } else if (rawFullName) {
        fullName = rawFullName;
      } else {
        fullName = 'Sinh viên ' + mssv;
      }

      // Xử lý Email: Chỉ nhận nếu là địa chỉ email hợp lệ có chứa '@'
      var email = '';
      if (colMap.email >= 0 && row[colMap.email] !== undefined) {
        var rawEmail = row[colMap.email].toString().trim();
        if (rawEmail.indexOf('@') >= 0) {
          email = rawEmail.toLowerCase();
        }
      }
      if (!email && mssv) {
        email = mssv.toLowerCase() + '@fpt.edu.vn';
      }

      var totalSlots = 20;
      if (colMap.totalSlots >= 0 && row[colMap.totalSlots] !== undefined && row[colMap.totalSlots] !== '') {
        var parsedTot = parseInt(row[colMap.totalSlots]);
        if (!isNaN(parsedTot) && parsedTot > 0) totalSlots = parsedTot;
      } else if (meta.totalSessions && meta.totalSessions > 0) {
        totalSlots = meta.totalSessions;
      }

      // Đọc trạng thái 20 slot (B1..B20):
      // A / V = Vắng, P / CM = Có mặt, khoảng trắng / rỗng = Chưa điểm danh (Not Yet)
      var slots20 = [];
      var absentCountFromSlots = 0;
      for (var sn = 1; sn <= 20; sn++) {
        var sCol = colMap.slots20[sn];
        if (sCol !== undefined && sCol >= 0 && row[sCol] !== undefined) {
          var sVal = row[sCol].toString().trim().toUpperCase();
          slots20.push(sVal);
          if (sVal === 'A' || sVal === 'V' || sVal === 'ABSENT' || sVal === 'VẮNG') {
            absentCountFromSlots++;
          }
        } else {
          slots20.push('');
        }
      }

      var absentSlots = 0;
      if (colMap.absentSlots >= 0 && row[colMap.absentSlots] !== undefined && row[colMap.absentSlots] !== '') {
        var parsedAbs = parseInt(row[colMap.absentSlots]);
        if (!isNaN(parsedAbs)) absentSlots = parsedAbs;
        else absentSlots = absentCountFromSlots;
      } else {
        absentSlots = absentCountFromSlots;
      }
      // Nếu absentSlots bất thường (lớn hơn tổng số buổi học) nhưng có dữ liệu từ slots20
      if (absentSlots > totalSlots && absentCountFromSlots <= totalSlots) {
        absentSlots = absentCountFromSlots;
      }
      // Khi có ma trận B1..B20, đây là nguồn sự thật; ABSENT chỉ là cột tổng hợp.
      if (Object.keys(colMap.slots20).length > 0) {
        absentSlots = absentCountFromSlots;
      }

      students.push({
        member: member,
        // MEMBER là khóa định danh canonical dùng chung cho Flutter, log và ma trận.
        rollNumber: member,
        code: code,
        surname: surname,
        middleName: middleName,
        givenName: givenName,
        fullName: fullName,
        email: email,
        className: sheet.getName(),
        totalSlots: totalSlots,
        absentSlots: absentSlots,
        slots20: slots20
      });
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      success: true,
      className: sheet.getName(),
      subject: meta.subject,
      room: meta.room,
      days: meta.days,
      slot: meta.slot,
      slotTime: meta.slotTime || _getFptSlotTime(meta.slot),
      startDate: meta.startDate,
      currentSession: meta.currentSession,
      totalSessions: meta.totalSessions,
      nextDate: meta.nextDate,
      sessionStatus: meta.sessionStatus,
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
        var logClass = (l[1] || '').toString().trim();
        var targetStr = (targetClass || '').toString().trim();
        // Chỉ lấy log của đúng lớp; không gộp các lớp khác môn nhưng trùng tiền tố.
        var isClassMatch = !targetStr || logClass.toUpperCase() === targetStr.toUpperCase();
        if (isClassMatch) {
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

  // 5. Lấy danh sách lớp có tiết học hôm nay theo quy tắc FPT (4 slot, T2-T5 / T3-T6 / T4-T7)
  if (action === 'getTodayClasses') {
    try {
      var targetDateStr = (e.parameter.date || '').toString().trim();
      var targetDate = targetDateStr ? new Date(targetDateStr) : new Date();
      var weekday = targetDate.getDay(); // 0 = Chủ Nhật, 1 = Thứ Hai ... 6 = Thứ Bảy

      var logSheet = ss.getSheetByName('Attendance_Logs');
      var logValues = logSheet ? logSheet.getDataRange().getValues() : [];

      var y = targetDate.getFullYear();
      var m = ('0' + (targetDate.getMonth() + 1)).slice(-2);
      var d = ('0' + targetDate.getDate()).slice(-2);
      var isoDate = y + '-' + m + '-' + d;

      var todayClasses = [];
      var seenClasses = {};

      // 1. Quét trực tiếp các Sheet lớp để lấy metadata từ Dòng 1-4 (Single Source of Truth)
      var allSheets = ss.getSheets();
      for (var sh = 0; sh < allSheets.length; sh++) {
        var aSheet = allSheets[sh];
        if (typeof aSheet.isSheetHidden === 'function' && aSheet.isSheetHidden()) continue;
        var sName = aSheet.getName() ? aSheet.getName().trim() : '';
        if (!sName || sName.indexOf('_') === 0 || sName.indexOf('.') === 0 || sName.toLowerCase() === 'attendance_logs') continue;

        var sData = aSheet.getDataRange().getValues();
        if (sData.length < 5) continue;

        // Kiểm tra xem Dòng 1-4 có chứa metadata không
        var row0Str = sData[0].join(' ').toUpperCase();
        var row1Str = sData[1].join(' ').toUpperCase();
        if (row0Str.indexOf('MÔN HỌC') >= 0 || row1Str.indexOf('LỊCH') >= 0 || row1Str.indexOf('SLOT') >= 0) {
          var sMeta = {
            subject: '',
            days: '',
            slot: 1,
            room: 'NVH-601',
            startDate: '2026-09-07',
            currentSession: 1,
            totalSessions: 20,
            nextDate: '',
            sessionStatus: 'Chưa điểm danh'
          };

          for (var mr = 0; mr < 4; mr++) {
            var rArr = sData[mr];
            for (var mc = 0; mc < rArr.length; mc++) {
              var lbl = (rArr[mc] || '').toString().trim().toUpperCase();
              var val = (rArr[mc + 1] !== undefined) ? rArr[mc + 1].toString().trim() : '';
              if (lbl.indexOf('MÔN HỌC') >= 0 || lbl.indexOf('SUBJECT') >= 0) sMeta.subject = val;
              else if (lbl.indexOf('LỊCH') >= 0 || lbl.indexOf('SLOT') >= 0) {
                var dm = val.match(/(T[2-7]-T[2-7])/i);
                if (dm) sMeta.days = dm[1].toUpperCase();
                var sm = val.match(/Slot\s*([1-6])/i);
                if (sm) sMeta.slot = parseInt(sm[1]);
              } else if (lbl.indexOf('PHÒNG') >= 0 || lbl.indexOf('ROOM') >= 0) sMeta.room = val;
              else if (lbl.indexOf('NGÀY BẮT ĐẦU') >= 0 || lbl.indexOf('START DATE') >= 0) sMeta.startDate = val;
              else if (lbl.indexOf('BUỔI HIỆN TẠI') >= 0) {
                var csm = val.match(/(\d+)/);
                if (csm) sMeta.currentSession = parseInt(csm[1]);
              } else if (lbl.indexOf('TỔNG SỐ BUỔI') >= 0) {
                var tsm = val.match(/(\d+)/);
                if (tsm) sMeta.totalSessions = parseInt(tsm[1]);
              } else if (lbl.indexOf('NGÀY HỌC TIẾP THEO') >= 0 || lbl.indexOf('NEXT DATE') >= 0) sMeta.nextDate = val;
              else if (lbl.indexOf('TRẠNG THÁI') >= 0 || lbl.indexOf('STATUS') >= 0) sMeta.sessionStatus = val;
            }
          }

          var isMatch = false;
          var days = sMeta.days || 'T2-T5';
          if (days.indexOf('T2') >= 0 && days.indexOf('T5') >= 0 && (weekday === 1 || weekday === 4)) isMatch = true;
          if (days.indexOf('T3') >= 0 && days.indexOf('T6') >= 0 && (weekday === 2 || weekday === 5)) isMatch = true;
          if (days.indexOf('T4') >= 0 && days.indexOf('T7') >= 0 && (weekday === 3 || weekday === 6)) isMatch = true;

          // Khớp thêm ngày học tiếp theo
          if (sMeta.nextDate) {
            var ndParts = sMeta.nextDate.split(/[\/\-]/);
            if (ndParts.length === 3) {
              var ndIso = ndParts[2].length === 4 ? (ndParts[2] + '-' + ndParts[1] + '-' + ndParts[0]) : sMeta.nextDate;
              if (ndIso === isoDate || sMeta.nextDate === (d + '/' + m + '/' + y)) {
                isMatch = true;
              }
            }
          }

          if (isMatch) {
            var parts = sName.split('_');
            var subCode = parts[1] || (sMeta.subject.split(' - ')[0] || 'PRM393');
            var stuCount = Math.max(0, sData.length - 5);

            var isDone = (sMeta.sessionStatus === 'Đã điểm danh');
            for (var lg = 1; lg < logValues.length; lg++) {
              if (logValues[lg][1] === sName && logValues[lg][2] === isoDate && parseInt(logValues[lg][3]) === sMeta.slot) {
                isDone = true;
                break;
              }
            }

            seenClasses[sName] = true;
            todayClasses.push({
              className: sName,
              subjectCode: subCode,
              slot: sMeta.slot,
              slotTime: _getFptSlotTime(sMeta.slot),
              daysOfWeek: days,
              room: sMeta.room,
              sessionNumber: sMeta.currentSession,
              totalSessions: sMeta.totalSessions,
              totalStudents: stuCount,
              isAttendanceDone: isDone,
              date: isoDate,
              nextDate: sMeta.nextDate
            });
          }
        }
      }

      // 2. Fallback nếu các sheet chưa có metadata Dòng 1-4: Quét sheet _Class_Schedules
      if (todayClasses.length === 0) {
        var scheduleSheet = ss.getSheetByName('_Class_Schedules');
        if (scheduleSheet) {
          var schedData = scheduleSheet.getDataRange().getValues();
          for (var sIdx = 1; sIdx < schedData.length; sIdx++) {
            var sRow = schedData[sIdx];
            if (!sRow[0] || sRow[0].toString().trim() === '') continue;
            var cName = sRow[0].toString().trim();
            if (seenClasses[cName]) continue;
            var subCode = sRow[1] ? sRow[1].toString().trim() : 'PRM393';
            var slotNum = sRow[2] ? parseInt(sRow[2]) : 1;
            var days = sRow[3] ? sRow[3].toString().trim().toUpperCase() : 'T2-T5';
            var room = sRow[4] ? sRow[4].toString().trim() : 'NVH-601';
            var startStr = sRow[5] ? sRow[5].toString().trim() : '2026-09-07';
            var totalSess = sRow[6] ? parseInt(sRow[6]) : 20;

            var isMatchDay = false;
            if (days.indexOf('T2') >= 0 && days.indexOf('T5') >= 0 && (weekday === 1 || weekday === 4)) isMatchDay = true;
            if (days.indexOf('T3') >= 0 && days.indexOf('T6') >= 0 && (weekday === 2 || weekday === 5)) isMatchDay = true;
            if (days.indexOf('T4') >= 0 && days.indexOf('T7') >= 0 && (weekday === 3 || weekday === 6)) isMatchDay = true;

            if (isMatchDay) {
              var sessNo = _calcSessionNo(startStr, targetDate, days, totalSess);
              var isDone = false;
              for (var lg = 1; lg < logValues.length; lg++) {
                if (logValues[lg][1] === cName && logValues[lg][2] === isoDate && parseInt(logValues[lg][3]) === slotNum) {
                  isDone = true;
                  break;
                }
              }

              var cSheet = ss.getSheetByName(cName);
              var stuCount = cSheet ? Math.max(0, cSheet.getLastRow() - 1) : 0;

              todayClasses.push({
                className: cName,
                subjectCode: subCode,
                slot: slotNum,
                slotTime: _getFptSlotTime(slotNum),
                daysOfWeek: days,
                room: room,
                sessionNumber: sessNo,
                totalSessions: totalSess,
                totalStudents: stuCount,
                isAttendanceDone: isDone,
                date: isoDate
              });
            }
          }
        }
      }

      return ContentService.createTextOutput(JSON.stringify({
        success: true,
        status: 'success',
        date: isoDate,
        total: todayClasses.length,
        data: todayClasses
      })).setMimeType(ContentService.MimeType.JSON);
    } catch (err) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        status: 'error',
        message: 'Lỗi khi lấy danh sách tiết học hôm nay: ' + err.toString()
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }

  // 5.1. Lấy tổng quan điểm danh tất cả các lớp (Hub: Lớp hôm nay & Các lớp khác)
  if (action === 'getAttendanceOverview') {
    try {
      var targetDateStr = (e.parameter.date || '').toString().trim();
      var targetDate = targetDateStr ? new Date(targetDateStr) : new Date();
      var weekday = targetDate.getDay(); // 0 = Chủ Nhật, 1 = Thứ Hai ... 6 = Thứ Bảy

      var y = targetDate.getFullYear();
      var m = ('0' + (targetDate.getMonth() + 1)).slice(-2);
      var d = ('0' + targetDate.getDate()).slice(-2);
      var isoDate = y + '-' + m + '-' + d;
      var dmyDate = d + '/' + m + '/' + y;

      var logSheet = ss.getSheetByName('Attendance_Logs');
      var logValues = logSheet ? logSheet.getDataRange().getValues() : [];

      var todayClasses = [];
      var otherClasses = [];
      var seenClasses = {};

      var allSheets = ss.getSheets();
      for (var sh = 0; sh < allSheets.length; sh++) {
        var aSheet = allSheets[sh];
        if (typeof aSheet.isSheetHidden === 'function' && aSheet.isSheetHidden()) continue;
        var sName = aSheet.getName() ? aSheet.getName().trim() : '';
        if (!sName || sName.indexOf('_') === 0 || sName.indexOf('.') === 0 || sName.toLowerCase() === 'attendance_logs') continue;

        var sData = aSheet.getDataRange().getValues();
        if (sData.length < 5) continue;

        var sMeta = {
          subject: '',
          days: '',
          slot: 1,
          slotTime: '',
          room: 'NVH-601',
          startDate: '',
          currentSession: 1,
          totalSessions: 20,
          nextDate: '',
          sessionStatus: 'Chưa điểm danh'
        };

        for (var mr = 0; mr < Math.min(sData.length, 4); mr++) {
          var rArr = sData[mr];
          for (var mc = 0; mc < rArr.length; mc++) {
            var lbl = (rArr[mc] || '').toString().trim().toUpperCase();
            var val = (rArr[mc + 1] !== undefined) ? rArr[mc + 1].toString().trim() : '';
            if (lbl.indexOf('MÔN HỌC') >= 0 || lbl.indexOf('SUBJECT') >= 0) sMeta.subject = val;
            else if (lbl.indexOf('LỊCH') >= 0 || lbl.indexOf('SLOT') >= 0) {
              var dm = val.match(/(T[2-7]-T[2-7])/i);
              if (dm) sMeta.days = dm[1].toUpperCase();
              var sm = val.match(/Slot\s*([1-6])/i);
              if (sm) sMeta.slot = parseInt(sm[1]);
              var tm = val.match(/\(([^)]+)\)/);
              if (tm) sMeta.slotTime = tm[1];
            } else if (lbl.indexOf('PHÒNG') >= 0 || lbl.indexOf('ROOM') >= 0) sMeta.room = val;
            else if (lbl.indexOf('NGÀY BẮT ĐẦU') >= 0 || lbl.indexOf('START DATE') >= 0) sMeta.startDate = val;
            else if (lbl.indexOf('BUỔI HIỆN TẠI') >= 0 || lbl.indexOf('CURRENT SESSION') >= 0) {
              var csm = val.match(/(\d+)/);
              if (csm) sMeta.currentSession = parseInt(csm[1]);
            } else if (lbl.indexOf('TỔNG SỐ BUỔI') >= 0 || lbl.indexOf('TOTAL SESSIONS') >= 0) {
              var tsm = val.match(/(\d+)/);
              if (tsm) sMeta.totalSessions = parseInt(tsm[1]);
            } else if (lbl.indexOf('NGÀY HỌC TIẾP THEO') >= 0 || lbl.indexOf('NEXT DATE') >= 0) sMeta.nextDate = val;
            else if (lbl.indexOf('TRẠNG THÁI') >= 0 || lbl.indexOf('STATUS') >= 0) sMeta.sessionStatus = val;
          }
        }

        if (!sMeta.slotTime) {
          sMeta.slotTime = _getFptSlotTime(sMeta.slot);
        }

        // ATD-04 fix: Tính lại "buổi hiện tại" = buổi học gần nhất có ngày <= hôm nay
        // Ưu tiên tính từ startDate + daysOfWeek; nếu không có startDate thì dùng currentSession từ sheet
        if (sMeta.startDate && sMeta.days) {
          var computedSession = _calcCurrentSessionFromToday(sMeta.startDate, targetDate, sMeta.days, sMeta.totalSessions);
          if (computedSession > 0) {
            sMeta.currentSession = computedSession;
          }
        }

        var parts = sName.split('_');
        var subCode = parts[1] || (sMeta.subject ? sMeta.subject.split(' - ')[0] : 'PRM393');
        var stuCount = Math.max(0, sData.length - 5);

        // Kiểm tra đã điểm danh buổi hôm nay chưa
        var isDoneToday = false;
        for (var lg = 1; lg < logValues.length; lg++) {
          var lgDate = logValues[lg][2];
          var lgDateStr = '';
          if (lgDate instanceof Date) {
            var ly = lgDate.getFullYear();
            var lm = ('0' + (lgDate.getMonth() + 1)).slice(-2);
            var ld = ('0' + lgDate.getDate()).slice(-2);
            lgDateStr = ly + '-' + lm + '-' + ld;
          } else {
            lgDateStr = (lgDate || '').toString().trim().slice(0, 10);
          }
          if (logValues[lg][1] === sName && (lgDateStr === isoDate || lgDateStr === dmyDate) && parseInt(logValues[lg][3]) === sMeta.slot) {
            isDoneToday = true;
            break;
          }
        }

        // Quét tìm thông tin lần điểm danh gần nhất (lastSession, lastDate, lastStatus)
        var lastSession = 0;
        var lastDate = '';
        var lastStatus = 'Chưa điểm danh';

        var hRowIdx = 4;
        for (var hr = 0; hr < Math.min(sData.length, 10); hr++) {
          var rStr = sData[hr].join(' ').toUpperCase();
          if (rStr.indexOf('MSSV') >= 0 || rStr.indexOf('MEMBER') >= 0 || rStr.indexOf('ROLLNUMBER') >= 0) {
            hRowIdx = hr;
            break;
          }
        }

        var hRow = sData[hRowIdx] || [];
        var colSlots = {};
        for (var c = 0; c < hRow.length; c++) {
          var hName = (hRow[c] || '').toString().trim().toUpperCase();
          var bm = hName.match(/^B([1-9]|1[0-9]|20)$/);
          if (bm) colSlots[parseInt(bm[1])] = c;
          else {
            var sm2 = hName.match(/^SLOT\s*([1-9]|1[0-9]|20)$/);
            if (sm2) colSlots[parseInt(sm2[1])] = c;
          }
        }

        // Quét lùi từ B20 về B1 xem buổi nào có dữ liệu
        for (var b = 20; b >= 1; b--) {
          var cIdx = colSlots[b];
          if (cIdx !== undefined) {
            var hasVal = false;
            for (var r = hRowIdx + 1; r < sData.length; r++) {
              var valStr = (sData[r][cIdx] || '').toString().trim().toUpperCase();
              if (valStr === 'P' || valStr === 'A' || valStr === 'CM' || valStr === 'V') {
                hasVal = true;
                break;
              }
            }
            if (hasVal) {
              lastSession = b;
              lastStatus = 'Đã điểm danh';
              break;
            }
          }
        }

        if (lastSession > 0) {
          for (var lg = logValues.length - 1; lg >= 1; lg--) {
            if (logValues[lg][1] === sName) {
              lastDate = logValues[lg][2] ? logValues[lg][2].toString().slice(0, 10) : '';
              break;
            }
          }
        }

        // Kiểm tra xem cột của buổi hiện tại (currentSession) đã có dữ liệu điểm danh thực tế chưa
        var currColIdx = colSlots[sMeta.currentSession];
        var currSessionHasData = false;
        if (currColIdx !== undefined) {
          for (var r = hRowIdx + 1; r < sData.length; r++) {
            var valStr = (sData[r][currColIdx] || '').toString().trim().toUpperCase();
            if (valStr === 'P' || valStr === 'A' || valStr === 'CM' || valStr === 'V' || valStr === 'L') {
              currSessionHasData = true;
              break;
            }
          }
        }

        // Phân loại: Lớp hôm nay vs Các lớp khác
        var isMatch = false;
        var days = sMeta.days || 'T2-T5';
        if (days.indexOf('T2') >= 0 && days.indexOf('T5') >= 0 && (weekday === 1 || weekday === 4)) isMatch = true;
        if (days.indexOf('T3') >= 0 && days.indexOf('T6') >= 0 && (weekday === 2 || weekday === 5)) isMatch = true;
        if (days.indexOf('T4') >= 0 && days.indexOf('T7') >= 0 && (weekday === 3 || weekday === 6)) isMatch = true;

        if (sMeta.nextDate) {
          var ndParts = sMeta.nextDate.split(/[\/\-]/);
          if (ndParts.length === 3) {
            var ndIso = ndParts[2].length === 4 ? (ndParts[2] + '-' + ndParts[1] + '-' + ndParts[0]) : sMeta.nextDate;
            if (ndIso === isoDate || sMeta.nextDate === dmyDate) {
              isMatch = true;
            }
          }
        }

        // Chỉ khi lớp này CÓ LỊCH HÔM NAY (isMatch) và (đã có dữ liệu cột hôm nay hoặc đã có log hôm nay):
        if (isMatch && (currSessionHasData || isDoneToday || (lastSession > 0 && lastSession >= sMeta.currentSession))) {
          isDoneToday = true;
          sMeta.sessionStatus = 'Đã điểm danh';
          // Đồng bộ lại ô "Trạng thái buổi" trên sheet nếu ô đó chưa cập nhật
          try {
            for (var mr = 0; mr < Math.min(sData.length, 4); mr++) {
              for (var mc = 0; mc < sData[mr].length; mc++) {
                var lbl = (sData[mr][mc] || '').toString().trim().toUpperCase();
                if (lbl.indexOf('TRẠNG THÁI') >= 0 || lbl.indexOf('STATUS') >= 0) {
                  aSheet.getRange(mr + 1, mc + 2).setValue('Đã điểm danh');
                  break;
                }
              }
            }
          } catch (_) {}
        } else if (!isMatch) {
          // Lớp khác không học hôm nay => chắc chắn chưa điểm danh hôm nay
          isDoneToday = false;
        }

        var classItem = {
          className: sName,
          subject: sMeta.subject || (subCode + ' - Môn học'),
          subjectCode: subCode,
          slot: sMeta.slot,
          slotTime: sMeta.slotTime,
          daysOfWeek: days,
          room: sMeta.room,
          currentSession: sMeta.currentSession,
          totalSessions: sMeta.totalSessions,
          totalStudents: stuCount,
          sessionStatus: sMeta.sessionStatus,
          isAttendanceDone: isDoneToday,
          date: isoDate,
          nextDate: sMeta.nextDate,
          lastSession: lastSession,
          lastDate: lastDate,
          lastStatus: lastStatus
        };

        seenClasses[sName] = true;

        if (isMatch) {
          todayClasses.push(classItem);
        } else {
          otherClasses.push(classItem);
        }
      }

      return ContentService.createTextOutput(JSON.stringify({
        success: true,
        status: 'success',
        targetDate: isoDate,
        totalClasses: todayClasses.length + otherClasses.length,
        todayCount: todayClasses.length,
        otherCount: otherClasses.length,
        todayClasses: todayClasses,
        otherClasses: otherClasses
      })).setMimeType(ContentService.MimeType.JSON);
    } catch (err) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        status: 'error',
        message: 'Lỗi khi lấy tổng quan điểm danh: ' + err.toString()
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }

  // 6. Lấy toàn bộ danh sách cấu hình lịch học
  if (action === 'getClassSchedules') {
    try {
      var sSheet = ss.getSheetByName('_Class_Schedules');
      var schedules = [];
      if (sSheet) {
        var sData = sSheet.getDataRange().getValues();
        for (var k = 1; k < sData.length; k++) {
          var r = sData[k];
          if (r[0] && r[0].toString().trim() !== '') {
            schedules.push({
              className: r[0].toString().trim(),
              subjectCode: r[1] ? r[1].toString().trim() : 'PRM393',
              slot: r[2] ? parseInt(r[2]) : 1,
              daysOfWeek: r[3] ? r[3].toString().trim() : 'T2-T5',
              room: r[4] ? r[4].toString().trim() : 'BE-302',
              startDate: r[5] ? r[5].toString().trim() : '2026-09-01',
              totalSessions: r[6] ? parseInt(r[6]) : 20
            });
          }
        }
      } else {
        // Quét trực tiếp các Sheet lớp để lấy cấu hình từ Dòng 1-4 (không tự tạo sheet _Class_Schedules)
        var allSheets = ss.getSheets();
        for (var sh = 0; sh < allSheets.length; sh++) {
          var aSheet = allSheets[sh];
          if (typeof aSheet.isSheetHidden === 'function' && aSheet.isSheetHidden()) continue;
          var sName = aSheet.getName() ? aSheet.getName().trim() : '';
          if (!sName || sName.indexOf('_') === 0 || sName.indexOf('.') === 0 || sName.toLowerCase() === 'attendance_logs') continue;
          var sData = aSheet.getDataRange().getValues();
          if (sData.length < 4) continue;
          var metaDays = 'T2-T5', metaSlot = 1, metaRoom = 'NVH-601', metaStart = '2026-09-01', metaTotal = 20, metaSub = 'PRM393';
          for (var mr = 0; mr < Math.min(sData.length, 4); mr++) {
            for (var mc = 0; mc < sData[mr].length; mc++) {
              var lbl = (sData[mr][mc] || '').toString().trim().toUpperCase();
              var val = (sData[mr][mc + 1] !== undefined) ? sData[mr][mc + 1].toString().trim() : '';
              if (lbl.indexOf('LỊCH') >= 0 || lbl.indexOf('SLOT') >= 0) {
                var dm = val.match(/(T[2-7]-T[2-7])/i);
                if (dm) metaDays = dm[1].toUpperCase();
                var sm = val.match(/Slot\s*([1-6])/i);
                if (sm) metaSlot = parseInt(sm[1]);
              } else if (lbl.indexOf('PHÒNG') >= 0) metaRoom = val;
              else if (lbl.indexOf('NGÀY BẮT ĐẦU') >= 0) metaStart = val;
              else if (lbl.indexOf('TỔNG SỐ BUỔI') >= 0) metaTotal = parseInt(val) || 20;
            }
          }
          schedules.push({
            className: sName,
            subjectCode: sName.split('_')[1] || metaSub,
            slot: metaSlot,
            daysOfWeek: metaDays,
            room: metaRoom,
            startDate: metaStart,
            totalSessions: metaTotal
          });
        }
      }
      return ContentService.createTextOutput(JSON.stringify({
        success: true,
        status: 'success',
        total: schedules.length,
        data: schedules
      })).setMimeType(ContentService.MimeType.JSON);
    } catch (err) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        status: 'error',
        message: 'Lỗi tải danh sách lịch học: ' + err.toString()
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }

  // 7. Giao diện Web Form điểm danh khi sinh viên quét mã QR trên điện thoại
  if (action === 'checkinForm') {
    var cNameParam = (e.parameter.class || e.parameter.className || 'SE1801').toString().trim();
    var slotParam = (e.parameter.slot || '1').toString().trim();
    var sessParam = (e.parameter.session || e.parameter.sessionNumber || '1').toString().trim();
    var tokenParam = (e.parameter.token || '').toString().trim();
    return _renderCheckInHtml(cNameParam, slotParam, sessParam, tokenParam);
  }

  // 8. API Sinh viên check-in bằng Email FPT
  if (action === 'studentCheckIn') {
    return _handleStudentCheckIn(ss, e.parameter);
  }

  // 9. API Lấy danh sách email đã quét QR thành công của phiên
  if (action === 'getQrStatus') {
    return _handleGetQrStatus(ss, e.parameter);
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
      var bypassDateLock = body.bypassDateLock === true;

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

      // Date Lock Validation: Chỉ cho phép điểm danh sau 00:00 của ngày học (date <= today GMT+7)
      if (!bypassDateLock && date) {
        var todayGmt7 = (typeof Utilities !== 'undefined')
          ? Utilities.formatDate(new Date(), 'Asia/Ho_Chi_Minh', 'yyyy-MM-dd')
          : (function() {
              var nowUtc = new Date();
              var gmt7 = new Date(nowUtc.getTime() + 7 * 3600 * 1000);
              return gmt7.toISOString().slice(0, 10);
            })();
        var dateNorm = _normalizeDateToIso(date);
        if (dateNorm && dateNorm > todayGmt7) {
          return ContentService.createTextOutput(JSON.stringify({
            status: 'error',
            error: 'date_locked',
            message: 'Buổi học ngày ' + date + ' chưa diễn ra! Chỉ được phép điểm danh sau 00:00 ngày học.'
          })).setMimeType(ContentService.MimeType.JSON);
        }
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

        var status = (rec.status || 'notyet').toString().trim().toLowerCase();
        // Không lưu các bản ghi notyet hoặc chưa điểm danh vào Attendance_Logs
        if (status === 'notyet' || status === 'not yet' || status === 'chưa điểm danh' || status === '' || status === '-') {
          continue;
        }
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

      // Cập nhật trực tiếp ma trận điểm danh 20 buổi (B1..B20) trong sheet lớp
      _updateClassMatrixAttendance(ss, className, body.sessionNumber || slot, records);

      return ContentService.createTextOutput(JSON.stringify({
        success: true,
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

    var headerRowIdx = 0;
    for (var r = 0; r < Math.min(classData.length, 10); r++) {
      var rowStr = classData[r].map(function(c) { return (c || '').toString().trim().toUpperCase(); }).join(' ');
      if (rowStr.indexOf('MSSV') >= 0 || rowStr.indexOf('ROLLNUMBER') >= 0 || rowStr.indexOf('MEMBER') >= 0) {
        headerRowIdx = r;
        break;
      }
    }

    var header = classData[headerRowIdx] || [];
    var memberColIdx = 0;
    var absentColIdx = -1;

    for (var h = 0; h < header.length; h++) {
      var colName = (header[h] || '').toString().trim().toUpperCase();
      if (colName === 'MEMBER' || colName === 'ROLLNUMBER' || colName === 'MSSV' || colName === 'CODE') {
        if (memberColIdx === 0) memberColIdx = h;
      }
      if (colName === 'ABSENT' || colName === 'VẮNG' || colName === 'ABSENT SLOTS') {
        absentColIdx = h;
      }
    }

    if (absentColIdx < 0) return;

    var absentValues = [];
    for (var s = headerRowIdx + 1; s < classData.length; s++) {
      var sMember = (classData[s][memberColIdx] || '').toString().trim().toUpperCase();
      if (_isInvalidStudentRollNumber(sMember)) {
        absentValues.push([classData[s][absentColIdx] || 0]);
        continue;
      }
      var realAbsent = sMember ? (absentCountsByMember[sMember] || 0) : 0;
      absentValues.push([realAbsent]);
    }

    if (absentValues.length > 0) {
      classSheet.getRange(headerRowIdx + 2, absentColIdx + 1, absentValues.length, 1).setValues(absentValues);
    }
  } catch (_) {}
}

// Giữ lại để tương thích ngược nếu có lời gọi ngoài
function _updateStudentAbsentCount(ss, className, records) {
  var logSheet = ss.getSheetByName('Attendance_Logs');
  _recalculateClassAbsentCount(ss, className, logSheet);
}

// Cập nhật trực tiếp ma trận điểm danh 20 buổi (B1..B20) và cột VẮNG trong sheet lớp
function _updateClassMatrixAttendance(ss, className, sessionNum, records) {
  try {
    var sheet = ss.getSheetByName(className);
    if (!sheet) {
      var allSheets = ss.getSheets();
      for (var sIdx = 0; sIdx < allSheets.length; sIdx++) {
        var sName = allSheets[sIdx].getName();
        if (sName.toLowerCase() === className.toLowerCase() ||
            sName.toLowerCase().indexOf(className.toLowerCase() + '_') === 0 ||
            className.toLowerCase().indexOf(sName.toLowerCase() + '_') === 0) {
          sheet = allSheets[sIdx];
          break;
        }
      }
    }
    if (!sheet) return;

    var data = sheet.getDataRange().getValues();
    if (data.length <= 1) return;

    // Tìm dòng header
    var headerRowIdx = -1;
    for (var r = 0; r < Math.min(data.length, 7); r++) {
      var rowStr = data[r].map(function(c) { return (c || '').toString().trim().toUpperCase(); }).join(' ');
      if (rowStr.indexOf('MSSV') >= 0 || rowStr.indexOf('ROLLNUMBER') >= 0 || rowStr.indexOf('MEMBER') >= 0 || rowStr.indexOf('STUDENT ID') >= 0) {
        headerRowIdx = r;
        break;
      }
    }
    if (headerRowIdx < 0) return;

    var headerRow = data[headerRowIdx];
    var mssvCol = -1;
    var absentCol = -1;
    var sessionCol = -1;
    var slotCols = {};

    for (var c = 0; c < headerRow.length; c++) {
      var hName = (headerRow[c] || '').toString().trim().toUpperCase();
      if (mssvCol === -1 && (hName === 'MSSV' || hName === 'ROLLNUMBER' || hName === 'MEMBER' || hName === 'CODE' || hName === 'STUDENT ID')) {
        mssvCol = c;
      } else if (absentCol === -1 && (hName === 'VẮNG' || hName === 'ABSENT' || hName === 'SỐ BUỔI VẮNG')) {
        absentCol = c;
      }

      var bMatch = hName.match(/^B([1-9]|1[0-9]|20)$/i);
      if (bMatch) {
        var sNum = parseInt(bMatch[1]);
        slotCols[sNum] = c;
        if (sNum === parseInt(sessionNum)) {
          sessionCol = c;
        }
      }
    }

    if (mssvCol < 0) return;

    // Map records theo rollNumber/member
    var statusMap = {};
    for (var i = 0; i < records.length; i++) {
      var rec = records[i];
      var rId = (rec.rollNumber || rec.member || '').toString().trim().toUpperCase();
      var st = (rec.status || 'notyet').toString().trim().toLowerCase();
      var codeVal = '';
      if (st === 'present' || st === 'có mặt' || st === 'p') codeVal = 'P';
      else if (st === 'absent' || st === 'vắng' || st === 'a') codeVal = 'A';
      else if (st === 'late' || st === 'muộn' || st === 'l') codeVal = 'L';
      else codeVal = ''; // notyet / chưa điểm danh -> RỖNG ""
      statusMap[rId] = codeVal;
    }

    // Cập nhật từng sinh viên
    for (var row = headerRowIdx + 1; row < data.length; row++) {
      var sId = (data[row][mssvCol] || '').toString().trim().toUpperCase();
      if (!sId) continue;

      var newCode = statusMap[sId];
      if (sessionCol >= 0 && newCode !== undefined) {
        data[row][sessionCol] = newCode;
        sheet.getRange(row + 1, sessionCol + 1).setValue(newCode);
      }

      // Đếm lại số buổi vắng 'A' trong các cột slotCols nếu sheet có các cột slot
      if (absentCol >= 0 && Object.keys(slotCols).length > 0) {
        var aCount = 0;
        for (var s = 1; s <= 20; s++) {
          var colIdx = slotCols[s];
          if (colIdx !== undefined && colIdx >= 0) {
            var val = (data[row][colIdx] || '').toString().trim().toUpperCase();
            if (val === 'A' || val === 'VẮNG' || val === 'ABSENT') {
              aCount++;
            }
          }
        }
        sheet.getRange(row + 1, absentCol + 1).setValue(aCount);
      }
    }

    // Kiểm tra xem buổi học này có ít nhất 1 sinh viên thực sự được điểm danh (P, A, L) không
    var hasActualAttendance = false;
    for (var k in statusMap) {
      if (statusMap[k] === 'P' || statusMap[k] === 'A' || statusMap[k] === 'L') {
        hasActualAttendance = true;
        break;
      }
    }

    // Đánh dấu trạng thái buổi là Đã điểm danh và tự động cập nhật Ngày học tiếp theo nếu có điểm danh thực tế
    if (headerRowIdx > 0) {
      if (hasActualAttendance) {
        for (var mr = 0; mr < headerRowIdx; mr++) {
          for (var mc = 0; mc < data[mr].length; mc++) {
            var lbl = (data[mr][mc] || '').toString().trim().toUpperCase();
            if (lbl.indexOf('TRẠNG THÁI') >= 0 || lbl.indexOf('STATUS') >= 0) {
              sheet.getRange(mr + 1, mc + 2).setValue('Đã điểm danh');
              break;
            }
          }
        }
        _advanceSessionAndNextDate(sheet, headerRowIdx, data, sessionNum);
      }
    }
  } catch (_) {}
}

// Chuẩn hóa chuỗi ngày sang định dạng YYYY-MM-DD
function _normalizeDateToIso(dateStr) {
  if (!dateStr) return '';
  var s = dateStr.toString().trim();
  var mIso = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (mIso) {
    var y = mIso[1];
    var m = ('0' + mIso[2]).slice(-2);
    var d = ('0' + mIso[3]).slice(-2);
    return y + '-' + m + '-' + d;
  }
  var mDmY = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/);
  if (mDmY) {
    var d2 = ('0' + mDmY[1]).slice(-2);
    var m2 = ('0' + mDmY[2]).slice(-2);
    var y2 = mDmY[3];
    return y2 + '-' + m2 + '-' + d2;
  }
  return s;
}

// Tự động chuyển đổi Ngày tiếp theo và tăng Buổi học sau khi lưu điểm danh thành công
function _advanceSessionAndNextDate(sheet, headerRowIdx, data, sessionNum) {
  try {
    var days = 'T2-T5';
    var nextDateRow = -1;
    var nextDateCol = -1;
    var currentNextDateStr = '';
    var sessRow = -1;
    var sessCol = -1;
    var totalSess = 20;

    for (var r = 0; r < headerRowIdx; r++) {
      for (var c = 0; c < data[r].length; c++) {
        var cell = (data[r][c] || '').toString().trim().toUpperCase();
        if (cell.indexOf('LỊCH') >= 0 || cell.indexOf('DAYS') >= 0) {
          var val = (data[r][c + 1] || '').toString().trim().toUpperCase();
          if (val.indexOf('T3-T6') >= 0) days = 'T3-T6';
          else if (val.indexOf('T4-T7') >= 0) days = 'T4-T7';
          else if (val.indexOf('T2-T5') >= 0) days = 'T2-T5';
        }
        if (cell.indexOf('NGÀY HỌC TIẾP THEO') >= 0 || cell.indexOf('NEXT DATE') >= 0 || cell.indexOf('NEXT CLASS') >= 0) {
          nextDateRow = r;
          nextDateCol = c + 1;
          currentNextDateStr = (data[r][c + 1] || '').toString().trim();
        }
        if (cell.indexOf('BUỔI HIỆN TẠI') >= 0 || cell.indexOf('CURRENT SESSION') >= 0) {
          sessRow = r;
          sessCol = c + 1;
        }
        if (cell.indexOf('TỔNG SỐ BUỔI') >= 0 || cell.indexOf('TOTAL SESSIONS') >= 0) {
          var parsedTot = parseInt((data[r][c + 1] || '').toString().trim(), 10);
          if (!isNaN(parsedTot) && parsedTot > 0) totalSess = parsedTot;
        }
      }
    }

    // 1. Cập nhật buổi hiện tại tăng lên 1 (nếu chưa vượt totalSess)
    var currentSessNum = parseInt(sessionNum, 10);
    if (isNaN(currentSessNum) || currentSessNum <= 0) currentSessNum = 1;
    var nextSessNum = Math.min(currentSessNum + 1, totalSess);
    if (sessRow >= 0 && sessCol >= 0) {
      sheet.getRange(sessRow + 1, sessCol + 1).setValue(nextSessNum + ' / ' + totalSess);
    }

    // 2. Tính ngày tiếp theo từ currentNextDateStr hoặc ngày hôm nay
    var baseDate = new Date();
    if (currentNextDateStr) {
      var iso = _normalizeDateToIso(currentNextDateStr);
      if (iso) {
        var dp = iso.split('-');
        baseDate = new Date(parseInt(dp[0]), parseInt(dp[1]) - 1, parseInt(dp[2]));
      }
    }

    var nextDateObj = _calculateNextFptDate(baseDate, days);
    var dStr = ('0' + nextDateObj.getDate()).slice(-2);
    var mStr = ('0' + (nextDateObj.getMonth() + 1)).slice(-2);
    var yStr = nextDateObj.getFullYear();
    var nextDateFormatted = dStr + '/' + mStr + '/' + yStr;

    if (nextDateRow >= 0 && nextDateCol >= 0) {
      sheet.getRange(nextDateRow + 1, nextDateCol + 1).setValue(nextDateFormatted);
    }
  } catch (_) {}
}

function _calculateNextFptDate(fromDate, daysPattern) {
  var d = new Date(fromDate.getTime());
  var dayOfWeek = d.getDay(); // 0 = Sun, 1 = Mon, 2 = Tue, 3 = Wed, 4 = Thu, 5 = Fri, 6 = Sat
  var daysToAdd = 3;

  var upperDays = (daysPattern || 'T2-T5').toUpperCase();

  if (upperDays.indexOf('T2-T5') >= 0) {
    if (dayOfWeek === 1) daysToAdd = 3; // Monday -> Thursday (+3)
    else if (dayOfWeek === 4) daysToAdd = 4; // Thursday -> Monday (+4)
    else if (dayOfWeek < 1) daysToAdd = 1; // Sun -> Mon
    else if (dayOfWeek < 4) daysToAdd = 4 - dayOfWeek; // Tue/Wed -> Thu
    else daysToAdd = 8 - dayOfWeek; // Fri/Sat -> next Mon
  } else if (upperDays.indexOf('T3-T6') >= 0) {
    if (dayOfWeek === 2) daysToAdd = 3; // Tuesday -> Friday (+3)
    else if (dayOfWeek === 5) daysToAdd = 4; // Friday -> Tuesday (+4)
    else if (dayOfWeek < 2) daysToAdd = 2 - dayOfWeek; // Sun/Mon -> Tue
    else if (dayOfWeek < 5) daysToAdd = 5 - dayOfWeek; // Wed/Thu -> Fri
    else daysToAdd = 9 - dayOfWeek; // Sat -> next Tue
  } else if (upperDays.indexOf('T4-T7') >= 0) {
    if (dayOfWeek === 3) daysToAdd = 3; // Wednesday -> Saturday (+3)
    else if (dayOfWeek === 6) daysToAdd = 4; // Saturday -> Wednesday (+4)
    else if (dayOfWeek < 3) daysToAdd = 3 - dayOfWeek;
    else if (dayOfWeek < 6) daysToAdd = 6 - dayOfWeek;
    else daysToAdd = 10 - dayOfWeek;
  }

  d.setDate(d.getDate() + daysToAdd);
  return d;
}

// Tự tạo sheet mẫu cho lớp với cấu trúc chuẩn FPT (Metadata Dòng 1-4, Header Dòng 5)
function _createSampleClassSheet(ss, className) {
  var sheet = ss.insertSheet(className);

  var parts = className.split('_');
  var subCode = parts[1] || 'PRM393';

  var metaRows = [
    ['Môn học:', subCode + ' - Lập trình Di động', 'Buổi hiện tại:', '1 / 20'],
    ['Lịch & Slot:', 'T2-T5 | Slot 1 (07:00 - 09:15)', 'Ngày học tiếp theo:', '22/09/2026'],
    ['Phòng học:', 'NVH-611', 'Trạng thái buổi:', 'Chưa điểm danh'],
    ['Ngày bắt đầu:', '07/09/2026', 'Tổng số buổi:', 20]
  ];
  sheet.getRange(1, 1, 4, 4).setValues(metaRows);

  var headers = ['STT', 'MSSV', 'HỌ', 'TÊN ĐỆM', 'TÊN', 'EMAIL', 'TỔNG BUỔI', 'VẮNG'];
  for (var b = 1; b <= 20; b++) headers.push('B' + b);
  sheet.appendRow(headers);

  var hRange = sheet.getRange(5, 1, 1, headers.length);
  hRange.setBackground('#059669');
  hRange.setFontColor('#FFFFFF');
  hRange.setFontWeight('bold');

  var sampleData = [
    [1, 'CE190585', 'Lâm', 'Quốc', 'Minh', 'minhlqce190585@fpt.edu.vn', 20, 0],
    [2, 'SE170125', 'Nguyễn', 'Văn', 'An', 'anvse170125@fpt.edu.vn', 20, 1],
    [3, 'SE170456', 'Trần', 'Thị', 'Bình', 'binhttse170456@fpt.edu.vn', 20, 0],
    [4, 'SE170789', 'Lê', 'Hoàng', 'Cương', 'cuonglhse170789@fpt.edu.vn', 20, 3],
    [5, 'SE171012', 'Phạm', 'Minh', 'Đức', 'ducpmse171012@fpt.edu.vn', 20, 4],
    [6, 'SE171345', 'Vũ', 'Hải', 'Đăng', 'dangvhse171345@fpt.edu.vn', 20, 2],
    [7, 'SE160234', 'Đỗ', 'Thùy', 'Linh', 'linhdthse160234@fpt.edu.vn', 20, 0],
    [8, 'SE160567', 'Ngô', 'Quốc', 'Nam', 'namngqse160567@fpt.edu.vn', 20, 1],
    [9, 'IA160090', 'Hoàng', 'Mai', 'Phương', 'phuonghmia160090@fpt.edu.vn', 20, 5]
  ];

  var paddedData = [];
  for (var i = 0; i < sampleData.length; i++) {
    var pRow = sampleData[i].slice();
    for (var sl = 0; sl < 20; sl++) pRow.push('');
    paddedData.push(pRow);
  }

  sheet.getRange(6, 1, paddedData.length, headers.length).setValues(paddedData);
  return sheet;
}

// Kiểm tra chuỗi có phải là MSSV hợp lệ hay là dòng tiêu đề / metadata
function _isInvalidStudentRollNumber(str) {
  if (!str) return true;
  var s = str.toString().trim().toUpperCase();
  if (!s || s === 'STT' || s === 'MSSV' || s === 'MEMBER' || s === 'CODE' || s === 'STUDENT ID' || s === 'ROLLNUMBER') return true;
  if (s.indexOf(':') >= 0 || s.indexOf('|') >= 0 || s.indexOf('(') >= 0 || s.indexOf(')') >= 0) return true;
  if (s.indexOf('SLOT') >= 0 || s.indexOf('PHÒNG') >= 0 || s.indexOf('NGÀY') >= 0 || s.indexOf('LỊCH') >= 0 || s.indexOf('TRẠNG THÁI') >= 0 || s.indexOf('TỔNG SỐ') >= 0) return true;
  if (/^T[2-7]-T[2-7]/.test(s) || /^NVH-/.test(s) || /^BE-/.test(s) || /^DE-/.test(s)) return true;
  if (/^\d{2}\/\d{2}\/\d{4}/.test(s)) return true;
  return false;
}

// Khung giờ 4 Slot chuẩn FPT (135 phút/tiết)
function _getFptSlotTime(slot) {
  switch (parseInt(slot)) {
    case 1: return '07:00 - 09:15';
    case 2: return '09:30 - 11:45';
    case 3: return '12:30 - 14:45';
    case 4: return '15:00 - 17:15';
    case 5: return '17:30 - 19:45';
    case 6: return '20:00 - 22:15';
    default: return 'Slot ' + slot;
  }
}

// Tính số thứ tự buổi học (1..20) dựa trên ngày bắt đầu và cặp ngày học
function _calcSessionNo(startDateStr, targetDate, daysOfWeek, totalSessions) {
  try {
    var start = new Date(startDateStr);
    var target = new Date(targetDate);
    start.setHours(0, 0, 0, 0);
    target.setHours(0, 0, 0, 0);
    if (target < start) return 1;

    var days = (daysOfWeek || 'T2-T5').toUpperCase();
    var allowedWeekdays = [];
    if (days.indexOf('T2') >= 0 && days.indexOf('T5') >= 0) allowedWeekdays = [1, 4];
    else if (days.indexOf('T3') >= 0 && days.indexOf('T6') >= 0) allowedWeekdays = [2, 5];
    else if (days.indexOf('T4') >= 0 && days.indexOf('T7') >= 0) allowedWeekdays = [3, 6];
    else allowedWeekdays = [1, 4];

    var count = 0;
    var cur = new Date(start.getTime());
    while (cur <= target) {
      if (allowedWeekdays.indexOf(cur.getDay()) >= 0) {
        count++;
        if (count >= totalSessions) return totalSessions;
      }
      cur.setDate(cur.getDate() + 1);
    }
    return count > 0 ? count : 1;
  } catch (_) {
    return 1;
  }
}

/**
 * ATD-04: Tính "buổi hiện tại" theo nguyên tắc:
 *   Buổi hiện tại = buổi học gần nhất mà ngày học <= hôm nay (targetDate).
 *
 * Ví dụ: lớp học T3-T6, hôm nay là T4 (Thứ Tư)
 *   → Ngày học gần nhất ≤ hôm nay là T3 (Thứ Ba)
 *   → Đếm số buổi từ startDate đến T3 đó = buổi hiện tại
 *
 * Nếu hôm nay đúng là ngày học (ví dụ T6 = Thứ Sáu, 00:00) thì tính chính buổi đó.
 *
 * @param {string} startDateStr - Ngày bắt đầu lớp học (dd/MM/yyyy hoặc yyyy-MM-dd)
 * @param {Date}   targetDate   - Ngày cần tính (thường là hôm nay)
 * @param {string} daysOfWeek   - Lịch học: "T2-T5" | "T3-T6" | "T4-T7"
 * @param {number} totalSessions - Tổng số buổi (mặc định 20)
 * @returns {number} Số thứ tự buổi học hiện tại (1..totalSessions), hoặc 0 nếu chưa bắt đầu
 */
function _calcCurrentSessionFromToday(startDateStr, targetDate, daysOfWeek, totalSessions) {
  try {
    if (!startDateStr) return 0;

    // Chuẩn hóa startDate
    var startIso = _normalizeDateToIso(startDateStr.toString().trim());
    if (!startIso) return 0;
    var startParts = startIso.split('-');
    var start = new Date(parseInt(startParts[0]), parseInt(startParts[1]) - 1, parseInt(startParts[2]));
    start.setHours(0, 0, 0, 0);

    // Chuẩn hóa targetDate (hôm nay, tính từ 00:00)
    var today = new Date(targetDate);
    today.setHours(0, 0, 0, 0);

    if (today < start) return 0; // Lớp chưa bắt đầu

    // Xác định các ngày học hợp lệ trong tuần (JS: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat)
    var days = (daysOfWeek || 'T2-T5').toUpperCase();
    var allowedWeekdays = [];
    if (days.indexOf('T2') >= 0 && days.indexOf('T5') >= 0) allowedWeekdays = [1, 4]; // T2=Mon, T5=Thu
    else if (days.indexOf('T3') >= 0 && days.indexOf('T6') >= 0) allowedWeekdays = [2, 5]; // T3=Tue, T6=Fri
    else if (days.indexOf('T4') >= 0 && days.indexOf('T7') >= 0) allowedWeekdays = [3, 6]; // T4=Wed, T7=Sat
    else allowedWeekdays = [1, 4];

    var total = totalSessions || 20;

    // Tìm ngày học gần nhất <= hôm nay (bao gồm cả hôm nay nếu hôm nay là ngày học)
    // Duyệt lùi từ today về start
    var lastClassDay = null;
    var cur = new Date(today.getTime());
    while (cur >= start) {
      if (allowedWeekdays.indexOf(cur.getDay()) >= 0) {
        lastClassDay = new Date(cur.getTime());
        break;
      }
      cur.setDate(cur.getDate() - 1);
    }

    if (!lastClassDay) return 0;

    // Đếm số buổi từ start đến lastClassDay (inclusive)
    return _calcSessionNo(startIso, lastClassDay, daysOfWeek, total);
  } catch (_) {
    return 0;
  }
}

// Quản lý sheet cấu hình lịch học _Class_Schedules (không tự tiện tạo sheet nếu không có)
function _getOrCreateSchedulesSheet(ss) {
  return ss.getSheetByName('_Class_Schedules');
}

// Quản lý hoặc tự tạo sheet lưu check-in QR tạm thời _Qr_CheckIns
function _getOrCreateQrCheckInsSheet(ss) {
  var sheet = ss.getSheetByName('_Qr_CheckIns');
  if (!sheet) {
    sheet = ss.insertSheet('_Qr_CheckIns');
    var headers = ['TIMESTAMP', 'CLASS_NAME', 'DATE', 'SLOT', 'SESSION_NO', 'EMAIL', 'STUDENT_NAME', 'TOKEN'];
    sheet.appendRow(headers);
    var hRange = sheet.getRange(1, 1, 1, headers.length);
    hRange.setBackground('#F59E0B');
    hRange.setFontColor('#FFFFFF');
    hRange.setFontWeight('bold');
  }
  return sheet;
}

// Xử lý khi sinh viên gửi yêu cầu check-in bằng Email (Hỗ trợ OAuth Google & Email FPT)
function _handleStudentCheckIn(ss, params) {
  try {
    var cName = (params.className || params.class || '').toString().trim();
    var oauthEmail = '';
    try {
      if (typeof Session !== 'undefined' && Session.getActiveUser) {
        oauthEmail = Session.getActiveUser().getEmail() || '';
      }
    } catch (e) {}

    var email = (params.email || oauthEmail || '').toString().trim().toLowerCase();
    var slot = parseInt(params.slot || '1', 10);
    var sessionNo = parseInt(params.session || '1', 10);
    var date = (params.date || '').toString().trim();
    var token = (params.token || '').toString().trim();

    if (!cName || !email) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        status: 'error',
        message: 'Thiếu thông tin lớp học hoặc email đăng nhập OAuth!'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    var cSheet = ss.getSheetByName(cName);
    // Hỗ trợ tìm sheet thông minh theo prefix (SE1801 -> SE1801_PRM393)
    if (!cSheet) {
      var allSheets = ss.getSheets();
      for (var sIdx = 0; sIdx < allSheets.length; sIdx++) {
        var sName = allSheets[sIdx].getName();
        if (sName.toLowerCase() === cName.toLowerCase() ||
            sName.toLowerCase().indexOf(cName.toLowerCase() + '_') === 0 ||
            cName.toLowerCase().indexOf(sName.toLowerCase() + '_') === 0) {
          cSheet = allSheets[sIdx];
          cName = sName;
          break;
        }
      }
    }

    if (!cSheet) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        status: 'error',
        message: 'Lớp ' + cName + ' không tồn tại trong hệ thống!'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    var cData = cSheet.getDataRange().getValues();
    var headerRowIdx = 0;
    for (var r = 0; r < Math.min(cData.length, 7); r++) {
      var rowStr = cData[r].map(function(c) { return (c || '').toString().trim().toUpperCase(); }).join(' ');
      if (rowStr.indexOf('MSSV') >= 0 || rowStr.indexOf('ROLLNUMBER') >= 0 || rowStr.indexOf('MEMBER') >= 0 || rowStr.indexOf('MÃ SV') >= 0 || rowStr.indexOf('CODE') >= 0) {
        headerRowIdx = r;
        break;
      }
    }

    // Kiểm tra trạng thái buổi học trên Metadata Dòng 1-4 (Chống gian lận khi đã chốt điểm danh)
    var isSessionClosed = false;
    for (var mr = 0; mr < headerRowIdx; mr++) {
      var rArr = cData[mr];
      for (var mc = 0; mc < rArr.length; mc++) {
        var lbl = (rArr[mc] || '').toString().trim().toUpperCase();
        var val = (rArr[mc + 1] !== undefined) ? rArr[mc + 1].toString().trim() : '';
        if (lbl.indexOf('TRẠNG THÁI') >= 0 || lbl.indexOf('STATUS') >= 0) {
          if (val === 'Đã điểm danh' || val.toLowerCase() === 'done' || val.toLowerCase() === 'completed') {
            isSessionClosed = true;
          }
        }
      }
    }

    if (isSessionClosed && params.force !== 'true' && params.reopen !== 'true') {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        status: 'error',
        message: 'Buổi học này đã hoàn tất điểm danh QR. Sinh viên không thể tự quét mã nữa! Vui lòng liên hệ trực tiếp Giảng viên để được hỗ trợ.'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    var headerRow = cData[headerRowIdx] || [];
    var mssvCol = -1, emailCol = -1, hoCol = -1, demCol = -1, tenCol = -1, fullNameCol = -1;
    for (var h = 0; h < headerRow.length; h++) {
      var hText = (headerRow[h] || '').toString().trim().toUpperCase();
      if (hText === 'EMAIL') {
        emailCol = h;
      } else if (hText === 'MSSV' || hText === 'MÃ SV' || hText === 'MÃ SINH VIÊN' || hText === 'ROLLNUMBER' || hText === 'MEMBER' || hText === 'CODE') {
        if (mssvCol === -1) mssvCol = h;
      } else if (hText === 'HỌ' || hText === 'SURNAME') {
        hoCol = h;
      } else if (hText === 'TÊN ĐỆM' || hText === 'MIDDLE NAME') {
        demCol = h;
      } else if (hText === 'TÊN' || hText === 'GIVEN NAME' || hText === 'FIRST NAME') {
        tenCol = h;
      } else if (hText === 'HỌ VÀ TÊN' || hText === 'FULL NAME' || hText === 'STUDENT NAME') {
        fullNameCol = h;
      }
    }

    var studentFound = null;
    for (var i = headerRowIdx + 1; i < cData.length; i++) {
      var row = cData[i];
      var rowEmail = (emailCol >= 0 && row[emailCol] !== undefined) ? row[emailCol].toString().trim().toLowerCase() : '';
      var mssv = (mssvCol >= 0 && row[mssvCol] !== undefined) ? row[mssvCol].toString().trim() : '';
      var defEmail = mssv ? (mssv.toLowerCase() + '@fpt.edu.vn') : '';
      var mssvLower = mssv.toLowerCase();
      var isMssvMatch = mssvLower && (email === mssvLower || email.indexOf(mssvLower) >= 0 || mssvLower.indexOf(email) >= 0);

      if ((rowEmail && (rowEmail === email || email.indexOf(rowEmail) >= 0)) ||
          (defEmail && defEmail === email) ||
          isMssvMatch) {
        var fName = '';
        if (fullNameCol >= 0 && row[fullNameCol]) {
          fName = row[fullNameCol].toString().trim();
        } else {
          var p1 = (hoCol >= 0 && row[hoCol]) ? row[hoCol].toString().trim() : '';
          var p2 = (demCol >= 0 && row[demCol]) ? row[demCol].toString().trim() : '';
          var p3 = (tenCol >= 0 && row[tenCol]) ? row[tenCol].toString().trim() : '';
          fName = [p1, p2, p3].filter(function(x) { return x.length > 0; }).join(' ');
        }
        studentFound = {
          rollNumber: mssv,
          member: mssv,
          fullName: fName || ('Sinh viên ' + mssv),
          email: rowEmail || email
        };
        break;
      }
    }

    if (!studentFound) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        status: 'error',
        message: 'Email ' + email + ' không có trong danh sách sinh viên lớp ' + cName + '!'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // Ghi nhận vào sheet lưu check-in tạm _Qr_CheckIns
    var qrSheet = _getOrCreateQrCheckInsSheet(ss);
    var qrData = qrSheet.getDataRange().getValues();
    var nowIso = new Date().toISOString();
    var todayStr = date || nowIso.slice(0, 10);

    // Chuẩn hóa tên lớp
    function _normClass(str) {
      return (str || '').toString().trim().toLowerCase().replace(/[-_\s]/g, '');
    }

    // Chuẩn hóa ngày dạng YYYY-MM-DD
    function _normDate(val) {
      if (!val) return '';
      if (val instanceof Date) {
        return Utilities.formatDate(val, Session.getScriptTimeZone() || 'Asia/Ho_Chi_Minh', 'yyyy-MM-dd');
      }
      var s = val.toString().trim();
      if (s.indexOf('T') > 0) return s.split('T')[0];
      var m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
      if (m) {
        var day = m[1].length === 1 ? '0' + m[1] : m[1];
        var month = m[2].length === 1 ? '0' + m[2] : m[2];
        return m[3] + '-' + month + '-' + day;
      }
      return s.slice(0, 10);
    }

    var targetDateNorm = _normDate(todayStr);

    // Kiểm tra xem đã check-in chưa
    var alreadyCheckedIn = false;
    for (var q = 1; q < qrData.length; q++) {
      var qRow = qrData[q];
      var qClassNorm = _normClass(qRow[1]);
      var qDateNorm = _normDate(qRow[2]);
      var qSlot = parseInt(qRow[3], 10);
      var qEmail = (qRow[5] || '').toString().trim().toLowerCase();

      var matchCls = qClassNorm === _normClass(cName) || qClassNorm.indexOf(_normClass(cName)) >= 0 || _normClass(cName).indexOf(qClassNorm) >= 0;
      var matchDt = !targetDateNorm || qDateNorm === targetDateNorm;
      var matchSl = isNaN(slot) || slot <= 0 || isNaN(qSlot) || qSlot === slot;

      if (matchCls && matchDt && matchSl && qEmail === email) {
        alreadyCheckedIn = true;
        break;
      }
    }

    if (!alreadyCheckedIn) {
      qrSheet.appendRow([nowIso, cName, todayStr, slot, sessionNo, email, studentFound.fullName, token]);
    }

    return ContentService.createTextOutput(JSON.stringify({
      success: true,
      status: 'success',
      message: 'Điểm danh thành công (Có mặt)!',
      data: {
        student: studentFound,
        className: cName,
        slot: slot,
        sessionNumber: sessionNo,
        alreadyCheckedIn: alreadyCheckedIn
      }
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      status: 'error',
      message: 'Lỗi điểm danh: ' + err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// Lấy danh sách email đã quét QR trong phiên
function _handleGetQrStatus(ss, params) {
  try {
    var cName = (params.className || params.class || '').toString().trim();
    var slot = parseInt(params.slot || '1', 10);
    var date = (params.date || new Date().toISOString().slice(0, 10)).toString().trim();

    function _normClass(str) {
      return (str || '').toString().trim().toLowerCase().replace(/[-_\s]/g, '');
    }

    function _normDate(val) {
      if (!val) return '';
      if (val instanceof Date) {
        return Utilities.formatDate(val, Session.getScriptTimeZone() || 'Asia/Ho_Chi_Minh', 'yyyy-MM-dd');
      }
      var s = val.toString().trim();
      if (s.indexOf('T') > 0) return s.split('T')[0];
      var m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
      if (m) {
        var day = m[1].length === 1 ? '0' + m[1] : m[1];
        var month = m[2].length === 1 ? '0' + m[2] : m[2];
        return m[3] + '-' + month + '-' + day;
      }
      return s.slice(0, 10);
    }

    var targetDateNorm = _normDate(date);
    var targetClassNorm = _normClass(cName);

    var qrSheet = ss.getSheetByName('_Qr_CheckIns');
    var checkedInList = [];
    if (qrSheet) {
      var data = qrSheet.getDataRange().getValues();
      for (var i = 1; i < data.length; i++) {
        var r = data[i];
        var rClass = (r[1] || '').toString().trim();
        var rClassNorm = _normClass(rClass);

        var matchClass = !targetClassNorm ||
                          rClassNorm === targetClassNorm ||
                          rClassNorm.indexOf(targetClassNorm) >= 0 ||
                          targetClassNorm.indexOf(rClassNorm) >= 0;

        var rDateNorm = _normDate(r[2]);
        var matchDate = !targetDateNorm || rDateNorm === targetDateNorm;

        var rSlot = parseInt(r[3], 10);
        var matchSlot = isNaN(slot) || slot <= 0 || isNaN(rSlot) || rSlot === slot;

        if (matchClass && matchDate && matchSlot) {
          checkedInList.push({
            email: (r[5] || '').toString().trim().toLowerCase(),
            name: r[6] || '',
            timestamp: r[0] || ''
          });
        }
      }
    }

    return ContentService.createTextOutput(JSON.stringify({
      success: true,
      status: 'success',
      total: checkedInList.length,
      data: checkedInList
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      status: 'error',
      message: 'Lỗi lấy trạng thái QR: ' + err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// Render Web Page cho sinh viên quét mã QR (Hỗ trợ xác thực OAuth Google Account)
function _renderCheckInHtml(className, slot, sessionNo, token) {
  var oauthEmail = '';
  try {
    if (typeof Session !== 'undefined' && Session.getActiveUser) {
      oauthEmail = Session.getActiveUser().getEmail() || '';
    }
  } catch (e) {}

  var serviceUrl = '';
  try {
    if (typeof ScriptApp !== 'undefined' && ScriptApp.getService) {
      serviceUrl = ScriptApp.getService().getUrl() || '';
    }
  } catch (e) {}

  var html = '<!DOCTYPE html>' +
    '<html lang="vi">' +
    '<head>' +
    '  <meta charset="utf-8">' +
    '  <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
    '  <title>FAP Attendance - Điểm Danh QR</title>' +
    '  <style>' +
    '    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0F172A; color: #F8FAFC; margin: 0; padding: 24px 16px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }' +
    '    .card { background: #1E293B; border: 1px solid #334155; border-radius: 16px; padding: 28px 24px; max-width: 420px; width: 100%; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }' +
    '    .badge { display: inline-block; background: #0D9488; color: white; padding: 4px 12px; border-radius: 9999px; font-size: 13px; font-weight: 600; margin-bottom: 16px; }' +
    '    h1 { font-size: 22px; margin: 0 0 8px 0; color: #F8FAFC; font-weight: 700; }' +
    '    .meta { color: #94A3B8; font-size: 14px; margin-bottom: 24px; line-height: 1.5; }' +
    '    .oauth-box { background: rgba(59, 130, 246, 0.15); border: 1px solid rgba(59, 130, 246, 0.4); border-radius: 10px; padding: 12px 14px; font-size: 13px; color: #93C5FD; margin-bottom: 18px; }' +
    '    label { display: block; font-size: 13px; font-weight: 600; color: #CBD5E1; margin-bottom: 8px; }' +
    '    input { width: 100%; padding: 14px 16px; background: #0F172A; border: 1px solid #475569; border-radius: 10px; color: white; font-size: 15px; box-sizing: border-box; margin-bottom: 20px; outline: none; transition: border-color 0.2s; }' +
    '    input:focus { border-color: #14B8A6; }' +
    '    button { width: 100%; padding: 14px; background: #0D9488; border: none; border-radius: 10px; color: white; font-size: 16px; font-weight: 600; cursor: pointer; transition: background 0.2s; }' +
    '    button:hover { background: #0F766E; }' +
    '    .result { margin-top: 20px; padding: 14px; border-radius: 10px; display: none; font-size: 14px; text-align: center; }' +
    '    .success { background: rgba(16, 185, 129, 0.2); border: 1px solid #10B981; color: #34D399; }' +
    '    .error { background: rgba(239, 68, 68, 0.2); border: 1px solid #EF4444; color: #F87171; }' +
    '  </style>' +
    '</head>' +
    '<body>' +
    '  <div class="card">' +
    '    <span class="badge">FAP ATTENDANCE</span>' +
    '    <h1>Xác Nhận Có Mặt</h1>' +
    '    <div class="meta">Lớp: <b>' + className + '</b> · Slot <b>' + slot + '</b> · Buổi <b>' + sessionNo + '/20</b></div>' +
    (oauthEmail ? '    <div class="oauth-box">Đăng nhập Google OAuth: <b>' + oauthEmail + '</b></div>' : '') +
    '    <form id="checkinForm">' +
    '      <label for="email">Email FPT của bạn (@fpt.edu.vn):</label>' +
    '      <input type="email" id="email" value="' + (oauthEmail || '') + '" placeholder="ví dụ: annvse170123@fpt.edu.vn" required ' + (oauthEmail ? 'readonly' : 'autofocus') + '>' +
    '      <button type="submit" id="btnSubmit">Xác Nhận Có Mặt</button>' +
    '    </form>' +
    '    <div id="resBox" class="result"></div>' +
    '  </div>' +
    '  <script>' +
    '    var form = document.getElementById("checkinForm");' +
    '    var resBox = document.getElementById("resBox");' +
    '    var btn = document.getElementById("btnSubmit");' +
    '    var serviceUrl = "' + (serviceUrl || '') + '";' +
    '    form.onsubmit = function(e) {' +
    '      e.preventDefault();' +
    '      var email = document.getElementById("email").value.trim();' +
    '      btn.disabled = true;' +
    '      btn.innerText = "Đang xác thực OAuth...";' +
    '      var base = serviceUrl || window.location.href.split("?")[0];' +
    '      var url = base + "?action=studentCheckIn&className=" + encodeURIComponent("' + className + '") + "&slot=" + encodeURIComponent("' + slot + '") + "&session=" + encodeURIComponent("' + sessionNo + '") + "&token=" + encodeURIComponent("' + token + '") + "&email=" + encodeURIComponent(email);' +
    '      fetch(url).then(function(r) { return r.json(); }).then(function(data) {' +
    '        resBox.style.display = "block";' +
    '        if (data.success) {' +
    '          resBox.className = "result success";' +
    '          resBox.innerHTML = "<b>✓ Điểm danh thành công!</b><br>" + (data.data.student.fullName || email) + " đã được ghi nhận Có mặt!";' +
    '          form.style.display = "none";' +
    '        } else {' +
    '          resBox.className = "result error";' +
    '          resBox.innerText = data.message || "Lỗi điểm danh!";' +
    '          btn.disabled = false;' +
    '          btn.innerText = "Thử lại";' +
    '        }' +
    '      }).catch(function(err) {' +
    '        resBox.style.display = "block";' +
    '        resBox.className = "result error";' +
    '        resBox.innerText = "Lỗi kết nối mạng: " + err;' +
    '        btn.disabled = false;' +
    '        btn.innerText = "Thử lại";' +
    '      });' +
    '    };' +
    '  </script>' +
    '</body>' +
    '</html>';

  return HtmlService.createHtmlOutput(html)
    .setTitle('FAP - Điểm danh ' + className)
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

