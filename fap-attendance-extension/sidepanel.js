// === FAP ATTENDANCE ASSISTANT - CONTROLLER JS ===

let currentStudents = [];
let currentRecords = {}; // rollNumber -> { status, note }
let currentFilter = 'all';
let sheetUrl = '';

// Sample FPT students fallback
const sampleStudents = [
  { rollNumber: 'SE170123', fullName: 'Nguyễn Văn An', email: 'annvse170123@fpt.edu.vn' },
  { rollNumber: 'SE170456', fullName: 'Trần Thị Bình', email: 'binhttse170456@fpt.edu.vn' },
  { rollNumber: 'SE170789', fullName: 'Lê Hoàng Cường', email: 'cuonglhse170789@fpt.edu.vn' },
  { rollNumber: 'SE171012', fullName: 'Phạm Minh Đức', email: 'ducpmse171012@fpt.edu.vn' },
  { rollNumber: 'SE171345', fullName: 'Vũ Hải Đăng', email: 'dangvhse171345@fpt.edu.vn' },
  { rollNumber: 'HE160234', fullName: 'Đỗ Thùy Linh', email: 'linhdthe160234@fpt.edu.vn' },
  { rollNumber: 'HE160567', fullName: 'Ngô Quốc Nam', email: 'namnqhe160567@fpt.edu.vn' },
  { rollNumber: 'IA160890', fullName: 'Hoàng Mai Phương', email: 'phuonghmia160890@fpt.edu.vn' }
];

document.addEventListener('DOMContentLoaded', async () => {
  setupTabs();
  await loadSettings();
  setupEventListeners();
  renderStudentList();
  renderManageStudentsList();
});

// Setup tab navigation
function setupTabs() {
  const tabBtns = document.querySelectorAll('.nav-pill');
  const tabPanes = document.querySelectorAll('.tab-view');

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      tabBtns.forEach(b => b.classList.remove('active'));
      tabPanes.forEach(p => p.classList.remove('active'));

      btn.classList.add('active');
      const target = document.getElementById(btn.dataset.tab);
      if (target) target.classList.add('active');
    });
  });
}

// Load settings from storage
async function loadSettings() {
  try {
    const result = await chrome.storage.local.get(['sheetUrl', 'cachedStudents']);
    sheetUrl = result.sheetUrl || '';
    document.getElementById('inputSheetUrl').value = sheetUrl;

    if (result.cachedStudents && result.cachedStudents.length > 0) {
      currentStudents = result.cachedStudents;
    } else {
      currentStudents = sampleStudents;
    }

    currentStudents.forEach(s => {
      if (!currentRecords[s.rollNumber]) {
        currentRecords[s.rollNumber] = { status: 'present', note: '' };
      }
    });

    if (sheetUrl) {
      testSheetConnection(sheetUrl, false);
    }
  } catch (_) {
    currentStudents = sampleStudents;
  }
}

