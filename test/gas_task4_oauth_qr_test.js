// test/gas_task4_oauth_qr_test.js
// Kiểm thử Task 4 cho Google Apps Script: Điểm danh QR Động, OAuth Email Check-In và Lấy trạng thái QR

const assert = require('assert');
const fs = require('fs');
const path = require('path');

console.log('--- BẮT ĐẦU KIỂM THỬ TASK 4 (OAUTH QR CHECK-IN & 3 STATES) ---');

// Mock môi trường GAS
const mockSheets = {};

class MockRange {
  constructor(sheet, startRow, startCol, numRows = 1, numCols = 1) {
    this.sheet = sheet;
    this.startRow = startRow;
    this.startCol = startCol;
    this.numRows = numRows;
    this.numCols = numCols;
  }

  getValues() {
    const res = [];
    for (let r = 0; r < this.numRows; r++) {
      const rowArr = [];
      const actualRow = this.startRow + r;
      for (let c = 0; c < this.numCols; c++) {
        const actualCol = this.startCol + c;
        const rowData = this.sheet.grid[actualRow - 1] || [];
        rowArr.push(rowData[actualCol - 1] !== undefined ? rowData[actualCol - 1] : '');
      }
      res.push(rowArr);
    }
    return res;
  }

  setValues(values) {
    for (let r = 0; r < values.length; r++) {
      const actualRow = this.startRow + r;
      if (!this.sheet.grid[actualRow - 1]) {
        this.sheet.grid[actualRow - 1] = [];
      }
      for (let c = 0; c < values[r].length; c++) {
        const actualCol = this.startCol + c;
        this.sheet.grid[actualRow - 1][actualCol - 1] = values[r][c];
      }
    }
  }

  setValue(val) {
    const actualRow = this.startRow;
    const actualCol = this.startCol;
    if (!this.sheet.grid[actualRow - 1]) {
      this.sheet.grid[actualRow - 1] = [];
    }
    this.sheet.grid[actualRow - 1][actualCol - 1] = val;
  }

  setBackground(c) {}
  setFontColor(c) {}
  setFontWeight(w) {}
}

class MockSheet {
  constructor(name, initialData = []) {
    this.name = name;
    this.grid = JSON.parse(JSON.stringify(initialData));
  }
  getName() { return this.name; }
  getDataRange() {
    const numRows = Math.max(this.grid.length, 1);
    let maxCols = 1;
    for (const r of this.grid) {
      if (r && r.length > maxCols) maxCols = r.length;
    }
    return new MockRange(this, 1, 1, numRows, maxCols);
  }
  getRange(startRow, startCol, numRows = 1, numCols = 1) {
    return new MockRange(this, startRow, startCol, numRows, numCols);
  }
  getLastRow() { return this.grid.length; }
  getLastColumn() {
    let maxCols = 1;
    for (const r of this.grid) {
      if (r && r.length > maxCols) maxCols = r.length;
    }
    return maxCols;
  }
  appendRow(rowValues) {
    this.grid.push([...rowValues]);
  }
  insertSheet(name) {
    const s = new MockSheet(name);
    mockSheets[name] = s;
    return s;
  }
}

const mockSpreadsheet = {
  getName: () => 'PRM-FA26 Database',
  getSheetByName: (name) => mockSheets[name] || null,
  getSheets: () => Object.values(mockSheets),
  insertSheet: (name) => {
    const s = new MockSheet(name);
    mockSheets[name] = s;
    return s;
  }
};

let activeUserEmail = '';
const mockSession = {
  getActiveUser: () => ({
    getEmail: () => activeUserEmail
  })
};

