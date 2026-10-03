/**
 * Regression tests for safe roster upsert.
 * syncStudents must not delete metadata, ABSENT, B1..B20, or old roster rows.
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
    const values = [];
    for (let r = 0; r < this.numRows; r++) {
      const row = this.sheet.data[this.startRow - 1 + r] || [];
      const result = [];
      for (let c = 0; c < this.numCols; c++) {
        result.push(row[this.startCol - 1 + c] === undefined ? '' : row[this.startCol - 1 + c]);
      }
      values.push(result);
    }
    return values;
  }

  setValues(values) {
    for (let r = 0; r < values.length; r++) {
      const rowIndex = this.startRow - 1 + r;
      if (!this.sheet.data[rowIndex]) this.sheet.data[rowIndex] = [];
      for (let c = 0; c < values[r].length; c++) {
        this.sheet.data[rowIndex][this.startCol - 1 + c] = values[r][c];
      }
    }
    return this;
  }

  setValue(value) {
    return this.setValues([[value]]);
  }

  setBackground() { return this; }
  setFontColor() { return this; }
  setFontWeight() { return this; }
}

class MockSheet {
  constructor(name) {
    this.name = name;
    this.data = [];
  }

  getName() { return this.name; }

  getDataRange() {
    const maxCols = this.data.length === 0 ? 0 : Math.max(...this.data.map(row => row.length));
    return new MockRange(this, 1, 1, this.data.length, maxCols);
  }

  getRange(row, col, numRows, numCols) {
    return new MockRange(this, row, col, numRows, numCols);
  }

  appendRow(row) { this.data.push([...row]); }
}

class MockSpreadsheet {
  constructor() {
    this.sheets = [];
  }

  getSheetByName(name) {
    return this.sheets.find(sheet => sheet.name === name) || null;
  }

  insertSheet(name) {
    const sheet = new MockSheet(name);
    this.sheets.push(sheet);
    return sheet;
  }

  getSheets() { return this.sheets; }
}

function createEnvironment() {
  const spreadsheet = new MockSpreadsheet();
  const lock = { tryLock: () => true, releaseLock: () => {} };
  const sandbox = {
    SpreadsheetApp: { getActiveSpreadsheet: () => spreadsheet },
    LockService: { getScriptLock: () => lock },
    ContentService: {
      MimeType: { JSON: 'application/json' },
      createTextOutput: text => ({
        setMimeType: () => ({ getContent: () => text })
      })
    },
    console
  };
  vm.createContext(sandbox);
  const code = fs.readFileSync(path.join(__dirname, '../google-apps-script/Code.gs'), 'utf8');
  vm.runInContext(code, sandbox);
  return { sandbox, spreadsheet };
}

function post(sandbox, payload) {
  const output = sandbox.doPost({ postData: { contents: JSON.stringify(payload) } });
  return JSON.parse(output.getContent());
}

function makeStudent(member, name, email) {
  return {
    member,
    code: `CODE-${member}`,
    surname: name,
    middleName: '',
    givenName: '',
    totalSlots: 20,
    email
  };
}

function runTests() {
  const { sandbox, spreadsheet } = createEnvironment();
  const sheet = spreadsheet.insertSheet('SE1801');
  const slotHeaders = Array.from({ length: 20 }, (_, index) => `B${index + 1}`);
  sheet.data = [
    ['Môn học:', 'PRM393', 'Trạng thái buổi:', 'Đã điểm danh'],
    ['Lịch & Slot:', 'T2-T5 | Slot 1', 'Ngày học tiếp theo:', '24/09/2026'],
    ['Phòng học:', 'BE-302'],
    ['Ngày bắt đầu:', '01/09/2026', 'Tổng số buổi:', 20],
    ['MEMBER', 'CODE', 'SURNAME', 'MIDDLE NAME', 'GIVEN NAME', 'TOTAL SLOTS', 'ABSENT', 'EMAIL', ...slotHeaders],
    ['SE170001', 'OLD-CODE-1', 'Nguyễn', 'Văn', 'An', 20, 2, 'old-an@fpt.edu.vn', 'P', 'A', ...Array(18).fill('')],
    ['SE170002', 'OLD-CODE-2', 'Trần', 'Thị', 'Bình', 20, 1, 'binh@fpt.edu.vn', 'A', ...Array(19).fill('')]
  ];
  const originalMetadata = JSON.stringify(sheet.data.slice(0, 4));
  const originalHeader = JSON.stringify(sheet.data[4]);

  const first = post(sandbox, {
    action: 'syncStudents',
    className: 'SE1801',
    students: [
      makeStudent('SE170001', 'Nguyễn Updated', 'updated-an@fpt.edu.vn'),
      makeStudent('SE170003', 'Lê', 'le@fpt.edu.vn')
    ]
  });

  assert.strictEqual(first.status, 'success');
  assert.strictEqual(first.updated, 1);
  assert.strictEqual(first.inserted, 1);
  assert.strictEqual(first.retained, 1);
  assert.strictEqual(JSON.stringify(sheet.data.slice(0, 4)), originalMetadata, 'Metadata must remain unchanged');
  assert.strictEqual(JSON.stringify(sheet.data[4]), originalHeader, 'Header and B1..B20 columns must remain unchanged');

  const an = sheet.data.find(row => row[0] === 'SE170001');
  const binh = sheet.data.find(row => row[0] === 'SE170002');
  const le = sheet.data.find(row => row[0] === 'SE170003');
  assert.ok(an && binh && le, 'Existing and new roster rows must all exist');
  assert.strictEqual(an[2], 'Nguyễn Updated');
  assert.strictEqual(an[6], 2, 'Existing ABSENT must be preserved');
  assert.strictEqual(an[8], 'P', 'Existing B1 must be preserved');
  assert.strictEqual(an[9], 'A', 'Existing B2 must be preserved');
  assert.strictEqual(binh[6], 1, 'Retained student ABSENT must be preserved');
  assert.strictEqual(binh[8], 'A', 'Retained student B1 must be preserved');
  assert.strictEqual(le[6], 0, 'New student ABSENT must start at zero');
  assert.strictEqual(le[8], '', 'New student B1 must start empty');

  const second = post(sandbox, {
    action: 'syncStudents',
    className: 'SE1801',
    students: [
      makeStudent('SE170001', 'Nguyễn Updated', 'updated-an@fpt.edu.vn'),
      makeStudent('SE170003', 'Lê', 'le@fpt.edu.vn')
    ]
  });
  assert.strictEqual(second.status, 'success');
  assert.strictEqual(second.inserted, 0, 'Sync must be idempotent');
  assert.strictEqual(sheet.data.filter(row => row[0] === 'SE170003').length, 1, 'Sync must not duplicate rows');

  const partial = post(sandbox, {
    action: 'syncStudents',
    className: 'SE1801',
    students: [{ member: 'SE170001', surname: 'Nguyễn Partial' }]
  });
  assert.strictEqual(partial.status, 'success');
  const partiallyUpdated = sheet.data.find(row => row[0] === 'SE170001');
  assert.strictEqual(partiallyUpdated[2], 'Nguyễn Partial');
  assert.strictEqual(partiallyUpdated[1], 'CODE-SE170001', 'Missing CODE must preserve the existing value');
  assert.strictEqual(partiallyUpdated[7], 'updated-an@fpt.edu.vn', 'Missing EMAIL must preserve the existing value');

  const beforeRejectedSync = JSON.stringify(sheet.data);
  const empty = post(sandbox, { action: 'syncStudents', className: 'SE1801', students: [] });
  assert.strictEqual(empty.status, 'error');
  assert.strictEqual(JSON.stringify(sheet.data), beforeRejectedSync, 'Empty payload must not mutate sheet');

  const duplicate = post(sandbox, {
    action: 'syncStudents',
    className: 'SE1801',
    students: [makeStudent('SE170004', 'Duplicate', 'a@fpt.edu.vn'), makeStudent('SE170004', 'Duplicate', 'b@fpt.edu.vn')]
  });
  assert.strictEqual(duplicate.status, 'error');
  assert.strictEqual(JSON.stringify(sheet.data), beforeRejectedSync, 'Duplicate payload must not mutate sheet');

  console.log('✓ syncStudents upsert preserves metadata, ABSENT, B1..B20, old rows, and rejects unsafe payloads');
}

runTests();