// Setup Event Listeners
function setupEventListeners() {
  // Search
  document.getElementById('inputSearch').addEventListener('input', () => {
    renderStudentList();
  });

  // Filter Chips (All, Present, Absent)
  const chips = document.querySelectorAll('.chip');
  chips.forEach(chip => {
    chip.addEventListener('click', () => {
      chips.forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      currentFilter = chip.dataset.filter;
      renderStudentList();
    });
  });

  // Batch actions
  document.getElementById('btnAllPresent').addEventListener('click', () => {
    currentStudents.forEach(s => {
      currentRecords[s.rollNumber] = { status: 'present', note: currentRecords[s.rollNumber]?.note || '' };
    });
    renderStudentList();
    showToast('✓ Đã đánh dấu tất cả có mặt');
  });

  document.getElementById('btnAllAbsent').addEventListener('click', () => {
    currentStudents.forEach(s => {
      currentRecords[s.rollNumber] = { status: 'absent', note: currentRecords[s.rollNumber]?.note || '' };
    });
    renderStudentList();
    showToast('✕ Đã đánh dấu tất cả vắng');
  });

  // Scrape from FAP tab
  document.getElementById('btnScrapeFap').addEventListener('click', async () => {
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (!tab) return alert('Không tìm thấy tab trình duyệt!');

      chrome.tabs.sendMessage(tab.id, { action: 'scrapeStudents' }, (response) => {
        if (chrome.runtime.lastError || !response || !response.success) {
          return alert('Không tìm thấy bảng điểm danh trên trang này!\nHãy mở trang điểm danh FAP hoặc trang test-mock-fap.html.');
        }

        currentStudents = response.students;
        currentStudents.forEach(s => {
          currentRecords[s.rollNumber] = { status: s.status || 'present', note: '' };
        });
        chrome.storage.local.set({ cachedStudents: currentStudents });
        renderStudentList();
        renderManageStudentsList();
        showToast(`📥 Đã quét thành công ${response.count} sinh viên từ FAP!`);
      });
    } catch (err) {
      alert('Lỗi: ' + err.message);
    }
  });

  // Apply to FAP tab
  document.getElementById('btnApplyFap').addEventListener('click', async () => {
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (!tab) return alert('Không tìm thấy tab trình duyệt!');

      const recordsArray = currentStudents.map(s => ({
        rollNumber: s.rollNumber,
        status: currentRecords[s.rollNumber]?.status || 'present',
        note: currentRecords[s.rollNumber]?.note || ''
      }));

      chrome.tabs.sendMessage(tab.id, { action: 'applyAttendance', records: recordsArray }, (res) => {
        if (chrome.runtime.lastError || !res || !res.success) {
          return alert('Chưa tìm thấy trang FAP!\nĐảm bảo tab hiện tại đang mở fap.fpt.edu.vn hoặc test-mock-fap.html.');
        }
        showToast(`⚡ Đã tự động điền ${res.filled} SV lên FAP!`);
      });
    } catch (err) {
      alert('Lỗi: ' + err.message);
    }
  });

  // Test Google Sheet connection
  document.getElementById('btnTestSheet').addEventListener('click', async () => {
    const url = document.getElementById('inputSheetUrl').value.trim();
    if (!url) return alert('Vui lòng nhập URL Google Apps Script!');
    await testSheetConnection(url, true);
  });

  // Open Google Sheet in new tab
  document.getElementById('btnOpenSheet').addEventListener('click', () => {
    if (sheetUrl) {
      chrome.tabs.create({ url: sheetUrl });
    } else {
      chrome.tabs.create({ url: 'https://sheet.new' });
    }
  });

  // Save to Google Sheet
  document.getElementById('btnSaveSheet').addEventListener('click', async () => {
    if (!sheetUrl) return alert('Vui lòng cài đặt URL Google Sheet trong mục Cài đặt trước!');

    const cls = document.getElementById('selectClass').value;
    const slot = document.getElementById('selectSlot').value;
    const today = new Date().toISOString().split('T')[0];

    const recordsArray = currentStudents.map(s => ({
      rollNumber: s.rollNumber,
      status: currentRecords[s.rollNumber]?.status || 'present',
      note: currentRecords[s.rollNumber]?.note || ''
    }));

    try {
      await fetch(sheetUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'saveAttendance',
          className: cls,
          slot: slot,
          date: today,
          records: recordsArray
        })
      });

      showToast('💾 Đã lưu thành công vào Google Sheet DB!');
    } catch (e) {
      alert('Lỗi lưu Google Sheet: ' + e.message);
    }
  });

  // Sync students to Google Sheet
  document.getElementById('btnSyncStudents').addEventListener('click', async () => {
    if (!sheetUrl) return alert('Vui lòng cài đặt URL Google Sheet trước!');
    const cls = document.getElementById('selectClass').value;

    try {
      await fetch(sheetUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'syncStudents',
          className: cls,
          students: currentStudents
        })
      });
      showToast(`👥 Đã đồng bộ ${currentStudents.length} SV vào Google Sheet!`);
    } catch (e) {
      alert('Lỗi: ' + e.message);
    }
  });

  // Copy Apps Script code
  document.getElementById('btnCopyAppsScript').addEventListener('click', () => {
    const code = `function doGet(e){var action=(e&&e.parameter&&e.parameter.action)?e.parameter.action:'test';var ss=SpreadsheetApp.getActiveSpreadsheet();if(action==='test'){return ContentService.createTextOutput(JSON.stringify({status:'success',message:'Kết nối thành công!'})).setMimeType(ContentService.MimeType.JSON);}if(action==='getStudents'){var cName=e.parameter.className||'SE1801';var sheet=ss.getSheetByName(cName)||ss.getActiveSheet();var data=sheet.getDataRange().getValues();var students=[];for(var i=1;i<data.length;i++){if(data[i][0]){students.push({rollNumber:data[i][0],fullName:data[i][1]||'',email:data[i][2]||''});}}return ContentService.createTextOutput(JSON.stringify({status:'success',data:students})).setMimeType(ContentService.MimeType.JSON);}}function doPost(e){try{var body=JSON.parse(e.postData.contents);var ss=SpreadsheetApp.getActiveSpreadsheet();if(body.action==='saveAttendance'){var logSheet=ss.getSheetByName('Attendance_Logs')||ss.insertSheet('Attendance_Logs');if(logSheet.getLastRow()===0){logSheet.appendRow(['Timestamp','Lớp','Ngày','Slot','Mã SV','Trạng thái','Ghi chú']);}var recs=body.records||[];var now=new Date();for(var j=0;j<recs.length;j++){logSheet.appendRow([now,body.className,body.date,body.slot,recs[j].rollNumber,recs[j].status,recs[j].note||'']);}return ContentService.createTextOutput(JSON.stringify({status:'success',message:'Đã lưu!'})).setMimeType(ContentService.MimeType.JSON);}}catch(err){return ContentService.createTextOutput(JSON.stringify({status:'error',message:err.toString()})).setMimeType(ContentService.MimeType.JSON);}}`;
    navigator.clipboard.writeText(code);
    showToast('📋 Đã sao chép mã Google Apps Script!');
  });
}

