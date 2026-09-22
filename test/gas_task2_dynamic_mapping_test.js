/**
 * Test suite verifying Task 2: Google Apps Script Dynamic Header Mapping,
 * Rows 1-4 Metadata Extraction, and 20 Slots Matrix Tracking.
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
    const maxCols = this.data.length > 0 ? Math.max(...this.data.map(r => r ? r.length : 0)) : 0;
    return new MockRange(this, 1, 1, this.data.length, maxCols);
  }
  getRange(r, c, nr, nc) { return new MockRange(this, r, c, nr || 1, nc || 1); }
  appendRow(row) { this.data.push([...row]); }
  getLastRow() { return this.data.length; }
  clearContents() { this.data = []; }
  clear() { this.data = []; }
}

class MockSpreadsheet {
  constructor() {
    this.sheets = [];
  }

  getSheets() { return this.sheets; }
  getSheetByName(name) {
    return this.sheets.find(s => s.name.toLowerCase() === name.toLowerCase()) || null;
  }
  insertSheet(name) {
    const s = new MockSheet(name);
    this.sheets.push(s);
    return s;
  }
}

function createGasContext(mockSs) {
  const codeContent = fs.readFileSync(path.join(__dirname, '../google-apps-script/Code.gs'), 'utf8');
  const sandbox = {
    SpreadsheetApp: { getActiveSpreadsheet: () => mockSs },
    ContentService: {
      MimeType: { JSON: 'application/json' },
      createTextOutput: (str) => ({
        setMimeType: () => str,
        getContent: () => str
      })
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
        setXFrameOptionsMode: function() { return html; }
      }),
      XFrameOptionsMode: { ALLOWALL: 'ALLOWALL' }
    },
    console: console
  };

  const context = vm.createContext(sandbox);
  vm.runInContext(codeContent, context);
  return sandbox;
}

function runTests() {
  console.log('--- BẮT ĐẦU KIỂM THỬ TASK 2 (DYNAMIC HEADER MAPPING & 20 SLOTS) ---');

  // Test Case 1: Đọc sheet chuẩn FPT (Rows 1-4 Metadata, Row 5 Header)
  {
    const ss = new MockSpreadsheet();
    const sheet = ss.insertSheet('SE1801_PRM393');
    sheet.data = [
      ['Môn học:', 'PRM393 - Lập trình Di động', 'Buổi hiện tại:', '6 / 20'],
      ['Lịch & Slot:', 'T2-T5 | Slot 1 (07:00 - 09:15)', 'Ngày học tiếp theo:', '24/09/2026'],
      ['Phòng học:', 'NVH-611', 'Trạng thái buổi:', 'Chưa điểm danh'],
      ['Ngày bắt đầu:', '07/09/2026', 'Tổng số buổi:', 20],
      ['STT', 'MSSV', 'HỌ', 'TÊN ĐỆM', 'TÊN', 'EMAIL', 'TỔNG BUỔI', 'VẮNG', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'B10', 'B11', 'B12', 'B13', 'B14', 'B15', 'B16', 'B17', 'B18', 'B19', 'B20'],
      [1, 'CE190585', 'Lâm', 'Quốc', 'Minh', 'minhlqce190585@fpt.edu.vn', 20, 0, 'P', 'P', 'P', 'P', 'P', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
      [2, 'SE170125', 'Nguyễn', 'Văn', 'An', 'anvse170125@fpt.edu.vn', 20, 1, 'P', 'A', 'P', 'P', 'P', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
    ];

    const gas = createGasContext(ss);
    const resRaw = gas.doGet({ parameter: { action: 'getStudents', className: 'SE1801_PRM393' } });
    const res = JSON.parse(resRaw);

    assert.strictEqual(res.status, 'success', 'Status must be success');
    assert.strictEqual(res.subject, 'PRM393 - Lập trình Di động', 'Must extract subject metadata');
    assert.strictEqual(res.room, 'NVH-611', 'Must extract room NVH-611');
    assert.strictEqual(res.slot, 1, 'Must extract slot 1');
    assert.strictEqual(res.nextDate, '24/09/2026', 'Must extract nextDate 24/09/2026');
    assert.strictEqual(res.currentSession, 6, 'Must extract currentSession 6');

    // KIỂM TRA QUAN TRỌNG: MSSV vs HỌ TÊN KHÔNG ĐƯỢC NHẦM LẪN
    assert.strictEqual(res.data[0].member, 'CE190585', 'MSSV phải là CE190585, KHÔNG ĐƯỢC là Lâm!');
    assert.strictEqual(res.data[0].rollNumber, 'CE190585', 'rollNumber phải là CE190585');
    assert.strictEqual(res.data[0].surname, 'Lâm', 'Họ phải là Lâm');
    assert.strictEqual(res.data[0].fullName, 'Lâm Quốc Minh', 'Họ tên đầy đủ phải là Lâm Quốc Minh');
    assert.strictEqual(res.data[0].slots20.length, 20, 'slots20 phải có đúng 20 phần tử');
    assert.strictEqual(res.data[0].slots20[0], 'P', 'Buổi 1 là P');
    assert.strictEqual(res.data[0].slots20[4], 'P', 'Buổi 5 là P');
    assert.strictEqual(res.data[0].slots20[5], '', 'Buổi 6 chưa điểm danh là rỗng');
    assert.strictEqual(res.data[1].slots20[1], 'A', 'Sinh viên 2 buổi 2 là A (Vắng)');

    console.log('✓ Test 1: Đọc chính xác Metadata và Dynamic Header Mapping: PASS');
  }

  // Test Case 2: Tìm sheet theo prefix className (SE1801 -> SE1801_PRM393)
  {
    const ss = new MockSpreadsheet();
    const sheet = ss.insertSheet('SE1801_PRM393');
    sheet.data = [
      ['Môn học:', 'PRM393', '', ''],
      ['Lịch & Slot:', 'T2-T5 | Slot 1', '', ''],
      ['Phòng học:', 'NVH-611', '', ''],
      ['Ngày bắt đầu:', '07/09/2026', '', ''],
      ['STT', 'MSSV', 'HỌ', 'TÊN ĐỆM', 'TÊN', 'EMAIL', 'TỔNG BUỔI', 'VẮNG'],
      [1, 'CE190585', 'Lâm', 'Quốc', 'Minh', 'minhlqce190585@fpt.edu.vn', 20, 0]
    ];

    const gas = createGasContext(ss);
    const resRaw = gas.doGet({ parameter: { action: 'getStudents', className: 'SE1801' } });
    const res = JSON.parse(resRaw);

    assert.strictEqual(res.status, 'success');
    assert.strictEqual(res.className, 'SE1801_PRM393');
    assert.strictEqual(res.data[0].member, 'CE190585');
    console.log('✓ Test 2: Tự động ghép nối lớp theo prefix SE1801 -> SE1801_PRM393: PASS');
  }

  // Test Case 3: getTodayClasses đọc trực tiếp từ Metadata của các tab lớp
  {
    const ss = new MockSpreadsheet();
    const sheet = ss.insertSheet('IA1601_CSN101');
    sheet.data = [
      ['Môn học:', 'CSN101 - An toàn thông tin', 'Buổi hiện tại:', '5 / 20'],
      ['Lịch & Slot:', 'T3-T6 | Slot 2 (09:30 - 11:45)', 'Ngày học tiếp theo:', '22/09/2026'],
      ['Phòng học:', 'NVH-603', 'Trạng thái buổi:', 'Chưa điểm danh'],
      ['Ngày bắt đầu:', '07/09/2026', 'Tổng số buổi:', 20],
      ['STT', 'MSSV', 'HỌ', 'TÊN ĐỆM', 'TÊN', 'EMAIL', 'TỔNG BUỔI', 'VẮNG'],
      [1, 'IA160001', 'Bùi', 'Thành', 'Đạt', 'datbtia160001@fpt.edu.vn', 20, 0]
    ];

    const gas = createGasContext(ss);
    // Ngày 22/09/2026 là Thứ Ba
    const resRaw = gas.doGet({ parameter: { action: 'getTodayClasses', date: '2026-09-22' } });
    const res = JSON.parse(resRaw);

    assert.strictEqual(res.success, true);
    assert.strictEqual(res.total, 1, 'Hôm nay Thứ 3 phải tìm thấy lớp IA1601_CSN101 (T3-T6)');
    assert.strictEqual(res.data[0].className, 'IA1601_CSN101');
    assert.strictEqual(res.data[0].room, 'NVH-603');
    assert.strictEqual(res.data[0].slot, 2);
    console.log('✓ Test 3: getTodayClasses đọc trực tiếp Metadata Dòng 1-4 của tab lớp: PASS');
  }

  // Test Case 4: saveAttendance ghi trực tiếp vào cột B{slot/session} trên sheet
  {
    const ss = new MockSpreadsheet();
    const sheet = ss.insertSheet('SE1801_PRM393');
    sheet.data = [
      ['Môn học:', 'PRM393', 'Buổi hiện tại:', '1 / 20'],
      ['Lịch & Slot:', 'T2-T5 | Slot 1', 'Ngày học tiếp theo:', '22/09/2026'],
      ['Phòng học:', 'NVH-611', 'Trạng thái buổi:', 'Chưa điểm danh'],
      ['Ngày bắt đầu:', '07/09/2026', 'Tổng số buổi:', 20],
      ['STT', 'MSSV', 'HỌ', 'TÊN ĐỆM', 'TÊN', 'EMAIL', 'TỔNG BUỔI', 'VẮNG', 'B1', 'B2', 'B3'],
      [1, 'CE190585', 'Lâm', 'Quốc', 'Minh', 'minhlqce190585@fpt.edu.vn', 20, 0, '', '', ''],
      [2, 'SE170125', 'Nguyễn', 'Văn', 'An', 'anvse170125@fpt.edu.vn', 20, 0, '', '', '']
    ];

    const gas = createGasContext(ss);
    const postBody = {
      action: 'saveAttendance',
      className: 'SE1801_PRM393',
      date: '2026-09-22',
      slot: 1,
      sessionNumber: 1,
      records: [
        { rollNumber: 'CE190585', status: 'present', note: '' },
        { rollNumber: 'SE170125', status: 'absent', note: 'Nghỉ không phép' }
      ]
    };

    const resPostRaw = gas.doPost({ postData: { contents: JSON.stringify(postBody) } });
    const resPost = JSON.parse(resPostRaw);
    assert.strictEqual(resPost.status, 'success');

    // Kiểm tra ô B1 trong sheet: CE190585 = 'P', SE170125 = 'A'
    assert.strictEqual(sheet.data[5][8], 'P', 'Cột B1 của CE190585 phải là P');
    assert.strictEqual(sheet.data[6][8], 'A', 'Cột B1 của SE170125 phải là A');
    assert.strictEqual(sheet.data[6][7], 1, 'Cột VẮNG của SE170125 phải tăng lên 1');

    console.log('✓ Test 4: saveAttendance ghi ma trận 20 slot và cập nhật cột VẮNG thành công: PASS');
  }

  console.log('\n>>> TẤT CẢ 4/4 KIỂM THỬ TASK 2 ĐÃ VƯỢT QUA 100%! <<<\n');
}

runTests();
