const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

class MockRange {
  constructor(sheet, row, col, rows, cols) {
    this.sheet = sheet;
    this.row = row;
    this.col = col;
    this.rows = rows || 1;
    this.cols = cols || 1;
  }

  getValues() {
    return Array.from({ length: this.rows }, (_, r) =>
      Array.from({ length: this.cols }, (_, c) => {
        const source = this.sheet.data[this.row - 1 + r] || [];
        return source[this.col - 1 + c] === undefined ? '' : source[this.col - 1 + c];
      })
    );
  }

  setValue(value) { return this.setValues([[value]]); }

  setValues(values) {
    values.forEach((valuesRow, r) => {
      const rowIndex = this.row - 1 + r;
      if (!this.sheet.data[rowIndex]) this.sheet.data[rowIndex] = [];
      valuesRow.forEach((value, c) => {
        this.sheet.data[rowIndex][this.col - 1 + c] = value;
      });
    });
    return this;
  }

  setBackground() { return this; }
  setFontColor() { return this; }
  setFontWeight() { return this; }
}

class MockSheet {
  constructor(name) { this.name = name; this.data = []; }
  getName() { return this.name; }
  isSheetHidden() { return false; }
  getDataRange() {
    const cols = this.data.length ? Math.max(...this.data.map(row => row.length)) : 0;
    return new MockRange(this, 1, 1, this.data.length, cols);
  }
  getRange(row, col, rows, cols) { return new MockRange(this, row, col, rows, cols); }
  appendRow(row) { this.data.push([...row]); }
  getLastRow() { return this.data.length; }
  clearContents() { this.data = []; }
}

class MockSpreadsheet {
  constructor() { this.sheets = []; }
  getSheets() { return this.sheets; }
  getSheetByName(name) { return this.sheets.find(sheet => sheet.name.toLowerCase() === name.toLowerCase()) || null; }
  insertSheet(name) { const sheet = new MockSheet(name); this.sheets.push(sheet); return sheet; }
}

