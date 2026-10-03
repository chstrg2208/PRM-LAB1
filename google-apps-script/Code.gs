/**
 * =====================================================================
 *  FAP ATTENDANCE ASSISTANT - GOOGLE APPS SCRIPT BACKEND DATABASE
 *  Dự án: Lab 1 Desktop Application - Môn PRM - Trường Đại học FPT
 *  Hỗ trợ cấu trúc cột: MEMBER, CODE, SURNAME, MIDDLE NAME, GIVEN NAME
 *  Tích hợp AI Analytics: Phân tích Slot nghỉ, Thứ nghỉ, Fail attendance
 * =====================================================================
 */

// Chuẩn hóa khóa sinh viên dùng chung cho roster, ma trận và Attendance_Logs.
function _normalizeStudentKey_(value) {
  return (value === undefined || value === null ? '' : value.toString()).trim().toUpperCase();
}

function _headerName_(value) {
  return (value === undefined || value === null ? '' : value.toString()).trim().toUpperCase();
}

function _findCanonicalStudentColumn_(headerRow) {
  var aliases = ['MEMBER', 'ROLLNUMBER', 'MSSV', 'MÃ SINH VIÊN', 'MÃ SV', 'STUDENT ID', 'CODE', 'STUDENTCODE'];
  for (var a = 0; a < aliases.length; a++) {
    for (var c = 0; c < headerRow.length; c++) {
      if (_headerName_(headerRow[c]) === aliases[a]) return c;
    }
  }
  return -1;
}

function _findHeaderColumn_(headerRow, aliases) {
  for (var c = 0; c < headerRow.length; c++) {
    var name = _headerName_(headerRow[c]);
    for (var a = 0; a < aliases.length; a++) {
      if (name === aliases[a]) return c;
    }
  }
  return -1;
}

function _findStudentHeaderRow_(data) {
  for (var r = 0; r < Math.min(data.length, 10); r++) {
    var row = data[r] || [];
    if (_findCanonicalStudentColumn_(row) >= 0) return r;
  }
  return -1;
}

function _incomingStudentKey_(student) {
  return _normalizeStudentKey_(student && (student.member || student.rollNumber || student.MEMBER || student.RollNumber || student.id || student.code || student.CODE));
}

function _incomingStudentValue_(student, keys, fallback) {
  for (var i = 0; i < keys.length; i++) {
    var value = student ? student[keys[i]] : undefined;
    if (value !== undefined && value !== null && value.toString().trim() !== '') return value.toString().trim();
  }
  return fallback;
}

function _findClassSheet_(ss, className) {
  var requested = (className || '').toString().trim();
  if (!requested) return null;
  var exact = ss.getSheetByName(requested);
  if (exact) return exact;
  var allSheets = ss.getSheets();
  for (var i = 0; i < allSheets.length; i++) {
    var sheetName = allSheets[i].getName().toString().trim();
    var lowerSheet = sheetName.toLowerCase();
    var lowerRequested = requested.toLowerCase();
    if (lowerSheet === lowerRequested ||
        lowerSheet.indexOf(lowerRequested + '_') === 0 ||
        lowerRequested.indexOf(lowerSheet + '_') === 0) {
      return allSheets[i];
    }
  }
  return null;
}

function _buildStudentIdentityMap_(sheet) {
  var result = { aliases: {}, codeByMember: {} };
  if (!sheet) return result;
  var data = sheet.getDataRange().getValues();
  var headerRowIdx = _findStudentHeaderRow_(data);
  if (headerRowIdx < 0) return result;
  var header = data[headerRowIdx] || [];
  var memberCol = _findCanonicalStudentColumn_(header);
  var codeCol = _findHeaderColumn_(header, ['CODE', 'STUDENTCODE']);
  if (memberCol < 0) return result;

  for (var row = headerRowIdx + 1; row < data.length; row++) {
    var member = _normalizeStudentKey_(data[row][memberCol]);
    if (!member || _isInvalidStudentRollNumber(member)) continue;
    result.aliases[member] = member;
    if (codeCol >= 0 && codeCol !== memberCol) {
      var code = _normalizeStudentKey_(data[row][codeCol]);
      if (code && !_isInvalidStudentRollNumber(code)) {
        result.aliases[code] = member;
        result.codeByMember[member] = code;
      }
    }
  }
  return result;
}

function _canonicalStudentKey_(value, identityMap) {
  var normalized = _normalizeStudentKey_(value);
  if (!normalized || !identityMap || !identityMap.aliases) return normalized;
  return identityMap.aliases[normalized] || normalized;
}

// Chuẩn hóa ngày dùng khi đối chiếu Attendance_Logs và lịch học.
function _normalizeAttendanceDate_(value) {
  if (!value) return '';
  if (Object.prototype.toString.call(value) === '[object Date]' && !isNaN(value.getTime())) {
    var y = value.getFullYear();
    var m = ('0' + (value.getMonth() + 1)).slice(-2);
    var d = ('0' + value.getDate()).slice(-2);
    return y + '-' + m + '-' + d;
  }
  var text = value.toString().trim();
  var normalized = _normalizeDateToIso(text);
  if (/^\d{4}-\d{2}-\d{2}$/.test(normalized)) return normalized;

  // Google Sheets đôi khi serialize Date thành chuỗi JavaScript như
  // "Sat Oct 03 2026 00:00:00 GMT+0700 (...)".
  var parsed = new Date(text);
  if (!isNaN(parsed.getTime())) {
    var parsedYear = parsed.getFullYear();
    var parsedMonth = ('0' + (parsed.getMonth() + 1)).slice(-2);
    var parsedDay = ('0' + parsed.getDate()).slice(-2);
    return parsedYear + '-' + parsedMonth + '-' + parsedDay;
  }
  return '';
}

function _attendanceStatusIsTerminal_(value) {
  var status = (value === undefined || value === null ? '' : value.toString()).trim().toLowerCase();
  return [
    'present', 'absent', 'late',
    'có mặt', 'vắng', 'muộn',
    'p', 'a', 'l', 'cm', 'v'
  ].indexOf(status) >= 0;
}

function _attendanceAllowedWeekdays_(daysOfWeek) {
  var days = (daysOfWeek || 'T2-T5').toString().toUpperCase();
  if (days.indexOf('T2') >= 0 && days.indexOf('T5') >= 0) return [1, 4];
  if (days.indexOf('T3') >= 0 && days.indexOf('T6') >= 0) return [2, 5];
  if (days.indexOf('T4') >= 0 && days.indexOf('T7') >= 0) return [3, 6];
  return [1, 4];
}

function _parseAttendanceDate_(value) {
  var iso = _normalizeAttendanceDate_(value);
  var match = iso.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;
  return new Date(parseInt(match[1], 10), parseInt(match[2], 10) - 1, parseInt(match[3], 10));
}