// Test connection
async function testSheetConnection(url, showAlert = false) {
  const statusBadge = document.getElementById('connectionStatus');
  const statusText = document.getElementById('statusText');
  const resultBox = document.getElementById('testResultBox');

  try {
    const res = await fetch(`${url}?action=test`);
    const data = await res.json();

    if (data.status === 'success') {
      sheetUrl = url;
      await chrome.storage.local.set({ sheetUrl: url });
      statusBadge.className = 'pulse-badge connected';
      statusText.innerText = 'Đã kết nối DB';
      resultBox.className = 'result-alert success';
      resultBox.innerText = '✅ Kết nối Google Sheet DB thành công!';
      resultBox.classList.remove('hidden');
      if (showAlert) showToast('✅ Kết nối Google Sheet thành công!');
    } else {
      throw new Error('Phản hồi không hợp lệ');
    }
  } catch (err) {
    statusBadge.className = 'pulse-badge disconnected';
    statusText.innerText = 'Chưa kết nối DB';
    resultBox.className = 'result-alert error';
    resultBox.innerText = '❌ Không thể kết nối. Hãy kiểm tra URL Web App và quyền Anyone!';
    resultBox.classList.remove('hidden');
    if (showAlert) alert('❌ Không thể kết nối Google Sheet: ' + err.message);
  }
}