// Khởi tạo tab lớp SE1801_PRM393 chuẩn template
mockSheets['SE1801_PRM393'] = new MockSheet('SE1801_PRM393', [
  ['MÔN HỌC:', 'PRM393', '', 'PHÒNG HỌC:', 'NVH-611', '', ''],
  ['LỊCH HỌC:', 'T2-T5 (Slot 1: 07:00 - 09:15)', '', 'NGÀY BẮT ĐẦU:', '07/09/2026', '', ''],
  ['BUỔI HIỆN TẠI:', '5 / 20', '', 'TỔNG SỐ BUỔI:', '20', '', ''],
  ['NGÀY HỌC TIẾP THEO:', '24/09/2026', '', 'TRẠNG THÁI BUỔI:', 'Chưa điểm danh', '', ''],
  ['STT', 'MSSV', 'HỌ', 'TÊN ĐỆM', 'TÊN', 'EMAIL', 'TỔNG BUỔI', 'VẮNG', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6'],
  [1, 'SE180101', 'Nguyễn', 'Văn', 'An', 'annvse180101@fpt.edu.vn', 20, 0, 'P', 'P', 'P', 'P', '', ''],
  [2, 'SE180102', 'Trần', 'Thị', 'Bình', 'binhttse180102@fpt.edu.vn', 20, 0, 'P', 'P', 'P', 'P', '', '']
]);

// Nạp mã nguồn Code.gs
const codePath = path.join(__dirname, '../google-apps-script/Code.gs');
const codeContent = fs.readFileSync(codePath, 'utf8');

const context = {
  SpreadsheetApp: { getActiveSpreadsheet: () => mockSpreadsheet },
  ContentService: {
    MimeType: { JSON: 'application/json' },
    createTextOutput: (str) => {
      const output = {
        str: str,
        getContent: () => str,
        json: () => JSON.parse(str),
        setMimeType: function() { return this; }
      };
      return output;
    }
  },
  HtmlService: {
    XFrameOptionsMode: { ALLOWALL: 'ALLOWALL' },
    createHtmlOutput: (html) => ({
      html: html,
      setTitle: function() { return this; },
      setXFrameOptionsMode: function() { return this; },
      getContent: () => html
    })
  },
  Session: mockSession,
  console: console
};

const vm = require('vm');
vm.createContext(context);
vm.runInContext(codeContent, context);

// 1. TEST CASE 1: Sinh viên check-in thành công qua OAuth Google/Email FPT
console.log('\n--- 1. Kiểm thử Sinh viên Check-in OAuth Email hợp lệ ---');
activeUserEmail = 'annvse180101@fpt.edu.vn'; // Giả lập OAuth Google trả về email này

const checkInRes1 = context.doGet({
  parameter: {
    action: 'studentCheckIn',
    className: 'SE1801', // Khớp theo prefix SE1801 -> SE1801_PRM393
    slot: '1',
    session: '5',
    date: '2026-09-22',
    token: 'FAP_123456'
  }
}).json();

assert.strictEqual(checkInRes1.success, true, 'Check-in sinh viên hợp lệ phải thành công');
assert.strictEqual(checkInRes1.data.student.rollNumber, 'SE180101', 'MSSV phải là SE180101');
assert.strictEqual(checkInRes1.data.student.fullName, 'Nguyễn Văn An', 'Tên đầy đủ chính xác');
console.log('✓ Test 1: Sinh viên Nguyễn Văn An check-in OAuth thành công: PASS');

// 2. TEST CASE 2: Sinh viên check-in với Email KHÔNG có trong danh sách lớp
console.log('\n--- 2. Kiểm thử Từ chối Email không thuộc danh sách sinh viên lớp ---');
activeUserEmail = 'hacker@gmail.com';

const checkInRes2 = context.doGet({
  parameter: {
    action: 'studentCheckIn',
    className: 'SE1801',
    slot: '1',
    session: '5',
    date: '2026-09-22',
    token: 'FAP_123456'
  }
}).json();

assert.strictEqual(checkInRes2.success, false, 'Email lạ không được phép check-in');
assert.ok(checkInRes2.message.includes('không có trong danh sách sinh viên lớp'), 'Thông báo lỗi chính xác');
console.log('✓ Test 2: Từ chối thành công email ngoài danh sách: PASS');

// 3. TEST CASE 3: Lấy danh sách email đã quét QR qua API getQrStatus
console.log('\n--- 3. Kiểm thử API getQrStatus trả về sinh viên đã check-in ---');
const qrStatusRes = context.doGet({
  parameter: {
    action: 'getQrStatus',
    className: 'SE1801',
    slot: '1',
    date: '2026-09-22'
  }
}).json();

assert.strictEqual(qrStatusRes.success, true, 'getQrStatus phải thành công');
assert.strictEqual(qrStatusRes.total, 1, 'Tổng số SV đã check in là 1');
assert.strictEqual(qrStatusRes.data[0].email, 'annvse180101@fpt.edu.vn', 'Email trong danh sách khớp');
console.log('✓ Test 3: API getQrStatus trả về đúng email sinh viên đã quét: PASS');

// 4. TEST CASE 4: Giao diện HTML Check-in chứa thông tin OAuth
console.log('\n--- 4. Kiểm thử Giao diện Web Form checkinForm ---');
activeUserEmail = 'annvse180101@fpt.edu.vn';
const htmlRes = context.doGet({
  parameter: {
    action: 'checkinForm',
    class: 'SE1801',
    slot: '1',
    session: '5',
    token: 'FAP_123456'
  }
}).getContent();

assert.ok(htmlRes.includes('Điểm Danh QR'), 'HTML phải có tiêu đề Điểm Danh QR');
assert.ok(htmlRes.includes('annvse180101@fpt.edu.vn'), 'HTML phải hiển thị email OAuth');
assert.ok(htmlRes.includes('Xác Nhận Có Mặt'), 'HTML phải có nút xác nhận có mặt');
console.log('✓ Test 4: Giao diện Web Form kết nối OAuth Google chuẩn xác: PASS');

console.log('\n>>> TẤT CẢ 4/4 KIỂM THỬ TASK 4 GAS ĐÃ VƯỢT QUA 100%! <<<\n');
