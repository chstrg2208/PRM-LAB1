/**
 * Test suite verifying BK-01: Idempotent Attendance Saves & Accurate ABSENT Recalculation
 * Runs directly with Node.js in the repository environment.
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

// 1. Mock Range and Sheet implementations for Google Apps Script
class MockRange {
  constructor(sheet, startRow, startCol, numRows, numCols) {
    this.sheet = sheet;
    this.startRow = startRow; // 1-indexed
    this.startCol = startCol; // 1-indexed
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

  setValue(val) {
    return this.setValues([[val]]);
  }

  setBackground() { return this; }
  setFontColor() { return this; }
  setFontWeight() { return this; }
}

class MockSheet {
  constructor(name) {
    this.name = name;
    this.data = []; // 2D array of rows
  }

  getDataRange() {
    return new MockRange(this, 1, 1, this.data.length, this.data.length > 0 ? Math.max(...this.data.map(r => r.length)) : 0);
  }

  getRange(row, col, numRows = 1, numCols = 1) {
    return new MockRange(this, row, col, numRows, numCols);
  }

  appendRow(row) {
    this.data.push([...row]);
  }

  clearContents() {
    this.data = [];
  }

  clear() {
    this.data = [];
  }

  getLastRow() {
    return this.data.length;
  }
}

class MockSpreadsheet {
  constructor(name = 'Test_DB') {
    this.name = name;
    this.sheets = {};
  }

  getName() {
    return this.name;
  }

  getSheetByName(name) {
    return this.sheets[name] || null;
  }

  insertSheet(name) {
    const sheet = new MockSheet(name);
    this.sheets[name] = sheet;
    return sheet;
  }

  getActiveSheet() {
    const names = Object.keys(this.sheets);
    return names.length > 0 ? this.sheets[names[0]] : this.insertSheet('Sheet1');
  }
}

class MockLock {
  constructor() {
    this.isLocked = false;
  }

  tryLock(timeout) {
    if (this.isLocked) return false;
    this.isLocked = true;
    return true;
  }

  waitLock(timeout) {
    this.isLocked = true;
  }

  releaseLock() {
    this.isLocked = false;
  }
}

// 2. Build Sandbox & Load Code.gs
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
        setMimeType: () => ({
          getContent: () => text,
          json: () => JSON.parse(text)
        })
      })
    },
    console: console,
    Date: Date,
    JSON: JSON,
    parseInt: parseInt,
    isNaN: isNaN,
    Array: Array
  };

  const codeGsPath = path.join(__dirname, '..', 'google-apps-script', 'Code.gs');
  const codeGsContent = fs.readFileSync(codeGsPath, 'utf8');
  vm.createContext(sandbox);
  vm.runInContext(codeGsContent, sandbox);

  return { sandbox, ss, lock };
}

// 3. Automated Test Suite
function runTests() {
  console.log('=== RUNNING GOOGLE APPS SCRIPT BK-01 AUTOMATED TESTS ===\n');
  const { sandbox, ss, lock } = createEnvironment();

  // Khởi tạo sheet SE1801 chuẩn với 3 sinh viên mẫu
  const seSheet = ss.insertSheet('SE1801');
  seSheet.appendRow(['MEMBER', 'CODE', 'SURNAME', 'MIDDLE NAME', 'GIVEN NAME', 'TOTAL SLOTS', 'ABSENT', 'EMAIL']);
  seSheet.appendRow(['CE190585', 'Lâm', 'Quốc', 'Minh', '', 20, 0, 'minhlqce190585@fpt.edu.vn']);
  seSheet.appendRow(['SE170123', 'Nguyễn', 'Văn', 'An', '', 20, 0, 'annvse170123@fpt.edu.vn']);
  seSheet.appendRow(['SE170456', 'Trần', 'Thị', 'Bình', '', 20, 0, 'binhttse170456@fpt.edu.vn']);

  // Chuẩn bị dữ liệu lớp khác (IA1601) để kiểm tra tính độc lập
  const iaSheet = ss.insertSheet('IA1601');
  iaSheet.appendRow(['MEMBER', 'CODE', 'SURNAME', 'MIDDLE NAME', 'GIVEN NAME', 'TOTAL SLOTS', 'ABSENT', 'EMAIL']);
  iaSheet.appendRow(['IA160890', 'Hoàng', 'Mai', 'Phương', '', 20, 0, 'phuonghmia160890@fpt.edu.vn']);

  // Pre-seed Attendance_Logs với 1 log của lớp IA1601
  const logSheet = ss.insertSheet('Attendance_Logs');
  logSheet.appendRow(['Thời gian ghi nhận', 'Lớp', 'Ngày học', 'Slot', 'Mã Sinh Viên (MEMBER)', 'Trạng thái', 'Ghi chú']);
  logSheet.appendRow([new Date(), 'IA1601', '2026-09-20', 2, 'IA160890', 'absent', 'Nghỉ có phép']);
  sandbox._recalculateClassAbsentCount(ss, 'IA1601', logSheet);
  assert.strictEqual(iaSheet.data[1][6], 1, 'Pre-seed IA1601 absent count must be 1');

  // TEST CASE 1: Lưu lần đầu SE1801, 2026-09-22, slot 1 với 2 sinh viên vắng
  console.log('[Test 1] Lưu lần đầu lớp SE1801, ngày 2026-09-22, slot 1 (2 vắng, 1 có mặt)...');
  const req1 = {
    postData: {
      contents: JSON.stringify({
        action: 'saveAttendance',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        records: [
          { rollNumber: 'CE190585', status: 'absent', note: 'Ốm' },
          { rollNumber: 'SE170123', status: 'absent', note: 'Không lý do' },
          { rollNumber: 'SE170456', status: 'present', note: '' }
        ]
      })
    }
  };

  const res1 = sandbox.doPost(req1).json();
  assert.strictEqual(res1.status, 'success', 'Save 1 should succeed');
  assert.strictEqual(res1.recordsCount, 3, 'Should process 3 records');

  // Kiểm tra Attendance_Logs: 1 header + 1 pre-seed IA1601 + 3 records SE1801 = 5 rows
  assert.strictEqual(logSheet.data.length, 5, 'Attendance_Logs must contain exactly 5 rows');

  // Kiểm tra cột ABSENT của SE1801
  assert.strictEqual(seSheet.data[1][6], 1, 'CE190585 ABSENT must be 1');
  assert.strictEqual(seSheet.data[2][6], 1, 'SE170123 ABSENT must be 1');
  assert.strictEqual(seSheet.data[3][6], 0, 'SE170456 ABSENT must be 0');
  console.log('✓ PASS: Lưu lần đầu chính xác (CE190585: 1 vắng, SE170123: 1 vắng, SE170456: 0 vắng).\n');

  // TEST CASE 2: Lưu lần 2 đúng lớp/ngày/slot và cùng dữ liệu (Kiểm tra Idempotent)
  console.log('[Test 2] Lưu lặp lần 2 với cùng dữ liệu lớp/ngày/slot (Kiểm tra tính Idempotent)...');
  const res2 = sandbox.doPost(req1).json();
  assert.strictEqual(res2.status, 'success', 'Save 2 should succeed');

  // Kiểm tra Attendance_Logs không bị nhân đôi
  assert.strictEqual(logSheet.data.length, 5, 'Attendance_Logs must STILL contain 5 rows (not duplicated)');

  // Kiểm tra cột ABSENT không bị cộng dồn
  assert.strictEqual(seSheet.data[1][6], 1, 'CE190585 ABSENT must REMAIN 1 (not duplicated to 2)');
  assert.strictEqual(seSheet.data[2][6], 1, 'SE170123 ABSENT must REMAIN 1 (not duplicated to 2)');
  assert.strictEqual(seSheet.data[3][6], 0, 'SE170456 ABSENT must REMAIN 0');
  console.log('✓ PASS: Tính Idempotent hoàn hảo (Không nhân đôi log, không tăng ABSENT khi lưu lại).\n');

  // TEST CASE 3: Lưu lần 3 đổi SE170123 từ absent sang present
  console.log('[Test 3] Lưu lần 3 đổi SE170123 từ absent sang present...');
  const req3 = {
    postData: {
      contents: JSON.stringify({
        action: 'saveAttendance',
        className: 'SE1801',
        date: '2026-09-22',
        slot: 1,
        records: [
          { rollNumber: 'CE190585', status: 'absent', note: 'Ốm' },
          { rollNumber: 'SE170123', status: 'present', note: 'Đi muộn được điểm danh lại' },
          { rollNumber: 'SE170456', status: 'present', note: '' }
        ]
      })
    }
  };

  const res3 = sandbox.doPost(req3).json();
  assert.strictEqual(res3.status, 'success', 'Save 3 should succeed');

  // Kiểm tra số buổi vắng giảm đúng 1 cho SE170123
  assert.strictEqual(seSheet.data[1][6], 1, 'CE190585 ABSENT remains 1');
  assert.strictEqual(seSheet.data[2][6], 0, 'SE170123 ABSENT decrements to 0');
  assert.strictEqual(seSheet.data[3][6], 0, 'SE170456 ABSENT remains 0');

  // Kiểm tra note được cập nhật
  const se170123Row = logSheet.data.find(r => r[4] === 'SE170123');
  assert.strictEqual(se170123Row[5], 'present', 'SE170123 status in log updated to present');
  assert.strictEqual(se170123Row[6], 'Đi muộn được điểm danh lại', 'SE170123 note updated in log');
  console.log('✓ PASS: Cập nhật đổi trạng thái từ vắng sang có mặt làm giảm ABSENT về 0 chính xác.\n');

  // TEST CASE 4: Xác nhận dữ liệu lớp khác (IA1601) không bị ảnh hưởng
  console.log('[Test 4] Kiểm tra tính độc lập dữ liệu lớp khác (IA1601)...');
  assert.strictEqual(iaSheet.data[1][6], 1, 'IA1601 student absent count must remain 1');
  const iaLog = logSheet.data.find(r => r[1] === 'IA1601');
  assert.ok(iaLog, 'IA1601 log must still exist in Attendance_Logs');
  assert.strictEqual(iaLog[4], 'IA160890', 'IA1601 log student is IA160890');
  console.log('✓ PASS: Dữ liệu của lớp IA1601 hoàn toàn được bảo toàn nguyên vẹn.\n');

  // TEST CASE 5: Kiểm tra ScriptLock và giải phóng lock trong finally
  console.log('[Test 5] Kiểm tra ScriptLock & finally releaseLock...');
  assert.strictEqual(lock.isLocked, false, 'Lock must be released after successful request');

  // Mô phỏng tranh chấp lock khi hệ thống bận
  lock.isLocked = true;
  const busyRes = sandbox.doPost(req1).json();
  assert.strictEqual(busyRes.status, 'error', 'Should return error if lock busy');
  assert.ok(busyRes.message.includes('bận'), 'Error message indicates busy system');
  lock.isLocked = false;
  console.log('✓ PASS: LockService hoạt động chuẩn xác, tự giải phóng lock sau khi xong.\n');

  console.log('🎉 ALL 5 TEST CASES PASSED SUCCESSFULLY!\n');
}

try {
  runTests();
} catch (err) {
  console.error('❌ TEST FAILED:', err);
  process.exit(1);
}
