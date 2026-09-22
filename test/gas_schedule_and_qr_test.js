/**
 * Test suite verifying FPT 4-Slot Schedule, Today's Classes, and Dynamic QR Check-in in Google Apps Script (Code.gs)
 * Runs with Node.js in the repository environment.
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

class MockRange {
  constructor(sheet, startRow, startCol, numRows, numCols) {
    this.sheet = sheet;
    this.startRow = startRow;
    this.startCol = startCol;
    this.numRows = numRows || 1;
    this.numCols = numCols || 1;
  }

  getValues() {
    const result = [];
    for (let r = 0; r < this.numRows; r++) {
      const rowIdx = this.startRow - 1 + r;
      const rowData = [];
      const sourceRow = this.sheet.data[rowIdx] || [];
      for (let c = 0; c < this.numCols; c++) {
        const colIdx = this.startCol - 1 + c;
        rowData.push(sourceRow[colIdx] !== undefined ? sourceRow[colIdx] : '');
      }
      result.push(rowData);
    }
    return result;
  }

  setValues(values) {
    for (let r = 0; r < values.length; r++) {
      const rowIdx = this.startRow - 1 + r;
      if (!this.sheet.data[rowIdx]) {
        this.sheet.data[rowIdx] = [];
      }
      for (let c = 0; c < values[r].length; c++) {
        const colIdx = this.startCol - 1 + c;
        this.sheet.data[rowIdx][colIdx] = values[r][c];
      }
    }
    return this;
  }

  setValue(val) { return this.setValues([[val]]); }
  setBackground() { return this; }
  setFontColor() { return this; }
  setFontWeight() { return this; }
}

class MockSheet {
  constructor(name, hidden = false) {
    this.name = name;
    this.hidden = hidden;
    this.data = [];
  }

  getName() { return this.name; }
  isSheetHidden() { return this.hidden; }

  getDataRange() {
    return new MockRange(this, 1, 1, this.data.length, this.data.length > 0 ? Math.max(...this.data.map(r => r.length)) : 0);
  }

  getRange(row, col, numRows = 1, numCols = 1) {
    return new MockRange(this, row, col, numRows, numCols);
  }

  appendRow(row) { this.data.push([...row]); }
  clearContents() { this.data = []; }
  clear() { this.data = []; }
  getLastRow() { return this.data.length; }
}

class MockSpreadsheet {
  constructor(name = 'Test_DB') {
    this.name = name;
    this.sheets = {};
  }

  getName() { return this.name; }
  getSheetByName(name) { return this.sheets[name] || null; }
  insertSheet(name, hidden = false) {
    const sheet = new MockSheet(name, hidden);
    this.sheets[name] = sheet;
    return sheet;
  }
  getSheets() { return Object.values(this.sheets); }
}

class MockLock {
  constructor() { this.isLocked = false; }
  tryLock() { return true; }
  waitLock() {}
  releaseLock() { this.isLocked = false; }
}

function createEnvironment() {
  const ss = new MockSpreadsheet('FAP_ATTENDANCE_DB');
  const lock = new MockLock();

  const sandbox = {
    SpreadsheetApp: {
      getActiveSpreadsheet: () => ss,
      insertSheet: (n) => ss.insertSheet(n)
    },
    LockService: {
      getScriptLock: () => lock
    },
    ContentService: {
      MimeType: { JSON: 'application/json' },
      createTextOutput: (text) => ({
        setMimeType: () => text,
        _content: text
      })
    },
    HtmlService: {
      createHtmlOutput: (html) => ({
        setTitle: function() { return this; },
        setXFrameOptionsMode: function() { return this; },
        getContent: () => html
      }),
      XFrameOptionsMode: { ALLOWALL: 'ALLOWALL' }
    },
    Logger: { log: () => {} },
    console: console,
    Date: Date,
    JSON: JSON,
    parseInt: parseInt,
    parseFloat: parseFloat,
    isNaN: isNaN,
    String: String
  };

  const codePath = path.join(__dirname, '..', 'google-apps-script', 'Code.gs');
  const code = fs.readFileSync(codePath, 'utf-8');

  vm.createContext(sandbox);
  vm.runInContext(code, sandbox);

  return { sandbox, ss };
}

console.log('=== RUNNING GOOGLE APPS SCRIPT SCHEDULE & QR TESTS ===\n');

// Test 1: getTodayClasses logic
{
  console.log('[Test 1] Kiểm tra getTodayClasses theo thứ trong tuần...');
  const { sandbox, ss } = createEnvironment();

  // Tạo sheet học sinh cho SE1801 và IA1601
  const sheetSE = ss.insertSheet('SE1801');
  sheetSE.appendRow(['MEMBER', 'CODE', 'SURNAME', 'MIDDLE NAME', 'GIVEN NAME', 'TOTAL SLOTS', 'ABSENT', 'EMAIL']);
  sheetSE.appendRow(['SE170123', 'SE170123', 'Nguyễn', 'Văn', 'An', 20, 0, 'annvse170123@fpt.edu.vn']);
  sheetSE.appendRow(['SE170456', 'SE170456', 'Trần', 'Thị', 'Bình', 20, 0, 'binhttse170456@fpt.edu.vn']);

  // Tạo _Class_Schedules
  const schedSheet = ss.insertSheet('_Class_Schedules');
  schedSheet.appendRow(['CLASS_NAME', 'SUBJECT_CODE', 'SLOT', 'DAYS_OF_WEEK', 'ROOM', 'START_DATE', 'TOTAL_SESSIONS']);
  // SE1801 học T2-T5, slot 1
  schedSheet.appendRow(['SE1801', 'PRM393', 1, 'T2-T5', 'BE-302', '2026-09-01', 20]);
  // IA1601 học T3-T6, slot 2
  schedSheet.appendRow(['IA1601', 'PRM393', 2, 'T3-T6', 'BE-304', '2026-09-01', 20]);

  // Ngày 2026-09-21 là Thứ Hai (Monday = 1) -> Chỉ có SE1801 (T2-T5)
  const reqMon = { parameter: { action: 'getTodayClasses', date: '2026-09-21' } };
  const resMon = JSON.parse(sandbox.doGet(reqMon));
  assert.strictEqual(resMon.success, true);
  assert.strictEqual(resMon.data.length, 1);
  assert.strictEqual(resMon.data[0].className, 'SE1801');
  assert.strictEqual(resMon.data[0].slot, 1);
  assert.strictEqual(resMon.data[0].slotTime, '07:00 - 09:15');
  assert.strictEqual(resMon.data[0].totalStudents, 2);
  console.log('  -> PASS: Thứ Hai lấy đúng lớp SE1801, slot 1 (07:00 - 09:15)');

  // Ngày 2026-09-22 là Thứ Ba (Tuesday = 2) -> Chỉ có IA1601 (T3-T6)
  const reqTue = { parameter: { action: 'getTodayClasses', date: '2026-09-22' } };
  const resTue = JSON.parse(sandbox.doGet(reqTue));
  assert.strictEqual(resTue.success, true);
  assert.strictEqual(resTue.data.length, 1);
  assert.strictEqual(resTue.data[0].className, 'IA1601');
  assert.strictEqual(resTue.data[0].slot, 2);
  assert.strictEqual(resTue.data[0].slotTime, '09:30 - 11:45');
  console.log('  -> PASS: Thứ Ba lấy đúng lớp IA1601, slot 2 (09:30 - 11:45)');

  // Ngày 2026-09-27 là Chủ Nhật (Sunday = 0) -> Không có lớp nào
  const reqSun = { parameter: { action: 'getTodayClasses', date: '2026-09-27' } };
  const resSun = JSON.parse(sandbox.doGet(reqSun));
  assert.strictEqual(resSun.success, true);
  assert.strictEqual(resSun.data.length, 0);
  console.log('  -> PASS: Chủ Nhật không có tiết');
}

// Test 2: studentCheckIn & getQrStatus
{
  console.log('[Test 2] Kiểm tra sinh viên check-in qua QR bằng Email FPT...');
  const { sandbox, ss } = createEnvironment();

  const sheetSE = ss.insertSheet('SE1801');
  sheetSE.appendRow(['MEMBER', 'CODE', 'SURNAME', 'MIDDLE NAME', 'GIVEN NAME', 'TOTAL SLOTS', 'ABSENT', 'EMAIL']);
  sheetSE.appendRow(['SE170123', 'SE170123', 'Nguyễn', 'Văn', 'An', 20, 0, 'annvse170123@fpt.edu.vn']);

  // Case 2.1: Check-in email hợp lệ có trong lớp
  const checkinReq = {
    parameter: {
      action: 'studentCheckIn',
      className: 'SE1801',
      slot: '1',
      session: '5',
      date: '2026-09-21',
      token: 'FAP_123456',
      email: 'annvse170123@fpt.edu.vn'
    }
  };
  const checkinRes = JSON.parse(sandbox.doGet(checkinReq));
  assert.strictEqual(checkinRes.success, true);
  assert.strictEqual(checkinRes.data.student.fullName, 'Nguyễn Văn An');
  console.log('  -> PASS: Check-in thành công cho email hợp lệ');

  // Case 2.2: Check-in email không có trong lớp
  const invalidReq = {
    parameter: {
      action: 'studentCheckIn',
      className: 'SE1801',
      slot: '1',
      email: 'unknown@fpt.edu.vn'
    }
  };
  const invalidRes = JSON.parse(sandbox.doGet(invalidReq));
  assert.strictEqual(invalidRes.success, false);
  console.log('  -> PASS: Chặn email lạ không có trong danh sách');

  // Case 2.3: Lấy trạng thái QR
  const statusReq = {
    parameter: {
      action: 'getQrStatus',
      className: 'SE1801',
      slot: '1',
      date: '2026-09-21'
    }
  };
  const statusRes = JSON.parse(sandbox.doGet(statusReq));
  assert.strictEqual(statusRes.success, true);
  assert.strictEqual(statusRes.data.length, 1);
  assert.strictEqual(statusRes.data[0].email, 'annvse170123@fpt.edu.vn');
  console.log('  -> PASS: getQrStatus trả về đúng email vừa check-in');
}

console.log('\n=== ALL SCHEDULE & QR GAS TESTS PASSED ===');
