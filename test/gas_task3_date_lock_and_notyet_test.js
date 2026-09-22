// test/gas_task3_date_lock_and_notyet_test.js
// Kiểm thử Task 3 cho Google Apps Script: Date Lock & Trạng thái Not Yet (Chưa điểm danh)

const assert = require('assert');
const fs = require('fs');
const path = require('path');

console.log('--- BẮT ĐẦU KIỂM THỬ TASK 3 (DATE LOCK & NOT YET STATUS) ---');

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
    const maxCols = this.grid.reduce((m, r) => Math.max(m, r.length), 0);
    return new MockRange(this, 1, 1, Math.max(this.grid.length, 1), Math.max(maxCols, 1));
  }
  getRange(row, col, numRows = 1, numCols = 1) {
    return new MockRange(this, row, col, numRows, numCols);
  }
  clearContents() {
    this.grid = [];
  }
  appendRow(row) {
    this.grid.push([...row]);
  }
}

const mockSpreadsheet = {
  getSheetByName(name) {
    return mockSheets[name] || null;
  },
  getSheets() {
    return Object.values(mockSheets);
  },
  insertSheet(name) {
    const s = new MockSheet(name, []);
    mockSheets[name] = s;
    return s;
  }
};

global.SpreadsheetApp = {
  getActiveSpreadsheet: () => mockSpreadsheet
};

global.LockService = {
  getScriptLock: () => ({
    tryLock: () => true,
    releaseLock: () => {}
  })
};

global.ContentService = {
  MimeType: { JSON: 'application/json' },
  createTextOutput: (str) => ({
    setMimeType: () => JSON.parse(str),
    getContent: () => str
  })
};

global.Utilities = {
  formatDate: (d, tz, format) => {
    // Luôn trả về 2026-09-22 cho ngày kiểm thử hiện tại
    return '2026-09-22';
  }
};

// Đọc mã nguồn Code.gs
const gasCode = fs.readFileSync(path.join(__dirname, '../google-apps-script/Code.gs'), 'utf8');
eval(gasCode);