function _readAttendanceMetadata_(sheet) {
  var meta = {
    subject: '',
    days: '',
    slot: 1,
    startDate: '',
    currentSession: 1,
    totalSessions: 20,
    nextDate: '',
    sessionStatus: 'Chưa điểm danh'
  };
  if (!sheet) return meta;
  var data = sheet.getDataRange().getValues();
  for (var r = 0; r < Math.min(data.length, 4); r++) {
    var row = data[r] || [];
    for (var c = 0; c < row.length; c++) {
      var label = _headerName_(row[c]);
      var value = row[c + 1] !== undefined ? row[c + 1].toString().trim() : '';
      if (label.indexOf('MÔN HỌC') >= 0 || label.indexOf('SUBJECT') >= 0) meta.subject = value;
      else if (label.indexOf('LỊCH') >= 0 || label.indexOf('DAYS') >= 0 || label.indexOf('SLOT') >= 0) {
        var dayMatch = value.match(/(T[2-7]-T[2-7])/i);
        if (dayMatch) meta.days = dayMatch[1].toUpperCase();
        var slotMatch = value.match(/Slot\s*([1-6])/i);
        if (slotMatch) meta.slot = parseInt(slotMatch[1], 10);
      } else if (label.indexOf('NGÀY BẮT ĐẦU') >= 0 || label.indexOf('START DATE') >= 0) {
        meta.startDate = value;
      } else if (label.indexOf('BUỔI HIỆN TẠI') >= 0 || label.indexOf('CURRENT SESSION') >= 0) {
        var sessionMatch = value.match(/(\d+)/);
        if (sessionMatch) meta.currentSession = parseInt(sessionMatch[1], 10);
      } else if (label.indexOf('TỔNG SỐ BUỔI') >= 0 || label.indexOf('TOTAL SESSIONS') >= 0) {
        var totalMatch = value.match(/(\d+)/);
        if (totalMatch) meta.totalSessions = parseInt(totalMatch[1], 10);
      } else if (label.indexOf('NGÀY HỌC TIẾP THEO') >= 0 || label.indexOf('NEXT DATE') >= 0) {
        meta.nextDate = value;
      } else if (label.indexOf('TRẠNG THÁI') >= 0 || label.indexOf('STATUS') >= 0) {
        meta.sessionStatus = value;
      }
    }
  }
  return meta;
}

function _extractSubjectCode_(subject, fallback) {
  var text = (subject || '').toString().trim();
  var match = text.match(/^([A-Z]{2,}[A-Z0-9]*\d[A-Z0-9]*)\s*-/i);
  if (match) return match[1].toUpperCase();
  if (/^[A-Z0-9-]+$/i.test(text) && text.indexOf(' ') < 0) return text.toUpperCase();
  return (fallback || 'PRM393').toString().trim().toUpperCase();
}

// Sheet lớp là nguồn chính cho tên/mã môn; schedule table chỉ là fallback.
function _getClassSubjectInfo_(ss, className, fallbackCode, fallbackSubject) {
  var sheet = _findClassSheet_(ss, className);
  var metadata = sheet ? _readAttendanceMetadata_(sheet) : {};
  var subject = (metadata.subject || fallbackSubject || '').toString().trim();
  var subjectCode = _extractSubjectCode_(subject, fallbackCode);
  if (!subject) subject = subjectCode;
  return { subject: subject, subjectCode: subjectCode };
}

function _matrixValueToLogStatus_(value) {
  var status = (value === undefined || value === null ? '' : value.toString()).trim().toUpperCase();
  if (status === 'P' || status === 'PRESENT' || status === 'CM' || status === 'CÓ MẶT') return 'present';
  if (status === 'A' || status === 'ABSENT' || status === 'V' || status === 'VẮNG') return 'absent';
  if (status === 'L' || status === 'LATE' || status === 'MUỘN') return 'late';
  return '';
}

// Tạo log bù từ ma trận khi cả buổi đã có dữ liệu nhưng Attendance_Logs chưa có.
// Chỉ append khi chưa có bất kỳ log nào của đúng class/date/slot/session.
function _materializeAttendanceLogsFromMatrix_(ss, className, dateIso, slot, sessionNumber, metadata, roster, matrixStatusByMember) {
  if (!ss || !roster || roster.length === 0) return false;
  var lock = null;
  var hasLock = false;
  try {
    if (typeof LockService !== 'undefined' && LockService.getScriptLock) {
      lock = LockService.getScriptLock();
      hasLock = lock.tryLock(5000);
      if (!hasLock) return false;
    }

    var canonicalClass = (className || '').toString().trim();
    var logSheet = ss.getSheetByName('Attendance_Logs');
    var header = ['Thời gian ghi nhận', 'Lớp', 'Ngày học', 'Slot', 'Mã Sinh Viên (MEMBER)', 'Trạng thái', 'Ghi chú', 'SESSION_NO'];
    if (!logSheet) {
      logSheet = ss.insertSheet('Attendance_Logs');
      logSheet.appendRow(header);
    } else {
      var currentData = logSheet.getDataRange().getValues();
      var currentHeader = currentData.length > 0 ? (currentData[0] || []) : [];
      var sessionColumn = _findHeaderColumn_(currentHeader, ['SESSION_NO', 'SESSION', 'SESSION NUMBER', 'BUỔI']);
      if (sessionColumn < 0) {
        logSheet.getRange(1, currentHeader.length + 1).setValue('SESSION_NO');
        currentHeader.push('SESSION_NO');
      }
      header = currentHeader.length > 0 ? currentHeader : header;

      var meta = metadata || {};
      for (var i = 1; i < currentData.length; i++) {
        var row = currentData[i] || [];
        var rowClass = (row[1] || '').toString().trim().toUpperCase();
        var rowDate = _normalizeAttendanceDate_(row[2]);
        var rowSlot = parseInt(row[3], 10);
        var rowSession = sessionColumn >= 0 ? parseInt(row[sessionColumn], 10) : NaN;
        if (isNaN(rowSession) && meta.startDate) {
          var rowDateObject = _parseAttendanceDate_(rowDate);
          if (rowDateObject) {
            rowSession = _calcSessionNo(meta.startDate, rowDateObject, meta.days, meta.totalSessions);
          }
        }
        if (rowClass === canonicalClass.toUpperCase() &&
            rowDate === dateIso &&
            rowSlot === parseInt(slot, 10) &&
            rowSession === parseInt(sessionNumber, 10)) {
          return false;
        }
      }
    }

    var now = new Date();
    for (var r = 0; r < roster.length; r++) {
      var logStatus = _matrixValueToLogStatus_(matrixStatusByMember[roster[r].key]);
      if (!logStatus) return false;
      var newRow = [];
      for (var c = 0; c < header.length; c++) newRow.push('');
      newRow[0] = now;
      newRow[1] = canonicalClass;
      newRow[2] = dateIso;
      newRow[3] = parseInt(slot, 10);
      newRow[4] = roster[r].key;
      newRow[5] = logStatus;
      newRow[6] = '';
      var sessionIndex = _findHeaderColumn_(header, ['SESSION_NO', 'SESSION', 'SESSION NUMBER', 'BUỔI']);
      if (sessionIndex < 0) sessionIndex = 7;
      while (newRow.length <= sessionIndex) newRow.push('');
      newRow[sessionIndex] = parseInt(sessionNumber, 10);
      logSheet.appendRow(newRow);
    }
    return true;
  } catch (_) {
    return false;
  } finally {
    if (hasLock && lock) {
      try { lock.releaseLock(); } catch (_) {}
    }
  }
}

