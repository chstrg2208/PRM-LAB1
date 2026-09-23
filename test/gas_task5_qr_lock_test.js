/**
 * Test suite verifying Task 5: QR Lock Anti-Cheat and Manual Edit on Google Apps Script backend
 * Runs directly with Node.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

// 1. Mock Range and Sheet implementations
class MockRange {
  constructor(sheet, startRow, startCol, numRows = 1, numCols = 1) {
    this.sheet = sheet;
    this.startRow = startRow;
    this.startCol = startCol;
    this.numRows = numRows;
    this.numCols = numCols;
  }
  getValues() {
    const result = [];
    for (let r = 0; r < this.numRows; r++) {
      const rowIdx = this.startRow - 1 + r;
      const rowData = [];
      const sourceRow = this.sheet.grid[rowIdx] || [];
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
      if (!this.sheet.grid[rowIdx]) this.sheet.grid[rowIdx] = [];
      for (let c = 0; c < values[r].length; c++) {
        const colIdx = this.startCol - 1 + c;
        this.sheet.grid[rowIdx][colIdx] = values[r][c];
      }
    }
    return this;
  }
  setValue(val) {
    const rowIdx = this.startRow - 1;
    const colIdx = this.startCol - 1;
    if (!this.sheet.grid[rowIdx]) this.sheet.grid[rowIdx] = [];
    this.sheet.grid[rowIdx][colIdx] = val;
    return this;
  }
  setBackground() { return this; }
  setFontColor() { return this; }
  setFontWeight() { return this; }
}

class MockSheet {
  constructor(name, initialData = []) {
    this.name = name;
    this.grid = JSON.parse(JSON.stringify(initialData));
  }
  getName() { return this.name; }
  getLastRow() { return this.grid.length; }
  getLastColumn() {
    let max = 0;
    for (const row of this.grid) {
      if (row.length > max) max = row.length;
    }
    return max;
  }
  getDataRange() {
    const maxCols = this.grid.reduce((m, r) => Math.max(m, r.length), 0);
    return new MockRange(this, 1, 1, Math.max(this.grid.length, 1), Math.max(maxCols, 1));
  }
  getRange(row, col, numRows = 1, numCols = 1) {
    return new MockRange(this, row, col, numRows, numCols);
  }
  appendRow(row) {
    this.grid.push([...row]);
  }
  deleteRow(rowIdx) {
    this.grid.splice(rowIdx - 1, 1);
  }
  clearContents() {
    this.grid = [];
  }
}

class MockSpreadsheet {
  constructor() {
    this.sheets = {};
  }
  getSheetByName(name) {
    return this.sheets[name] || null;
  }
  getSheets() {
    return Object.values(this.sheets);
  }
  insertSheet(name) {
    const s = new MockSheet(name, []);
    this.sheets[name] = s;
    return s;
  }
}

function runTests() {
  console.log('=== RUNNING TASK 5 GOOGLE APPS SCRIPT TESTS: QR LOCK & MANUAL EDIT ===\n');

  const codePath = path.join(__dirname, '../google-apps-script/Code.gs');
  const code = fs.readFileSync(codePath, 'utf8');

  const ss = new MockSpreadsheet();

  // Tab lớp SE1801_PRM393 với Metadata dòng 1-4, trong đó TRẠNG THÁI: Đã điểm danh
  const seSheet = ss.insertSheet('SE1801_PRM393');
  seSheet.grid = [
    ['MÔN HỌC:', 'PRM393', 'LỊCH HỌC:', 'T2-T5 (Slot 1: 07:00 - 09:15)', '', 'PHÒNG:', 'NVH-611'],
    ['NGÀY BẮT ĐẦU:', '07/09/2026', 'BUỔI HIỆN TẠI:', '5 / 20', '', 'TỔNG SỐ BUỔI:', '20'],
    ['NGÀY HỌC TIẾP THEO:', '24/09/2026', 'TRẠNG THÁI BUỔI:', 'Đã điểm danh', '', '', ''],
    ['', '', '', '', '', '', ''],
    ['STT', 'MSSV', 'HỌ', 'TÊN ĐỆM', 'TÊN', 'EMAIL', 'TỔNG BUỔI', 'VẮNG', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6'],
    [1, 'CE190585', 'Lâm', 'Quốc', 'Minh', 'minhlqce190585@fpt.edu.vn', 20, 1, 'P', 'P', 'P', 'P', 'A', ''],
    [2, 'SE170123', 'Nguyễn', 'Văn', 'An', 'annvse170123@fpt.edu.vn', 20, 0, 'P', 'P', 'P', 'P', 'P', '']
  ];

  const sandbox = {
    SpreadsheetApp: { getActiveSpreadsheet: () => ss },
    ContentService: {
      createTextOutput: (str) => ({
        setMimeType: () => ({ json: () => JSON.parse(str), raw: str })
      }),
      MimeType: { JSON: 'application/json' }
    },
    LockService: {
      getScriptLock: () => ({
        tryLock: () => true,
        releaseLock: () => {}
      })
    },
    HtmlService: {
      createHtmlOutput: (html) => ({
        setTitle: function() { return this; },
        setXFrameOptionsMode: function() { return { html: html }; }
      }),
      XFrameOptionsMode: { ALLOWALL: 'ALLOWALL' }
    },
    Session: {
      getActiveUser: () => ({ getEmail: () => 'minhlqce190585@fpt.edu.vn' })
    },
    console: console,
    Date: Date,
    parseInt: parseInt,
    parseFloat: parseFloat,
    Math: Math,
    JSON: JSON
  };

  vm.createContext(sandbox);
  vm.runInContext(code, sandbox);

  // Test 1: Sinh viên cố tình check-in vào buổi học đã có trạng thái "Đã điểm danh" -> Từ chối
  console.log('[Test 1] Kiểm tra chặn quét QR khi buổi học đã "Đã điểm danh"...');
  const reqBlocked = {
    parameter: {
      action: 'studentCheckIn',
      className: 'SE1801',
      slot: '1',
      session: '5',
      token: 'old_expired_token',
      email: 'minhlqce190585@fpt.edu.vn'
    }
  };
  const resBlocked = sandbox.doGet(reqBlocked).json();
  assert.strictEqual(resBlocked.success, false, 'Check-in must be rejected when session is closed');
  assert.ok(resBlocked.message.includes('đã hoàn tất điểm danh QR'), 'Error message must inform session is completed');
  console.log('✓ PASS: Chặn thành công check-in trộm sau khi buổi học đã chốt điểm danh.\n');

  // Test 2: Giảng viên mở lại phiên QR (reopen=true) -> Cho phép check-in
  console.log('[Test 2] Kiểm tra cho phép check-in khi Giảng viên mở lại QR (reopen=true)...');
  const reqReopen = {
    parameter: {
      action: 'studentCheckIn',
      className: 'SE1801',
      slot: '1',
      session: '5',
      token: 'reopened_token_123',
      email: 'minhlqce190585@fpt.edu.vn',
      reopen: 'true'
    }
  };
  const resReopen = sandbox.doGet(reqReopen).json();
  assert.strictEqual(resReopen.success, true, 'Check-in must succeed when reopen=true');
  assert.strictEqual(resReopen.data.student.rollNumber, 'CE190585');
  console.log('✓ PASS: Mở lại QR thành công cho sinh viên hợp lệ khi Giảng viên cho phép.\n');

  // Test 3: Giảng viên sửa tay đổi SV1 từ A sang P và gọi saveAttendance -> Idempotent cập nhật
  console.log('[Test 3] Kiểm tra Giảng viên sửa tay thủ công và lưu lại (Manual Override)...');
  const reqSave = {
    postData: {
      contents: JSON.stringify({
        action: 'saveAttendance',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        sessionNumber: 5,
        bypassDateLock: true,
        records: [
          { rollNumber: 'CE190585', status: 'present', note: 'GV sửa tay có mặt' },
          { rollNumber: 'SE170123', status: 'present', note: '' }
        ]
      })
    }
  };
  const resSave = sandbox.doPost(reqSave).json();
  assert.strictEqual(resSave.status, 'success', 'Save attendance must succeed for manual override');
  // Cột B5 của SV1 (row index 5, col index 12) phải là P
  assert.strictEqual(seSheet.grid[5][12], 'P', 'CE190585 B5 slot status must be updated to P');
  console.log('✓ PASS: Giảng viên toàn quyền sửa tay thủ công và cập nhật thành công lên Sheet.\n');

  console.log('🎉 TẤT CẢ 3/3 KIỂM THỬ TASK 5 BACKEND GAS ĐÃ VƯỢT QUA 100%!\n');
}

try {
  runTests();
} catch (err) {
  console.error('❌ TEST FAILED:', err);
  process.exit(1);
}