function createGasContext(spreadsheet) {
  const source = fs.readFileSync(path.join(__dirname, '../google-apps-script/Code.gs'), 'utf8');
  const sandbox = {
    SpreadsheetApp: { getActiveSpreadsheet: () => spreadsheet },
    ContentService: {
      MimeType: { JSON: 'application/json' },
      createTextOutput: value => ({ setMimeType: () => value, getContent: () => value })
    },
    LockService: {
      getScriptLock: () => ({ tryLock: () => true, releaseLock: () => {} })
    },
    console
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  return sandbox;
}

function createFixture({ matrix = ['', ''], logs = [] } = {}) {
  const spreadsheet = new MockSpreadsheet();
  const sheet = spreadsheet.insertSheet('SE1919-SWP392');
  sheet.data = [
    ['Môn học:', 'SWP392', 'Buổi hiện tại:', '5 / 20'],
    ['Lịch & Slot:', 'T2-T5 | Slot 1 (07:00 - 09:15)', 'Ngày học tiếp theo:', '21/09/2026'],
    ['Phòng học:', 'NVH-603', 'Trạng thái buổi:', 'Đã điểm danh'],
    ['Ngày bắt đầu:', '07/09/2026', 'Tổng số buổi:', 20],
    ['STT', 'MEMBER', 'HỌ', 'TÊN', 'EMAIL', 'VẮNG', 'B1', 'B2', 'B3', 'B4', 'B5'],
    [1, 'SE170001', 'Nguyễn', 'An', 'an@fpt.edu.vn', 0, '', '', '', '', matrix[0]],
    [2, 'SE170002', 'Trần', 'Bình', 'binh@fpt.edu.vn', 0, '', '', '', '', matrix[1]]
  ];
  if (logs.length) {
    const logSheet = spreadsheet.insertSheet('Attendance_Logs');
    logSheet.data = [
      ['Thời gian', 'Lớp', 'Ngày học', 'Slot', 'MEMBER', 'Trạng thái', 'Ghi chú', 'SESSION_NO'],
      ...logs
    ];
  }
  return { spreadsheet, sheet };
}

function callJson(gas, action) {
  return JSON.parse(gas.doGet({ parameter: { action, date: '2026-09-21' } }));
}

function callAttendance(gas, className, date, slot) {
  return JSON.parse(gas.doGet({
    parameter: {
      action: 'getAttendance',
      className,
      date,
      slot: String(slot)
    }
  }));
}

function callAnalytics(gas, className) {
  return JSON.parse(gas.doGet({ parameter: {
    action: 'getAnalyticsData',
    className,
    date: '2026-09-21'
  }}));
}

function assertConsistent(spreadsheet, expected) {
  const gas = createGasContext(spreadsheet);
  const today = callJson(gas, 'getTodayClasses');
  const overview = callJson(gas, 'getAttendanceOverview');
  assert.strictEqual(today.data[0].isAttendanceDone, expected);
  assert.strictEqual(overview.todayClasses[0].isAttendanceDone, expected);
  assert.strictEqual(overview.todayClasses[0].sessionStatus, expected ? 'Đã điểm danh' : 'Chưa điểm danh');
}

console.log('=== ATTENDANCE STATE CONSISTENCY REGRESSION TESTS ===');

{
  const { spreadsheet, sheet } = createFixture({ matrix: ['P', ''] });
  const before = JSON.stringify(sheet.data);
  assertConsistent(spreadsheet, false);
  assert.strictEqual(JSON.stringify(sheet.data), before, 'GET không được sửa metadata hoặc ma trận');
  console.log('✓ Partial matrix + stale metadata không được báo đã điểm danh');
}

{
  const { spreadsheet } = createFixture({ matrix: ['P', 'A'] });
  assertConsistent(spreadsheet, true);
  const generatedLogs = spreadsheet.getSheetByName('Attendance_Logs');
  assert.ok(generatedLogs, 'Matrix đầy đủ phải tự tạo Attendance_Logs');
  assert.strictEqual(generatedLogs.data.length, 3, 'Phải tạo đủ log cho toàn bộ roster');
  assert.strictEqual(generatedLogs.data[1][7], 5);
  console.log('✓ Matrix đầy đủ đúng session được chấp nhận');
}

{
  const { spreadsheet } = createFixture({
    matrix: ['', ''],
    logs: [
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', '2026-09-21', 1, 'SE170001', 'present', '', 5],
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', '2026-09-21', 1, 'SE170002', 'absent', '', 5]
    ]
  });
  assertConsistent(spreadsheet, true);
  console.log('✓ Log đầy đủ đúng class/date/slot/session được chấp nhận');
}

{
  const { spreadsheet } = createFixture({
    matrix: ['', ''],
    logs: [
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', '2026-09-21', 1, 'SE170001', 'present', '', 4],
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', '2026-09-21', 1, 'SE170002', 'absent', '', 4]
    ]
  });
  assertConsistent(spreadsheet, false);
  console.log('✓ Log sai session không được chấp nhận');
}

{
  const { spreadsheet } = createFixture({
    matrix: ['P', 'A'],
    logs: [
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', new Date(2026, 8, 21), 1, 'SE170001', 'present', '', 5],
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', new Date(2026, 8, 21), 1, 'SE170002', 'absent', '', 5],
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', new Date(2026, 8, 21), 1, 'SE170001', 'present', '', 4]
    ]
  });
  const gas = createGasContext(spreadsheet);
  const response = callAttendance(gas, 'SE1919-SWP392', '2026-09-21', 1);
  assert.strictEqual(response.status, 'success');
  assert.strictEqual(response.data.length, 2, 'Date dạng Date phải được normalize và trả đủ log đúng session');
  assert.ok(response.data.every(record => record.date === '2026-09-21'));
  assert.ok(response.data.every(record => record.status === 'present' || record.status === 'absent'));
  console.log('✓ getAttendance normalize Date và lọc đúng session');
}

{
  const { spreadsheet } = createFixture({ matrix: ['P', 'A'] });
  const gas = createGasContext(spreadsheet);
  const response = callAttendance(gas, 'SE1919-SWP392', '2026-09-21', 1);
  assert.strictEqual(response.status, 'success');
  assert.strictEqual(response.data.length, 2, 'getAttendance phải đọc được log vừa materialize từ matrix');
  assert.ok(response.data.every(record => record.date === '2026-09-21'));
  console.log('✓ getAttendance trả log ngay sau khi materialize');
}

{
  const { spreadsheet } = createFixture({
    matrix: ['P', 'A'],
    logs: [
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', new Date(2026, 8, 21), 1, 'SE170001', 'present', '', 5],
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', new Date(2026, 8, 21), 1, 'SE170002', 'absent', '', 5],
      ['2026-09-17T08:00:00Z', 'SE1919-SWP392', new Date(2026, 8, 17), 1, 'SE170001', 'present', '', 4],
      ['2026-09-17T08:00:00Z', 'SE1919-SWP392', new Date(2026, 8, 17), 1, 'SE170002', 'absent', '', 4]
    ]
  });
  const gas = createGasContext(spreadsheet);
  const overview = callJson(gas, 'getAttendanceOverview');
  const item = overview.todayClasses[0];
  assert.strictEqual(item.lastSession, 5);
  assert.strictEqual(item.lastDate, '2026-09-21');
  assert.strictEqual(item.lastStatus, 'Đã điểm danh');
  console.log('✓ Overview ghép lastSession và lastDate từ cùng session');
}

{
  const { spreadsheet } = createFixture({
    matrix: ['', ''],
    logs: [
      ['2026-09-21T08:00:00Z', 'SE1919-SWP392', new Date(2026, 8, 21), 1, 'SE170001', 'present', '', 5]
    ]
  });
  const gas = createGasContext(spreadsheet);
  const analytics = callAnalytics(gas, 'SE1919-SWP392');
  assert.strictEqual(analytics.logs[0].date, '2026-09-21');
  assert.strictEqual(analytics.logs[0].sessionNumber, 5);
  console.log('✓ Analytics normalize ngày Date và trả sessionNumber ổn định');
}

{
  const { spreadsheet } = createFixture({
    matrix: ['', ''],
    logs: [
      ['2026-09-17T08:00:00Z', 'SE1919-SWP392', '2026-09-17', 1, 'SE170001', 'present', '']
    ]
  });
  const gas = createGasContext(spreadsheet);
  const response = JSON.parse(gas.doPost({
    postData: {
      contents: JSON.stringify({
        action: 'saveAttendance',
        className: 'SE1919-SWP392',
        date: '2026-09-21',
        slot: 1,
        sessionNumber: 5,
        records: [
          { rollNumber: 'SE170001', status: 'present' },
          { rollNumber: 'SE170002', status: 'absent' }
        ]
      })
    }
  }));
  assert.strictEqual(response.status, 'success');
  const logs = spreadsheet.getSheetByName('Attendance_Logs').data;
  assert.strictEqual(logs[0][7], 'SESSION_NO');
  assert.strictEqual(logs[logs.length - 1][7], 5);
  console.log('✓ SaveAttendance ghi SESSION_NO và giữ tương thích log 7 cột cũ');
}

console.log('=== ALL ATTENDANCE STATE CONSISTENCY TESTS PASSED ===');