// Render student list
function renderStudentList() {
  const container = document.getElementById('studentListContainer');
  const query = document.getElementById('inputSearch').value.trim().toLowerCase();
  container.innerHTML = '';

  let presentCount = 0;
  let absentCount = 0;

  currentStudents.forEach(student => {
    const record = currentRecords[student.rollNumber] || { status: 'present', note: '' };
    if (record.status === 'present') presentCount++;
    if (record.status === 'absent') absentCount++;
  });

  // Update counters
  document.getElementById('countAll').innerText = currentStudents.length;
  document.getElementById('countPresent').innerText = presentCount;
  document.getElementById('countAbsent').innerText = absentCount;

  // Update Progress Bar
  const total = currentStudents.length;
  const percentage = total > 0 ? Math.round((presentCount / total) * 100) : 100;
  document.getElementById('ratePercentage').innerText = `${percentage}%`;
  document.getElementById('rateProgressBar').style.width = `${percentage}%`;

  const filtered = currentStudents.filter(s => {
    const rec = currentRecords[s.rollNumber] || { status: 'present' };

    // Apply Chip Filter
    if (currentFilter === 'present' && rec.status !== 'present') return false;
    if (currentFilter === 'absent' && rec.status !== 'absent') return false;

    // Apply Search Query
    if (query) {
      return s.rollNumber.toLowerCase().includes(query) || s.fullName.toLowerCase().includes(query);
    }
    return true;
  });

  filtered.forEach(student => {
    const record = currentRecords[student.rollNumber] || { status: 'present', note: '' };
    const initials = student.rollNumber.substring(0, 2);

    const card = document.createElement('div');
    card.className = `student-card ${record.status === 'absent' ? 'absent' : ''} ${record.status === 'late' ? 'late' : ''}`;
    card.innerHTML = `
      <div class="card-top">
        <div class="student-avatar">${initials}</div>
        <div class="student-details">
          <div class="student-name">${student.fullName}</div>
          <div class="student-roll">${student.rollNumber}</div>
        </div>
      </div>
      <div class="segmented-pill">
        <button class="pill-opt ${record.status === 'present' ? 'active present' : ''}" data-status="present">
          ✓ Có mặt
        </button>
        <button class="pill-opt ${record.status === 'absent' ? 'active absent' : ''}" data-status="absent">
          ✕ Vắng
        </button>
        <button class="pill-opt ${record.status === 'late' ? 'active late' : ''}" data-status="late">
          ◷ Muộn
        </button>
      </div>
      <input type="text" class="card-note-input" placeholder="Ghi chú thêm..." value="${record.note || ''}">
    `;

    // Button event listeners
    const pills = card.querySelectorAll('.pill-opt');
    pills.forEach(pill => {
      pill.addEventListener('click', () => {
        currentRecords[student.rollNumber].status = pill.dataset.status;
        renderStudentList();
      });
    });

    // Note event listener
    const noteInput = card.querySelector('.card-note-input');
    noteInput.addEventListener('input', (e) => {
      currentRecords[student.rollNumber].note = e.target.value;
    });

    container.appendChild(card);
  });
}

// Render student management list in Tab 2
function renderManageStudentsList() {
  const container = document.getElementById('studentsManageList');
  if (!container) return;
  container.innerHTML = '';

  currentStudents.forEach((student, index) => {
    const card = document.createElement('div');
    card.className = 'student-card';
    card.innerHTML = `
      <div class="card-top">
        <div class="student-avatar">${student.rollNumber.substring(0, 2)}</div>
        <div class="student-details">
          <div class="student-name">${student.fullName}</div>
          <div class="student-roll">${student.rollNumber} • ${student.email || ''}</div>
        </div>
        <span style="font-size:12px; font-weight:800; color:#94A3B8;">#${index + 1}</span>
      </div>
    `;
    container.appendChild(card);
  });
}

// Show Smooth Toast Notification
function showToast(message) {
  const existing = document.getElementById('sidepanel-toast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.id = 'sidepanel-toast';
  toast.style.cssText = `
    position: fixed;
    bottom: 20px;
    left: 50%;
    transform: translateX(-50%);
    background: #0F172A;
    color: #FFFFFF;
    padding: 8px 16px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 700;
    box-shadow: 0 4px 14px rgba(0,0,0,0.3);
    border: 1px solid #F36F21;
    z-index: 9999;
    animation: toastIn 0.2s ease-out;
  `;
  toast.innerText = message;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 2500);
}