function _getAttendanceSessionState_(ss, className, targetDate, slot, sessionNumber, metadata, logValues, sheetData) {
  var sheet = _findClassSheet_(ss, className);
  var canonicalClass = sheet ? sheet.getName().toString().trim() : (className || '').toString().trim();
  var meta = metadata || _readAttendanceMetadata_(sheet);
  var data = sheetData || (sheet ? sheet.getDataRange().getValues() : []);
  var dateIso = _normalizeAttendanceDate_(targetDate);
  var target = _parseAttendanceDate_(dateIso);
  var totalSessions = parseInt(meta.totalSessions, 10) || 20;
  var days = meta.days || 'T2-T5';
  var allowedDays = _attendanceAllowedWeekdays_(days);
  var isScheduledDate = !!target && allowedDays.indexOf(target.getDay()) >= 0;
  var calculatedSession = 0;
  if (meta.startDate && target) {
    calculatedSession = _calcSessionNo(meta.startDate, target, days, totalSessions);
  }
  var requestedSession = parseInt(sessionNumber, 10);
  if (isNaN(requestedSession) || requestedSession <= 0) {
    requestedSession = calculatedSession || parseInt(meta.currentSession, 10) || 0;
  }
  var sessionMatchesSchedule = isScheduledDate && calculatedSession > 0 && requestedSession === calculatedSession;

  var headerRowIdx = _findStudentHeaderRow_(data);
  var header = headerRowIdx >= 0 ? (data[headerRowIdx] || []) : [];
  var memberCol = _findCanonicalStudentColumn_(header);
  var identityMap = _buildStudentIdentityMap_(sheet);
  var roster = [];
  if (headerRowIdx >= 0 && memberCol >= 0) {
    for (var r = headerRowIdx + 1; r < data.length; r++) {
      var member = _canonicalStudentKey_(data[r][memberCol], identityMap);
      if (member && !_isInvalidStudentRollNumber(member)) roster.push({ key: member, row: r });
    }
  }

  var logs = logValues || [];
  var logStatusByMember = {};
  var matchingLogRows = 0;
  var expectedLogDate = dateIso;
  var logSessionCol = -1;
  if (logs.length > 0) {
    var logHeader = logs[0] || [];
    logSessionCol = _findHeaderColumn_(logHeader, ['SESSION_NO', 'SESSION', 'SESSION NUMBER', 'BUỔI']);
    for (var i = 1; i < logs.length; i++) {
      var logRow = logs[i] || [];
      var logClass = (logRow[1] || '').toString().trim();
      var logDate = _normalizeAttendanceDate_(logRow[2]);
      var logSlot = parseInt(logRow[3], 10);
      var logSession = logSessionCol >= 0 ? parseInt(logRow[logSessionCol], 10) : NaN;
      if (isNaN(logSession) && meta.startDate) {
        var logDateObject = _parseAttendanceDate_(logDate);
        if (logDateObject) logSession = _calcSessionNo(meta.startDate, logDateObject, days, totalSessions);
      }
      if (logClass.toUpperCase() !== canonicalClass.toUpperCase() ||
          logDate !== expectedLogDate ||
          logSlot !== parseInt(slot, 10) ||
          logSession !== requestedSession) {
        continue;
      }
      matchingLogRows++;
      var logMember = _canonicalStudentKey_(logRow[4], identityMap);
      if (logMember && _attendanceStatusIsTerminal_(logRow[5])) {
        logStatusByMember[logMember] = true;
      }
    }
  }

  var logMatched = 0;
  for (var l = 0; l < roster.length; l++) {
    if (logStatusByMember[roster[l].key]) logMatched++;
  }
  var logComplete = roster.length > 0 && logMatched === roster.length;

  var matrixCol = -1;
  if (sessionMatchesSchedule) {
    for (var h = 0; h < header.length; h++) {
      var headerName = _headerName_(header[h]);
      var bHeaderMatch = headerName.match(/^B([1-9]|1[0-9]|20)$/);
      var slotHeaderMatch = headerName.match(/^SLOT\s*([1-9]|1[0-9]|20)$/);
      var matrixHeaderSession = bHeaderMatch
        ? parseInt(bHeaderMatch[1], 10)
        : (slotHeaderMatch ? parseInt(slotHeaderMatch[1], 10) : -1);
      if (matrixHeaderSession === requestedSession) {
        matrixCol = h;
        break;
      }
    }
  }
  var matrixMatched = 0;
  var matrixStatusByMember = {};
  if (matrixCol >= 0) {
    for (var m = 0; m < roster.length; m++) {
      var matrixValue = data[roster[m].row][matrixCol];
      matrixStatusByMember[roster[m].key] = matrixValue;
      if (_attendanceStatusIsTerminal_(matrixValue)) matrixMatched++;
    }
  }
  var matrixComplete = roster.length > 0 && matrixCol >= 0 && matrixMatched === roster.length;
  var materialized = false;
  if (matrixComplete && matchingLogRows === 0) {
    materialized = _materializeAttendanceLogsFromMatrix_(
      ss,
      canonicalClass,
      dateIso,
      slot,
      requestedSession,
      meta,
      roster,
      matrixStatusByMember
    );
    if (materialized) {
      logComplete = true;
      logMatched = roster.length;
    }
  }
  var isDone = logComplete || matrixComplete;

  return {
    isDone: isDone,
    status: isDone ? 'Đã điểm danh' : 'Chưa điểm danh',
    source: logComplete ? (materialized ? 'logs-materialized' : 'logs') : (matrixComplete ? 'matrix' : 'none'),
    sessionNumber: requestedSession,
    matchedRecords: logComplete ? logMatched : matrixMatched,
    expectedRecords: roster.length
  };
}

// Tính ngày học tương ứng với một session từ lịch lớp.
function _calcAttendanceDateForSession_(startDateStr, sessionNumber, daysOfWeek, totalSessions) {
  try {
    var requestedSession = parseInt(sessionNumber, 10);
    var total = parseInt(totalSessions, 10) || 20;
    var start = _parseAttendanceDate_(startDateStr);
    if (!start || isNaN(requestedSession) || requestedSession <= 0 || requestedSession > total) return '';

    var allowedWeekdays = _attendanceAllowedWeekdays_(daysOfWeek);
    var current = new Date(start.getTime());
    var count = 0;
    var guard = total * 8 + 14;
    while (guard-- > 0 && count < requestedSession) {
      if (allowedWeekdays.indexOf(current.getDay()) >= 0) {
        count++;
        if (count === requestedSession) return _normalizeAttendanceDate_(current);
      }
      current.setDate(current.getDate() + 1);
    }
  } catch (_) {}
  return '';
}

