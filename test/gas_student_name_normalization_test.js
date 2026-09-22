/**
 * Test suite verifying BK-13.1: Student Full Name Normalization in Google Apps Script (Code.gs)
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

console.log('=== RUNNING GOOGLE APPS SCRIPT BK-13.1 STUDENT NAME NORMALIZATION TESTS ===\n');

// Test Suite: getStudents student name normalization
{
  const { sandbox, ss } = createEnvironment();
  const sheet = ss.insertSheet('SE1801');

  // Row 0: Headers
  sheet.appendRow(['RollNumber', 'StudentCode', 'Surname', 'MiddleName', 'GivenName', 'TotalSlots', 'AbsentSlots', 'Email']);

  // Row 1: Đủ họ, đệm, tên
  sheet.appendRow(['an_nv', 'SE170001', 'Nguyễn', 'Văn', 'An', 20, 1, 'annv@fpt.edu.vn']);

  // Row 2: Không có tên đệm
  sheet.appendRow(['binh_l', 'SE170002', 'Lê', '', 'Bình', 20, 2, 'binhl@fpt.edu.vn']);

  // Row 3: Cả họ, đệm, tên rỗng
  sheet.appendRow(['member_unknown', 'SE170003', '', '', '', 20, 0, 'unknown@fpt.edu.vn']);

  // Row 4: Có khoảng trắng thừa ở các phần tên
  sheet.appendRow(['hoa_tt', 'SE170004', '  Trần  ', '  Thị  ', '  Hoa  ', 20, 3, 'hoatt@fpt.edu.vn']);

  // Execute doGet action=getStudents
  const event = {
    parameter: {
      action: 'getStudents',
      className: 'SE1801'
    }
  };

  const output = sandbox.doGet(event);
  const response = JSON.parse(typeof output === 'string' ? output : output._content);

  console.log('[Test 1] API response status và cấu trúc data...');
  assert.strictEqual(response.status, 'success', 'Response status should be success');
  assert(Array.isArray(response.data), 'Response data should be an array');
  assert.strictEqual(response.data.length, 4, 'Should return 4 students');
  console.log('  -> PASS');

  console.log('[Test 2] Kịch bản 1: Đủ họ, đệm, tên -> "Nguyễn Văn An"...');
  const student1 = response.data[0];
  assert.strictEqual(student1.code, 'SE170001');
  assert.strictEqual(student1.surname, 'Nguyễn');
  assert.strictEqual(student1.middleName, 'Văn');
  assert.strictEqual(student1.givenName, 'An');
  assert.strictEqual(student1.fullName, 'Nguyễn Văn An', 'fullName must be correctly concatenated without code');
  console.log('  -> PASS: fullName = ' + student1.fullName);

  console.log('[Test 3] Kịch bản 2: Không có tên đệm -> "Lê Bình" (không có khoảng trắng thừa)...');
  const student2 = response.data[1];
  assert.strictEqual(student2.code, 'SE170002');
  assert.strictEqual(student2.surname, 'Lê');
  assert.strictEqual(student2.middleName, '');
  assert.strictEqual(student2.givenName, 'Bình');
  assert.strictEqual(student2.fullName, 'Lê Bình', 'fullName without middle name must have single space between surname and givenName');
  console.log('  -> PASS: fullName = ' + student2.fullName);

  console.log('[Test 4] Kịch bản 3: Mã sinh viên (code) không xuất hiện trong fullName...');
  for (const s of response.data) {
    if (s.code) {
      assert.strictEqual(s.fullName.includes(s.code), false, `fullName "${s.fullName}" must not contain code "${s.code}"`);
    }
  }
  console.log('  -> PASS: Không sinh viên nào bị ghép code vào fullName');

  console.log('[Test 5] Kịch bản 4: Cả họ tên rỗng -> fallback "Sinh viên " + member...');
  const student3 = response.data[2];
  assert.strictEqual(student3.fullName, 'Sinh viên member_unknown', 'fullName must fallback to "Sinh viên " + member');
  console.log('  -> PASS: fullName = ' + student3.fullName);

  console.log('[Test 6] Kịch bản 5: Khoảng trắng thừa được trim sạch sẽ -> "Trần Thị Hoa"...');
  const student4 = response.data[3];
  assert.strictEqual(student4.fullName, 'Trần Thị Hoa', 'Name parts with extra whitespace must be trimmed');
  console.log('  -> PASS: fullName = ' + student4.fullName);
}

console.log('\n=== ALL BK-13.1 NAME NORMALIZATION TESTS PASSED ===');
