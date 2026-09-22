/**
 * Test suite verifying BK-12: Dynamic Classes Endpoint (action=getClasses) in Google Apps Script
 * Runs with Node.js in the repository environment.
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

// 1. Mock Range and Sheet implementations for Google Apps Script
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

  getName() {
    return this.name;
  }

  isSheetHidden() {
    return this.hidden;
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

  insertSheet(name, hidden = false) {
    const sheet = new MockSheet(name, hidden);
    this.sheets[name] = sheet;
    return sheet;
  }

  getSheets() {
    return Object.values(this.sheets);
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

console.log('=== RUNNING GOOGLE APPS SCRIPT BK-12 GETCLASSES TESTS ===\n');

// Test 1: Lấy danh sách lớp thành công, loại trừ Attendance_Logs, sheet ẩn, sheet bắt đầu _, trim, sort
{
  console.log('[Test 1] Kiểm tra getClasses: lọc sheet ẩn, Attendance_Logs, sheet metadata, trim và sort A-Z...');
  const { sandbox, ss } = createEnvironment();

  // Thêm các sheets vào mock spreadsheet:
  ss.insertSheet('SE1802');
  ss.insertSheet('Attendance_Logs'); // Hệ thống - phải bỏ
  ss.insertSheet('attendance_logs'); // Hệ thống - phải bỏ (case-insensitive)
  ss.insertSheet('SE1801');
  ss.insertSheet('_Template'); // Sheet ẩn/metadata - phải bỏ
  ss.insertSheet('.Config'); // Sheet hệ thống - phải bỏ
  ss.insertSheet('Hidden_Class', true); // isSheetHidden = true - phải bỏ
  ss.insertSheet(' IA1801 '); // Cần trim khoảng trắng -> IA1801
  ss.insertSheet('PRM392-Lab');
  ss.insertSheet('SE1801'); // Trùng lặp - phải loại

  const req = {
    parameter: {
      action: 'getClasses'
    }
  };

  const resJson = sandbox.doGet(req);
  const res = JSON.parse(resJson);

  assert.strictEqual(res.success, true, 'Response phải có success: true');
  assert.strictEqual(res.status, 'success', 'Response phải có status: success');
  assert.strictEqual(Array.isArray(res.data), true, 'Data phải là một mảng');
  assert.strictEqual(res.total, 4, `Tổng số lớp hợp lệ phải là 4, thực tế: ${res.total}`);

  // Thứ tự phải sắp xếp A-Z: IA1801, PRM392-Lab, SE1801, SE1802
  assert.deepStrictEqual(res.data, ['IA1801', 'PRM392-Lab', 'SE1801', 'SE1802'], 'Danh sách lớp phải được lọc đúng và sắp xếp A-Z');
  console.log('✓ PASS: getClasses lọc sạch sheet hệ thống, sheet ẩn, trùng lặp và sắp xếp chính xác!\n');
}

// Test 2: Bảng tính chỉ có Attendance_Logs hoặc sheet rỗng
{
  console.log('[Test 2] Kiểm tra bảng tính chỉ có sheet hệ thống Attendance_Logs...');
  const { sandbox, ss } = createEnvironment();
  ss.insertSheet('Attendance_Logs');

  const req = {
    parameter: {
      action: 'getClasses'
    }
  };

  const res = JSON.parse(sandbox.doGet(req));
  assert.strictEqual(res.success, true);
  assert.strictEqual(res.total, 0);
  assert.deepStrictEqual(res.data, []);
  console.log('✓ PASS: Trả về danh sách rỗng an toàn khi không có sheet lớp học nào!\n');
}

console.log('🎉 ALL GOOGLE APPS SCRIPT BK-12 TESTS PASSED SUCCESSFULLY!\n');