// Trả về lastSession/lastDate/lastStatus từ cùng một session hoàn tất.
// Không phụ thuộc vào thứ tự dòng trong Attendance_Logs.
function _getLatestAttendanceSummary_(ss, className, metadata, logValues, sheetData, targetDate) {
  var summary = { lastSession: 0, lastDate: '', lastStatus: 'Chưa điểm danh' };
  var sheet = _findClassSheet_(ss, className);
  var meta = metadata || _readAttendanceMetadata_(sheet);
  var data = sheetData || (sheet ? sheet.getDataRange().getValues() : []);
  var headerRowIdx = _findStudentHeaderRow_(data);
  if (headerRowIdx < 0) return summary;

  var header = data[headerRowIdx] || [];
  var memberCol = _findCanonicalStudentColumn_(header);
  if (memberCol < 0) return summary;
  var identityMap = _buildStudentIdentityMap_(sheet);
  var roster = [];
  for (var r = headerRowIdx + 1; r < data.length; r++) {
    var member = _canonicalStudentKey_(data[r][memberCol], identityMap);
    if (member && !_isInvalidStudentRollNumber(member)) roster.push({ key: member, row: r });
  }
  if (roster.length === 0) return summary;

  var maxSession = parseInt(meta.totalSessions, 10) || 20;
  if (meta.startDate && targetDate) {
    var currentSession = _calcCurrentSessionFromToday(meta.startDate, targetDate, meta.days, maxSession);
    if (currentSession > 0) maxSession = currentSession;
  }

  var completeDatesBySession = {};
  var logs = logValues || [];
  var logSessionCol = logs.length > 0
    ? _findHeaderColumn_(logs[0] || [], ['SESSION_NO', 'SESSION', 'SESSION NUMBER', 'BUỔI'])
    : -1;
  var groupedLogs = {};
  for (var i = 1; i < logs.length; i++) {
    var logRow = logs[i] || [];
    var logClass = (logRow[1] || '').toString().trim();
    var logDate = _normalizeAttendanceDate_(logRow[2]);
    var logSlot = parseInt(logRow[3], 10);
    var logSession = logSessionCol >= 0 ? parseInt(logRow[logSessionCol], 10) : NaN;
    if (isNaN(logSession) && meta.startDate && logDate) {
      var logDateObject = _parseAttendanceDate_(logDate);
      if (logDateObject) logSession = _calcSessionNo(meta.startDate, logDateObject, meta.days, meta.totalSessions);
    }
    if (logClass.toUpperCase() !== sheet.getName().toString().trim().toUpperCase() ||
        logDate === '' || logSlot !== parseInt(meta.slot, 10) ||
        isNaN(logSession) || logSession <= 0 || logSession > maxSession) continue;

    var groupKey = logSession + '|' + logDate;
    if (!groupedLogs[groupKey]) groupedLogs[groupKey] = { session: logSession, date: logDate, members: {} };
    var logMember = _canonicalStudentKey_(logRow[4], identityMap);
    if (logMember && _attendanceStatusIsTerminal_(logRow[5])) groupedLogs[groupKey].members[logMember] = true;
  }

  for (var groupKey in groupedLogs) {
    var group = groupedLogs[groupKey];
    var complete = true;
    for (var g = 0; g < roster.length; g++) {
      if (!group.members[roster[g].key]) {
        complete = false;
        break;
      }
    }
    if (complete) {
      var existingDate = completeDatesBySession[group.session];
      if (!existingDate || group.date > existingDate) completeDatesBySession[group.session] = group.date;
    }
  }

  // Matrix là fallback cho các buổi đã đủ trạng thái nhưng chưa có log.
  for (var h = 0; h < header.length; h++) {
    var headerName = _headerName_(header[h]);
    var bMatch = headerName.match(/^B([1-9]|1[0-9]|20)$/);
    var slotMatch = headerName.match(/^SLOT\s*([1-9]|1[0-9]|20)$/);
    var matrixSession = bMatch ? parseInt(bMatch[1], 10) : (slotMatch ? parseInt(slotMatch[1], 10) : -1);
    if (matrixSession <= 0 || matrixSession > maxSession || completeDatesBySession[matrixSession]) continue;

    var matrixComplete = true;
    for (var m = 0; m < roster.length; m++) {
      if (!_attendanceStatusIsTerminal_(data[roster[m].row][h])) {
        matrixComplete = false;
        break;
      }
    }
    if (matrixComplete) {
      var matrixDate = _calcAttendanceDateForSession_(meta.startDate, matrixSession, meta.days, meta.totalSessions);
      if (matrixDate) completeDatesBySession[matrixSession] = matrixDate;
    }
  }

  for (var sessionKey in completeDatesBySession) {
    var session = parseInt(sessionKey, 10);
    var date = completeDatesBySession[sessionKey];
    if (session > summary.lastSession || (session === summary.lastSession && date > summary.lastDate)) {
      summary.lastSession = session;
      summary.lastDate = date;
      summary.lastStatus = 'Đã điểm danh';
    }
  }
  return summary;
}

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

      if (colName === 'MEMBER') {
        if (colMap.mssv === -1) colMap.mssv = colIdx;
        if (colMap.member === -1) colMap.member = colIdx;
      } else if (colName === 'MSSV' || colName === 'MÃ SINH VIÊN' || colName === 'MÃ SV' || colName === 'ROLLNUMBER' || colName === 'STUDENT ID') {
        if (colMap.mssv === -1) colMap.mssv = colIdx;
        if (colMap.member === -1) colMap.member = colIdx;
      } else if (colName === 'STUDENTCODE' || colName === 'CODE') {
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
      var mssv = (colMap.mssv >= 0 && row[colMap.mssv] !== undefined) ? _normalizeStudentKey_(row[colMap.mssv]) : '';
      var code = (colMap.code >= 0 && row[colMap.code] !== undefined) ? _normalizeStudentKey_(row[colMap.code]) : mssv;
      var member = (colMap.member >= 0 && row[colMap.member] !== undefined) ? _normalizeStudentKey_(row[colMap.member]) : mssv;
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

    // Đồng bộ trạng thái buổi hiện tại và tự materialize log từ matrix nếu
    // buổi đó đã đủ dữ liệu nhưng Attendance_Logs chưa có bản ghi.
    var studentToday = _normalizeAttendanceDate_(new Date());
    var studentLogSheet = ss.getSheetByName('Attendance_Logs');
    var studentState = _getAttendanceSessionState_(
      ss,
      sheet.getName(),
      studentToday,
      meta.slot,
      null,
      meta,
      studentLogSheet ? studentLogSheet.getDataRange().getValues() : [],
      data
    );
    meta.sessionStatus = studentState.status;

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      success: true,
      className: sheet.getName(),
      subject: meta.subject,
      room: meta.room,
      days: meta.days,
      slot: meta.slot,
      slotTime: meta.slotTime || _getFptSlotTime(meta.slot),
      startDate: _normalizeAttendanceDate_(meta.startDate),
      currentSession: meta.currentSession,
      totalSessions: meta.totalSessions,
      nextDate: _normalizeAttendanceDate_(meta.nextDate),
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
    var attendanceSheet = _findClassSheet_(ss, cName);
    var attendanceData = attendanceSheet ? attendanceSheet.getDataRange().getValues() : [];
    var attendanceMeta = _readAttendanceMetadata_(attendanceSheet);
    var initialLogValues = logSheet ? logSheet.getDataRange().getValues() : [];
    var attendanceState = _getAttendanceSessionState_(
      ss,
      cName,
      date,
      slot,
      null,
      attendanceMeta,
      initialLogValues,
      attendanceData
    );
    logSheet = ss.getSheetByName('Attendance_Logs');
    var identityMap = _buildStudentIdentityMap_(attendanceSheet);
    var requestedDateIso = _normalizeAttendanceDate_(date);
    var requestedSession = attendanceState ? parseInt(attendanceState.sessionNumber, 10) : NaN;
    var canonicalClassName = attendanceSheet
      ? attendanceSheet.getName().toString().trim().toUpperCase()
      : cName.toString().trim().toUpperCase();
    var records = [];

    if (logSheet) {
      var logData = logSheet.getDataRange().getValues();
      var logHeader = logData.length > 0 ? logData[0] : [];
      var logSessionCol = _findHeaderColumn_(logHeader, ['SESSION_NO', 'SESSION', 'SESSION NUMBER', 'BUỔI']);
      for (var j = 1; j < logData.length; j++) {
        var r = logData[j];
        var rowClassName = (r[1] || '').toString().trim().toUpperCase();
        var rowDateIso = _normalizeAttendanceDate_(r[2]);
        var rowSlot = parseInt(r[3], 10);
        var rowSession = logSessionCol >= 0 ? parseInt(r[logSessionCol], 10) : NaN;
        if (isNaN(rowSession) && attendanceMeta.startDate) {
          var rowDateObject = _parseAttendanceDate_(rowDateIso);
          if (rowDateObject) {
            rowSession = _calcSessionNo(
              attendanceMeta.startDate,
              rowDateObject,
              attendanceMeta.days,
              attendanceMeta.totalSessions
            );
          }
        }

        if (rowClassName === canonicalClassName &&
            rowDateIso === requestedDateIso &&
            rowSlot === slot &&
            rowSession === requestedSession) {
          var canonicalMember = _canonicalStudentKey_(r[4], identityMap);
          records.push({
            rollNumber: canonicalMember,
            member: canonicalMember,
            code: identityMap.codeByMember[canonicalMember] || '',
            className: cName,
            date: requestedDateIso,
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
    var analyticsSheet = _findClassSheet_(ss, targetClass);
    var analyticsMeta = _readAttendanceMetadata_(analyticsSheet);
    var analyticsDate = _normalizeAttendanceDate_(new Date());
    var analyticsLogSheet = ss.getSheetByName('Attendance_Logs');
    _getAttendanceSessionState_(
      ss,
      targetClass,
      analyticsDate,
      analyticsMeta.slot,
      null,
      analyticsMeta,
      analyticsLogSheet ? analyticsLogSheet.getDataRange().getValues() : [],
      analyticsSheet ? analyticsSheet.getDataRange().getValues() : []
    );
    analyticsLogSheet = ss.getSheetByName('Attendance_Logs');
    var logSheet = analyticsLogSheet;
    var logs = [];

    if (logSheet) {
      var allLogs = logSheet.getDataRange().getValues();
      var analyticsHeader = allLogs.length > 0 ? (allLogs[0] || []) : [];
      var analyticsSessionCol = _findHeaderColumn_(analyticsHeader, ['SESSION_NO', 'SESSION', 'SESSION NUMBER', 'BUỔI']);
      for (var m = 1; m < allLogs.length; m++) {
        var l = allLogs[m];
        var logClass = (l[1] || '').toString().trim();
        var targetStr = (targetClass || '').toString().trim();
        // Chỉ lấy log của đúng lớp; không gộp các lớp khác môn nhưng trùng tiền tố.
        var isClassMatch = !targetStr || logClass.toUpperCase() === targetStr.toUpperCase();
        if (isClassMatch) {
          var analyticsDate = _normalizeAttendanceDate_(l[2]);
          var analyticsSession = analyticsSessionCol >= 0 ? parseInt(l[analyticsSessionCol], 10) : NaN;
          if (isNaN(analyticsSession) && analyticsMeta.startDate && analyticsDate) {
            var analyticsDateObject = _parseAttendanceDate_(analyticsDate);
            if (analyticsDateObject) {
              analyticsSession = _calcSessionNo(
                analyticsMeta.startDate,
                analyticsDateObject,
                analyticsMeta.days,
                analyticsMeta.totalSessions
              );
            }
          }
          logs.push({
            timestamp: l[0],
            className: l[1],
            date: analyticsDate,
            slot: parseInt(l[3]),
            sessionNumber: isNaN(analyticsSession) ? null : analyticsSession,
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
          var normalizedNextDate = _normalizeAttendanceDate_(sMeta.nextDate);
          if (normalizedNextDate === isoDate) isMatch = true;

          if (isMatch) {
            var parts = sName.split('_');
            var subjectInfo = _getClassSubjectInfo_(ss, sName, parts[1] || 'PRM393', sMeta.subject);
            var stuCount = Math.max(0, sData.length - 5);

            var todayState = _getAttendanceSessionState_(
              ss,
              sName,
              isoDate,
              sMeta.slot,
              null,
              sMeta,
              logValues,
              sData
            );

            seenClasses[sName] = true;
            todayClasses.push({
              className: sName,
              subjectCode: subjectInfo.subjectCode,
              slot: sMeta.slot,
              slotTime: _getFptSlotTime(sMeta.slot),
              daysOfWeek: days,
              room: sMeta.room,
              sessionNumber: todayState.sessionNumber || sMeta.currentSession,
              totalSessions: sMeta.totalSessions,
              totalStudents: stuCount,
              isAttendanceDone: todayState.isDone,
              date: isoDate,
              nextDate: normalizedNextDate
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

              var cSheet = ss.getSheetByName(cName);
              var stuCount = cSheet ? Math.max(0, cSheet.getLastRow() - 1) : 0;
              var fallbackState = _getAttendanceSessionState_(
                ss,
                cName,
                isoDate,
                slotNum,
                sessNo,
                {
                  days: days,
                  slot: slotNum,
                  startDate: startStr,
                  currentSession: sessNo,
                  totalSessions: totalSess,
                  sessionStatus: 'Chưa điểm danh'
                },
                logValues,
                cSheet ? cSheet.getDataRange().getValues() : []
              );

              var fallbackSubjectInfo = _getClassSubjectInfo_(ss, cName, subCode, '');
              todayClasses.push({
                className: cName,
                subjectCode: fallbackSubjectInfo.subjectCode,
                slot: slotNum,
                slotTime: _getFptSlotTime(slotNum),
                daysOfWeek: days,
                room: room,
                sessionNumber: fallbackState.sessionNumber || sessNo,
                totalSessions: totalSess,
                totalStudents: stuCount,
                isAttendanceDone: fallbackState.isDone,
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
        var subjectInfo = _getClassSubjectInfo_(ss, sName, parts[1] || 'PRM393', sMeta.subject);
        var stuCount = Math.max(0, sData.length - 5);

        // Trạng thái hiện tại được xác định duy nhất bởi helper dùng chung bên dưới.
        var isDoneToday = false;

        var latestSummary = _getLatestAttendanceSummary_(ss, sName, sMeta, logValues, sData, targetDate);
        var lastSession = latestSummary.lastSession;
        var lastDate = latestSummary.lastDate;
        var lastStatus = latestSummary.lastStatus;

        var overviewState = _getAttendanceSessionState_(
          ss,
          sName,
          isoDate,
          sMeta.slot,
          null,
          sMeta,
          logValues,
          sData
        );
        isDoneToday = overviewState.isDone;
        sMeta.sessionStatus = overviewState.status;

        // Phân loại: Lớp hôm nay vs Các lớp khác
        var isMatch = false;
        var days = sMeta.days || 'T2-T5';
        if (days.indexOf('T2') >= 0 && days.indexOf('T5') >= 0 && (weekday === 1 || weekday === 4)) isMatch = true;
        if (days.indexOf('T3') >= 0 && days.indexOf('T6') >= 0 && (weekday === 2 || weekday === 5)) isMatch = true;
        if (days.indexOf('T4') >= 0 && days.indexOf('T7') >= 0 && (weekday === 3 || weekday === 6)) isMatch = true;

        var normalizedNextDate = _normalizeAttendanceDate_(sMeta.nextDate);
        if (normalizedNextDate === isoDate) isMatch = true;

        // Không ghi ngược trạng thái vào sheet trong API GET. Metadata cũ không
        // được phép làm thay đổi kết quả của helper.

        var classItem = {
          className: sName,
          subject: sMeta.subject || subjectInfo.subject,
          subjectCode: subjectInfo.subjectCode,
          slot: sMeta.slot,
          slotTime: sMeta.slotTime,
          daysOfWeek: days,
          room: sMeta.room,
          currentSession: overviewState.sessionNumber || sMeta.currentSession,
          totalSessions: sMeta.totalSessions,
          totalStudents: stuCount,
          sessionStatus: sMeta.sessionStatus,
          isAttendanceDone: isDoneToday,
          date: isoDate,
          nextDate: normalizedNextDate,
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
              subjectCode: _getClassSubjectInfo_(ss, r[0].toString().trim(), r[1] ? r[1].toString().trim() : 'PRM393', '').subjectCode,
              slot: r[2] ? parseInt(r[2]) : 1,
              daysOfWeek: r[3] ? r[3].toString().trim() : 'T2-T5',
              room: r[4] ? r[4].toString().trim() : 'BE-302',
              startDate: _normalizeAttendanceDate_(r[5] || '2026-09-01'),
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
               if (lbl.indexOf('MÔN HỌC') >= 0 || lbl.indexOf('SUBJECT') >= 0) metaSub = val;
               else if (lbl.indexOf('LỊCH') >= 0 || lbl.indexOf('SLOT') >= 0) {
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
             subjectCode: _getClassSubjectInfo_(ss, sName, sName.split('_')[1] || metaSub, metaSub).subjectCode,
            slot: metaSlot,
            daysOfWeek: metaDays,
            room: metaRoom,
             startDate: _normalizeAttendanceDate_(metaStart),
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

      var saveClassSheet = _findClassSheet_(ss, className);
      var saveMetadata = _readAttendanceMetadata_(saveClassSheet);
      var requestedSessionNumber = parseInt(body.sessionNumber, 10);
      if ((isNaN(requestedSessionNumber) || requestedSessionNumber <= 0) && saveMetadata.startDate) {
        var saveDateObject = _parseAttendanceDate_(date);
        if (saveDateObject) {
          requestedSessionNumber = _calcSessionNo(
            saveMetadata.startDate,
            saveDateObject,
            saveMetadata.days,
            saveMetadata.totalSessions
          );
        }
      }
      if (isNaN(requestedSessionNumber) || requestedSessionNumber <= 0) {
        requestedSessionNumber = slot;
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
      var headerRow = ['Thời gian ghi nhận', 'Lớp', 'Ngày học', 'Slot', 'Mã Sinh Viên (MEMBER)', 'Trạng thái', 'Ghi chú', 'SESSION_NO'];
      if (!logSheet) {
        logSheet = ss.insertSheet('Attendance_Logs');
        logSheet.appendRow(headerRow);
        var headerRange = logSheet.getRange(1, 1, 1, headerRow.length);
        headerRange.setBackground('#F36F21');
        headerRange.setFontColor('#FFFFFF');
        headerRange.setFontWeight('bold');
      }
      var identityMapForSave = _buildStudentIdentityMap_(_findClassSheet_(ss, className));

      // Đọc toàn bộ dữ liệu hiện tại để loại bỏ các bản ghi cũ của đúng buổi học này (Idempotent)
      var existingData = logSheet.getDataRange().getValues();
      var preservedRows = [];

      if (existingData.length > 0) {
        headerRow = (existingData[0] || []).slice();
        var sessionColumn = _findHeaderColumn_(headerRow, ['SESSION_NO', 'SESSION', 'SESSION NUMBER', 'BUỔI']);
        if (sessionColumn < 0) {
          sessionColumn = headerRow.length;
          headerRow.push('SESSION_NO');
        }
        for (var i = 1; i < existingData.length; i++) {
          var row = (existingData[i] || []).slice();
          while (row.length < headerRow.length) row.push('');
          var rClass = (row[1] || '').toString().trim().toUpperCase();
          var rDate = _normalizeAttendanceDate_(row[2]);
          var rSlot = parseInt(row[3], 10);
          var rSession = parseInt(row[sessionColumn], 10);
          if ((isNaN(rSession) || rSession <= 0) && saveMetadata.startDate) {
            var existingDateObject = _parseAttendanceDate_(rDate);
            if (existingDateObject) {
              rSession = _calcSessionNo(
                saveMetadata.startDate,
                existingDateObject,
                saveMetadata.days,
                saveMetadata.totalSessions
              );
            }
          }

          // Idempotent theo đúng class + date + slot + session.
          if (rClass === className.toUpperCase() &&
              rDate === _normalizeAttendanceDate_(date) &&
              rSlot === slot &&
              rSession === requestedSessionNumber) {
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
        var member = _canonicalStudentKey_(rec.rollNumber || rec.member || rec.MEMBER || rec.MSSV || rec.code || rec.CODE, identityMapForSave);
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
          note,
          requestedSessionNumber
        ]);
      }

      // Ghi đè lại Attendance_Logs một cách an toàn
      var allRows = [headerRow].concat(preservedRows).concat(newRows);
      logSheet.clearContents();
      if (allRows.length > 0) {
        logSheet.getRange(1, 1, allRows.length, headerRow.length).setValues(allRows);
      }

      // Cập nhật lại format header sau khi clearContents
      var hRange = logSheet.getRange(1, 1, 1, headerRow.length);
      hRange.setBackground('#F36F21');
      hRange.setFontColor('#FFFFFF');
      hRange.setFontWeight('bold');

      // Tính lại chính xác số buổi vắng (ABSENT) từ Attendance_Logs cho sheet lớp
      _recalculateClassAbsentCount(ss, className, logSheet);

      // Cập nhật trực tiếp ma trận điểm danh 20 buổi (B1..B20) trong sheet lớp
      _updateClassMatrixAttendance(ss, className, requestedSessionNumber, records);

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

    // 2. Đồng bộ roster theo kiểu upsert, không xóa metadata hoặc ma trận điểm danh.
    if (action === 'syncStudents') {
      var cls = (body.className || '').toString().trim();
      var students = body.students || [];

      if (!cls) {
        return ContentService.createTextOutput(JSON.stringify({
          status: 'error',
          success: false,
          message: 'Thiếu tên lớp cần đồng bộ!'
        })).setMimeType(ContentService.MimeType.JSON);
      }
      if (!Array.isArray(students) || students.length === 0) {
        return ContentService.createTextOutput(JSON.stringify({
          status: 'error',
          success: false,
          message: 'Danh sách sinh viên rỗng; từ chối đồng bộ để bảo toàn dữ liệu hiện có!'
        })).setMimeType(ContentService.MimeType.JSON);
      }

      // Validate toàn bộ payload trước khi ghi bất kỳ ô nào.
      var incomingKeys = {};
      for (var k = 0; k < students.length; k++) {
        var incomingKey = _incomingStudentKey_(students[k]);
        if (!incomingKey || _isInvalidStudentRollNumber(incomingKey)) {
          return ContentService.createTextOutput(JSON.stringify({
            status: 'error',
            success: false,
            message: 'Payload chứa sinh viên không có MEMBER hợp lệ tại vị trí ' + k + '.'
          })).setMimeType(ContentService.MimeType.JSON);
        }
        if (incomingKeys[incomingKey]) {
          return ContentService.createTextOutput(JSON.stringify({
            status: 'error',
            success: false,
            message: 'Payload chứa MEMBER trùng lặp: ' + incomingKey + '.'
          })).setMimeType(ContentService.MimeType.JSON);
        }
        incomingKeys[incomingKey] = true;
      }

      var stdSheet = ss.getSheetByName(cls);
      var inserted = 0;
      var updated = 0;
      var retained = 0;

      // Sheet mới có schema đầy đủ để những lần save sau có thể dùng B1..B20.
      if (!stdSheet) {
        stdSheet = ss.insertSheet(cls);
        var newHeaders = ['MEMBER', 'CODE', 'SURNAME', 'MIDDLE NAME', 'GIVEN NAME', 'TOTAL SLOTS', 'ABSENT', 'EMAIL'];
        for (var slotHeader = 1; slotHeader <= 20; slotHeader++) newHeaders.push('B' + slotHeader);
        stdSheet.appendRow(newHeaders);
        var newHeaderRange = stdSheet.getRange(1, 1, 1, newHeaders.length);
        newHeaderRange.setBackground('#6366F1');
        newHeaderRange.setFontColor('#FFFFFF');
        newHeaderRange.setFontWeight('bold');

        for (var newIndex = 0; newIndex < students.length; newIndex++) {
          var newStudent = students[newIndex];
          var newRow = [];
          for (var blankCol = 0; blankCol < newHeaders.length; blankCol++) newRow.push('');
          newRow[0] = _incomingStudentKey_(newStudent);
          newRow[1] = _incomingStudentValue_(newStudent, ['code', 'CODE'], '');
          newRow[2] = _incomingStudentValue_(newStudent, ['surname', 'SURNAME'], '');
          newRow[3] = _incomingStudentValue_(newStudent, ['middleName', 'MIDDLE NAME'], '');
          newRow[4] = _incomingStudentValue_(newStudent, ['givenName', 'GIVEN NAME'], '');
          newRow[5] = parseInt(_incomingStudentValue_(newStudent, ['totalSlots', 'TOTAL SLOTS'], '20'), 10) || 20;
          newRow[6] = 0;
          newRow[7] = _incomingStudentValue_(newStudent, ['email', 'EMAIL'], '');
          stdSheet.appendRow(newRow);
          inserted++;
        }
      } else {
        var currentData = stdSheet.getDataRange().getValues();
        var currentHeaderRowIdx = _findStudentHeaderRow_(currentData);
        if (currentHeaderRowIdx < 0) {
          return ContentService.createTextOutput(JSON.stringify({
            status: 'error',
            success: false,
            message: 'Không tìm thấy header định danh sinh viên; từ chối ghi đè sheet ' + cls + '.'
          })).setMimeType(ContentService.MimeType.JSON);
        }

        var currentHeader = currentData[currentHeaderRowIdx] || [];
        var canonicalCol = _findCanonicalStudentColumn_(currentHeader);
        var codeCol = _findHeaderColumn_(currentHeader, ['CODE', 'STUDENTCODE']);
        var surnameCol = _findHeaderColumn_(currentHeader, ['SURNAME', 'HỌ', 'HO', 'LAST NAME']);
        var middleNameCol = _findHeaderColumn_(currentHeader, ['MIDDLE NAME', 'MIDDLE_NAME', 'MIDDLENAME', 'TÊN ĐỆM', 'TEN DEM']);
        var givenNameCol = _findHeaderColumn_(currentHeader, ['GIVEN NAME', 'GIVEN_NAME', 'GIVENNAME', 'FIRST NAME', 'TÊN', 'TEN']);
        var totalSlotsCol = _findHeaderColumn_(currentHeader, ['TOTAL SLOTS', 'TOTAL', 'TỔNG BUỔI', 'TỔNG TIẾT']);
        var absentCol = _findHeaderColumn_(currentHeader, ['ABSENT', 'ABSENT SLOTS', 'VẮNG', 'SỐ BUỔI VẮNG']);
        var emailCol = _findHeaderColumn_(currentHeader, ['EMAIL', 'MAIL', 'THƯ ĐIỆN TỬ']);
        var existingRowsByKey = {};

        for (var existingRow = currentHeaderRowIdx + 1; existingRow < currentData.length; existingRow++) {
          var existingKey = _normalizeStudentKey_(currentData[existingRow][canonicalCol]);
          if (!existingKey || _isInvalidStudentRollNumber(existingKey)) continue;
          if (existingRowsByKey[existingKey] !== undefined) {
            return ContentService.createTextOutput(JSON.stringify({
              status: 'error',
              success: false,
              message: 'Sheet ' + cls + ' chứa MEMBER trùng lặp: ' + existingKey + '; không thể sync an toàn.'
            })).setMimeType(ContentService.MimeType.JSON);
          }
          existingRowsByKey[existingKey] = existingRow;
        }

        var setCell = function(rowIndex, colIndex, value) {
          if (colIndex >= 0 && colIndex !== absentCol) {
            stdSheet.getRange(rowIndex + 1, colIndex + 1).setValue(value);
          }
        };
        var setIncomingCell = function(rowIndex, colIndex, student, keys) {
          var value = _incomingStudentValue_(student, keys, null);
          if (value !== null) setCell(rowIndex, colIndex, value);
        };

        for (var incomingIndex = 0; incomingIndex < students.length; incomingIndex++) {
          var incomingStudent = students[incomingIndex];
          var key = _incomingStudentKey_(incomingStudent);
          var rowIndex = existingRowsByKey[key];
          if (rowIndex === undefined) {
            var appendedRow = [];
            for (var colIndex = 0; colIndex < currentHeader.length; colIndex++) appendedRow.push('');
            appendedRow[canonicalCol] = key;
            if (codeCol >= 0 && codeCol !== canonicalCol) appendedRow[codeCol] = _incomingStudentValue_(incomingStudent, ['code', 'CODE'], '');
            if (surnameCol >= 0) appendedRow[surnameCol] = _incomingStudentValue_(incomingStudent, ['surname', 'SURNAME'], '');
            if (middleNameCol >= 0) appendedRow[middleNameCol] = _incomingStudentValue_(incomingStudent, ['middleName', 'MIDDLE NAME'], '');
            if (givenNameCol >= 0) appendedRow[givenNameCol] = _incomingStudentValue_(incomingStudent, ['givenName', 'GIVEN NAME'], '');
            if (totalSlotsCol >= 0) appendedRow[totalSlotsCol] = parseInt(_incomingStudentValue_(incomingStudent, ['totalSlots', 'TOTAL SLOTS'], '20'), 10) || 20;
            if (absentCol >= 0) appendedRow[absentCol] = 0;
            if (emailCol >= 0) appendedRow[emailCol] = _incomingStudentValue_(incomingStudent, ['email', 'EMAIL'], '');
            stdSheet.appendRow(appendedRow);
            inserted++;
          } else {
            // Chỉ cập nhật roster fields; ABSENT và B1..B20 không bao giờ bị ghi đè.
            if (codeCol >= 0 && codeCol !== canonicalCol) setIncomingCell(rowIndex, codeCol, incomingStudent, ['code', 'CODE']);
            setIncomingCell(rowIndex, surnameCol, incomingStudent, ['surname', 'SURNAME']);
            setIncomingCell(rowIndex, middleNameCol, incomingStudent, ['middleName', 'MIDDLE NAME']);
            setIncomingCell(rowIndex, givenNameCol, incomingStudent, ['givenName', 'GIVEN NAME']);
            var totalSlotsValue = _incomingStudentValue_(incomingStudent, ['totalSlots', 'TOTAL SLOTS'], null);
            if (totalSlotsValue !== null) setCell(rowIndex, totalSlotsCol, parseInt(totalSlotsValue, 10) || 20);
            setIncomingCell(rowIndex, emailCol, incomingStudent, ['email', 'EMAIL']);
            updated++;
          }
        }

        for (var oldKey in existingRowsByKey) {
          if (!incomingKeys[oldKey]) retained++;
        }
      }

      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        success: true,
        inserted: inserted,
        updated: updated,
        retained: retained,
        message: 'Đã đồng bộ ' + students.length + ' sinh viên cho lớp ' + cls + ' mà không xóa lịch sử điểm danh.'
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
    var classSheet = _findClassSheet_(ss, className);
    if (!classSheet) return;
    var identityMap = _buildStudentIdentityMap_(classSheet);

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
          var member = _canonicalStudentKey_(row[4], identityMap);
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
    var memberColIdx = _findCanonicalStudentColumn_(header);
    var absentColIdx = -1;

    for (var h = 0; h < header.length; h++) {
      var colName = (header[h] || '').toString().trim().toUpperCase();
      if (colName === 'ABSENT' || colName === 'VẮNG' || colName === 'ABSENT SLOTS') {
        absentColIdx = h;
      }
    }

    if (memberColIdx < 0 || absentColIdx < 0) return;

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
    var identityMap = _buildStudentIdentityMap_(sheet);

    var data = sheet.getDataRange().getValues();
    if (data.length <= 1) return;

    // Tìm dòng header
    var headerRowIdx = -1;
    for (var r = 0; r < Math.min(data.length, 7); r++) {
      var rowStr = data[r].map(function(c) { return (c || '').toString().trim().toUpperCase(); }).join(' ');
      if (rowStr.indexOf('MSSV') >= 0 || rowStr.indexOf('ROLLNUMBER') >= 0 || rowStr.indexOf('MEMBER') >= 0 || rowStr.indexOf('STUDENT ID') >= 0 || rowStr.indexOf('CODE') >= 0) {
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
      if (absentCol === -1 && (hName === 'VẮNG' || hName === 'ABSENT' || hName === 'SỐ BUỔI VẮNG')) {
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

    mssvCol = _findCanonicalStudentColumn_(headerRow);

    if (mssvCol < 0) return;

    // Map records theo rollNumber/member
    var statusMap = {};
    for (var i = 0; i < records.length; i++) {
      var rec = records[i];
      var rId = _canonicalStudentKey_(rec.member || rec.rollNumber || rec.MEMBER || rec.MSSV || rec.code || rec.CODE, identityMap);
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

    // Chỉ chốt metadata khi toàn bộ roster có trạng thái cuối. Một vài SV có
    // dữ liệu không đủ để kết luận cả buổi đã hoàn tất.
    var expectedStudentCount = 0;
    var completedStudentCount = 0;
    for (var checkRow = headerRowIdx + 1; checkRow < data.length; checkRow++) {
      var checkId = _canonicalStudentKey_(data[checkRow][mssvCol], identityMap);
      if (!checkId || _isInvalidStudentRollNumber(checkId)) continue;
      expectedStudentCount++;
      var checkStatus = statusMap[checkId];
      if (checkStatus === 'P' || checkStatus === 'A' || checkStatus === 'L') {
        completedStudentCount++;
      }
    }
    var hasActualAttendance = expectedStudentCount > 0 && completedStudentCount === expectedStudentCount;

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
    var start = _parseAttendanceDate_(startDateStr) || new Date(startDateStr);
    var target = Object.prototype.toString.call(targetDate) === '[object Date]'
      ? new Date(targetDate.getTime())
      : (_parseAttendanceDate_(targetDate) || new Date(targetDate));
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
    var mssvCol = _findCanonicalStudentColumn_(headerRow);
    var codeCol = _findHeaderColumn_(headerRow, ['CODE', 'STUDENTCODE']);
    var emailCol = -1, hoCol = -1, demCol = -1, tenCol = -1, fullNameCol = -1;
    for (var h = 0; h < headerRow.length; h++) {
      var hText = (headerRow[h] || '').toString().trim().toUpperCase();
      if (hText === 'EMAIL') {
        emailCol = h;
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
      var mssv = (mssvCol >= 0 && row[mssvCol] !== undefined) ? _normalizeStudentKey_(row[mssvCol]) : '';
      var code = (codeCol >= 0 && row[codeCol] !== undefined) ? _normalizeStudentKey_(row[codeCol]) : mssv;
      var defEmail = mssv ? (mssv.toLowerCase() + '@fpt.edu.vn') : '';
      var mssvLower = mssv.toLowerCase();
      var codeLower = code.toLowerCase();
      var isMssvMatch = (mssvLower && (email === mssvLower || email.indexOf(mssvLower) >= 0 || mssvLower.indexOf(email) >= 0)) ||
        (codeLower && (email === codeLower || email.indexOf(codeLower) >= 0 || codeLower.indexOf(email) >= 0));

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
          code: code,
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
    var checkinMeta = _readAttendanceMetadata_(cSheet);
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
      var qSession = parseInt(qRow[4], 10);
      if (isNaN(qSession) && checkinMeta.startDate) {
        var qDateObject = _parseAttendanceDate_(qDateNorm);
        if (qDateObject) qSession = _calcSessionNo(checkinMeta.startDate, qDateObject, checkinMeta.days, checkinMeta.totalSessions);
      }
      var matchSession = qSession === sessionNo;

      if (matchCls && matchDt && matchSl && matchSession && qEmail === email) {
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
    var sessionNo = parseInt(params.session || params.sessionNumber || '1', 10);
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
    var classSheet = _findClassSheet_(ss, cName);
    var qrMeta = _readAttendanceMetadata_(classSheet);

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
        var rSession = parseInt(r[4], 10);
        if (isNaN(rSession) && qrMeta.startDate) {
          var qrDateObject = _parseAttendanceDate_(rDateNorm);
          if (qrDateObject) rSession = _calcSessionNo(qrMeta.startDate, qrDateObject, qrMeta.days, qrMeta.totalSessions);
        }
        var matchSession = rSession === sessionNo;

        if (matchClass && matchDate && matchSlot && matchSession) {
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
      sessionNumber: sessionNo,
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