// Thiết lập dữ liệu mẫu lớp IA1601_CSN101 (học T3-T6, slot 2)
const sampleIA1601Grid = [
  ['Môn học:', 'CSN101 - An toàn thông tin', 'Buổi hiện tại:', '5 / 20'],
  ['Lịch & Slot:', 'T3-T6 | Slot 2 (09:30 - 11:45)', 'Ngày học tiếp theo:', '22/09/2026'],
  ['Phòng học:', 'NVH-603', 'Trạng thái buổi:', 'Chưa điểm danh'],
  ['Ngày bắt đầu:', '07/09/2026', 'Tổng số buổi:', 20],
  ['STT', 'MSSV', 'HỌ', 'TÊN ĐỆM', 'TÊN', 'EMAIL', 'TỔNG BUỔI', 'VẮNG', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6'],
  [1, 'IA160001', 'Nguyễn', 'Văn', 'An', 'annvia160001@fpt.edu.vn', 20, 1, 'P', 'P', 'A', 'P', '', ''],
  [2, 'IA160002', 'Trần', 'Thị', 'Bình', 'binhtttia160002@fpt.edu.vn', 20, 0, 'P', 'P', 'P', 'P', '', '']
];

mockSheets['IA1601_CSN101'] = new MockSheet('IA1601_CSN101', sampleIA1601Grid);
mockSheets['Attendance_Logs'] = new MockSheet('Attendance_Logs', [
  ['Thời gian ghi nhận', 'Lớp', 'Ngày học', 'Slot', 'Mã Sinh Viên (MEMBER)', 'Trạng thái', 'Ghi chú'],
  ['2026-09-08', 'IA1601_CSN101', '2026-09-08', 2, 'IA160001', 'present', ''],
  ['2026-09-08', 'IA1601_CSN101', '2026-09-08', 2, 'IA160002', 'present', ''],
  ['2026-09-11', 'IA1601_CSN101', '2026-09-11', 2, 'IA160001', 'present', ''],
  ['2026-09-11', 'IA1601_CSN101', '2026-09-11', 2, 'IA160002', 'present', ''],
  ['2026-09-15', 'IA1601_CSN101', '2026-09-15', 2, 'IA160001', 'absent', ''],
  ['2026-09-15', 'IA1601_CSN101', '2026-09-15', 2, 'IA160002', 'present', ''],
  ['2026-09-18', 'IA1601_CSN101', '2026-09-18', 2, 'IA160001', 'present', ''],
  ['2026-09-18', 'IA1601_CSN101', '2026-09-18', 2, 'IA160002', 'present', '']
]);

// 1. Kiểm thử Date Lock
console.log('\n--- 1. Kiểm thử Date Lock (Chặn điểm danh trước 00:00 ngày học) ---');
const futurePostReq = {
  postData: {
    contents: JSON.stringify({
      action: 'saveAttendance',
      className: 'IA1601_CSN101',
      date: '2026-09-25', // Ngày tương lai so với hôm nay 2026-09-22
      slot: 2,
      sessionNumber: 6,
      records: [
        { rollNumber: 'IA160001', status: 'present' }
      ]
    })
  }
};
const futureRes = doPost(futurePostReq);
assert.strictEqual(futureRes.status, 'error', 'Phải từ chối lưu ngày tương lai');
assert.strictEqual(futureRes.error, 'date_locked', 'Mã lỗi phải là date_locked');
console.log('✓ Test 1: Date Lock chặn thành công điểm danh ngày tương lai 2026-09-25: PASS');

// 2. Kiểm thử Trạng thái Not Yet: Khi GV chưa điểm danh slot (status = notyet)
console.log('\n--- 2. Kiểm thử Not Yet (Không tự ý gán Absent hay Present khi GV chưa điểm danh) ---');
const notYetPostReq = {
  postData: {
    contents: JSON.stringify({
      action: 'saveAttendance',
      className: 'IA1601_CSN101',
      date: '2026-09-22', // Ngày hôm nay
      slot: 2,
      sessionNumber: 5,
      records: [
        { rollNumber: 'IA160001', status: 'notyet' },
        { rollNumber: 'IA160002', status: 'notyet' }
      ]
    })
  }
};
const notYetRes = doPost(notYetPostReq);
assert.strictEqual(notYetRes.status, 'success');

// Kiểm tra cell B5 của sinh viên trong sheet: Phải để trống rỗng '', KHÔNG ĐƯỢC LÀ 'P' hay 'A'
const iaSheet = mockSheets['IA1601_CSN101'];
const student1_B5 = iaSheet.grid[5][12]; // Dòng 6 (index 5), Cột M (index 12 là B5)
const student2_B5 = iaSheet.grid[6][12];
assert.strictEqual(student1_B5, '', 'B5 của SV1 chưa điểm danh phải để rỗng');
assert.strictEqual(student2_B5, '', 'B5 của SV2 chưa điểm danh phải để rỗng');

// Kiểm tra cột VẮNG: SV1 vẫn là 1 vắng (từ B3), KHÔNG bị tăng lên vì B5 là notyet
const student1_absent = iaSheet.grid[5][7];
assert.strictEqual(student1_absent, 1, 'SV1 số buổi vắng không đổi khi slot là notyet');

// Kiểm tra Attendance_Logs: Không được ghi nhận log cho các bản ghi notyet
const logs = mockSheets['Attendance_Logs'].grid;
const hasNotYetLogInDb = logs.some(r => r[1] === 'IA1601_CSN101' && r[2] === '2026-09-22' && (r[5] === 'notyet' || r[5] === 'present' || r[5] === 'absent'));
assert.strictEqual(hasNotYetLogInDb, false, 'Attendance_Logs không chứa log rỗng của slot chưa điểm danh');
console.log('✓ Test 2: Trạng thái Not Yet giữ ô slot rỗng và không tăng số buổi vắng: PASS');

// 3. Kiểm thử Tự động tính Next Date và tăng Buổi hiện tại khi GV thực sự điểm danh (P, A)
console.log('\n--- 3. Kiểm thử Tự động chuyển Next Date sau khi hoàn thành buổi học ---');
const actualPostReq = {
  postData: {
    contents: JSON.stringify({
      action: 'saveAttendance',
      className: 'IA1601_CSN101',
      date: '2026-09-22', // Thứ 3
      slot: 2,
      sessionNumber: 5,
      records: [
        { rollNumber: 'IA160001', status: 'present' },
        { rollNumber: 'IA160002', status: 'absent' }
      ]
    })
  }
};
const actualRes = doPost(actualPostReq);
assert.strictEqual(actualRes.status, 'success');

// Kiểm tra B5: SV1 là 'P', SV2 là 'A'
assert.strictEqual(iaSheet.grid[5][12], 'P', 'SV1 B5 phải ghi P');
assert.strictEqual(iaSheet.grid[6][12], 'A', 'SV2 B5 phải ghi A');

// Kiểm tra cột VẮNG SV2: Tăng từ 0 lên 1
assert.strictEqual(iaSheet.grid[6][7], 1, 'SV2 số buổi vắng tăng lên 1');

// Kiểm tra Dòng 1-4 Metadata:
// 3.1. Buổi hiện tại tăng từ '5 / 20' lên '6 / 20'
const currentSessVal = iaSheet.grid[0][3];
assert.strictEqual(currentSessVal, '6 / 20', 'Buổi hiện tại phải tăng lên 6 / 20');

// 3.2. Ngày học tiếp theo: Lớp T3-T6, từ Thứ 3 (22/09) -> Thứ 6 (25/09/2026)
const nextDateVal = iaSheet.grid[1][3];
assert.strictEqual(nextDateVal, '25/09/2026', 'Ngày học tiếp theo phải chuyển thành 25/09/2026');

// 3.3. Trạng thái buổi đổi thành 'Đã điểm danh'
const sessionStatusVal = iaSheet.grid[2][3];
assert.strictEqual(sessionStatusVal, 'Đã điểm danh', 'Trạng thái buổi phải đổi thành Đã điểm danh');
console.log('✓ Test 3: Tự động cập nhật Buổi hiện tại (6/20), Next Date (25/09/2026), và Trạng thái buổi: PASS');

// 4. Kiểm thử Giáo viên sửa lại điểm danh thủ công (Manual Edit - Idempotent)
console.log('\n--- 4. Kiểm thử GV sửa thủ công: Đổi SV2 từ Absent sang Present ---');
const rePostReq = {
  postData: {
    contents: JSON.stringify({
      action: 'saveAttendance',
      className: 'IA1601_CSN101',
      date: '2026-09-22',
      slot: 2,
      sessionNumber: 5,
      records: [
        { rollNumber: 'IA160001', status: 'present' },
        { rollNumber: 'IA160002', status: 'present' } // Sửa từ absent sang present
      ]
    })
  }
};
const reRes = doPost(rePostReq);
assert.strictEqual(reRes.status, 'success');
assert.strictEqual(iaSheet.grid[6][12], 'P', 'B5 của SV2 được cập nhật thành P');
assert.strictEqual(iaSheet.grid[6][7], 0, 'Số buổi vắng của SV2 giảm lại về 0 sau khi sửa');
console.log('✓ Test 4: GV sửa lại thủ công thành công và số buổi vắng tự động tính lại chuẩn xác: PASS');

console.log('\n>>> TẤT CẢ 4/4 KIỂM THỬ TASK 3 ĐÃ VƯỢT QUA 100%! <<<');
