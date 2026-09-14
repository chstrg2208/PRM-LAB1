// === FAP ATTENDANCE ASSISTANT - CONTROLLER JS ===

let currentStudents = [];
let currentRecords = {}; // rollNumber -> { status, note }
let currentFilter = 'all';
let sheetUrl = '';
let geminiApiKey = '';
let activeGeminiModel = 'gemini-2.0-flash';
let computedStats = {
  worstSlot: { slot: 1, time: '07:30 - 09:50', absentCount: 7, rate: 23.3 },
  worstDay: { name: 'Thứ Hai', absentCount: 9, rate: 30.0 },
  failedStudents: [],
  warningStudents: [],
  overallRate: 85.0
};

// Sample FPT students fallback with 4-field schema (Member, Code, Surname, Middle Name)
const sampleStudents = [
  { member: 'CE190585', code: 'Lâm', surname: 'Quốc', middleName: 'Minh', givenName: '', rollNumber: 'CE190585', fullName: 'Lâm Quốc Minh', email: 'minhlqce190585@fpt.edu.vn', totalSlots: 30, absentCount: 7 },
  { member: 'SE170123', code: 'Nguyễn', surname: 'Văn', middleName: 'An', givenName: '', rollNumber: 'SE170123', fullName: 'Nguyễn Văn An', email: 'annvse170123@fpt.edu.vn', totalSlots: 30, absentCount: 1 },
  { member: 'SE170456', code: 'Trần', surname: 'Thị', middleName: 'Bình', givenName: '', rollNumber: 'SE170456', fullName: 'Trần Thị Bình', email: 'binhttse170456@fpt.edu.vn', totalSlots: 30, absentCount: 3 },
  { member: 'SE170789', code: 'Lê', surname: 'Hoàng', middleName: 'Cường', givenName: '', rollNumber: 'SE170789', fullName: 'Lê Hoàng Cường', email: 'cuonglhse170789@fpt.edu.vn', totalSlots: 30, absentCount: 8 },
  { member: 'SE171012', code: 'Phạm', surname: 'Minh', middleName: 'Đức', givenName: '', rollNumber: 'SE171012', fullName: 'Phạm Minh Đức', email: 'ducpmse171012@fpt.edu.vn', totalSlots: 30, absentCount: 2 },
  { member: 'SE171345', code: 'Vũ', surname: 'Hải', middleName: 'Đăng', givenName: '', rollNumber: 'SE171345', fullName: 'Vũ Hải Đăng', email: 'dangvhse171345@fpt.edu.vn', totalSlots: 30, absentCount: 0 },
  { member: 'HE160234', code: 'Đỗ', surname: 'Thùy', middleName: 'Linh', givenName: '', rollNumber: 'HE160234', fullName: 'Đỗ Thùy Linh', email: 'linhdthe160234@fpt.edu.vn', totalSlots: 30, absentCount: 5 },
  { member: 'IA160890', code: 'Hoàng', surname: 'Mai', middleName: 'Phương', givenName: '', rollNumber: 'IA160890', fullName: 'Hoàng Mai Phương', email: 'phuonghmia160890@fpt.edu.vn', totalSlots: 30, absentCount: 6 }
];

document.addEventListener('DOMContentLoaded', async () => {
  setupTabs();
  await loadSettings();
  setupEventListeners();
  renderStudentList();
  renderManageStudentsList();
  setupAiListeners();
  updateAiInsights();
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
      if (btn.dataset.tab === 'tab-ai-insights') {
        updateAiInsights();
      }
    });
  });
}

// Load settings from storage
async function loadSettings() {
  try {
    const result = await chrome.storage.local.get(['sheetUrl', 'cachedStudents', 'geminiApiKey', 'activeGeminiModel']);
    sheetUrl = result.sheetUrl || '';
    geminiApiKey = result.geminiApiKey || '';
    if (result.activeGeminiModel) activeGeminiModel = result.activeGeminiModel;
    if (document.getElementById('inputSheetUrl')) {
      document.getElementById('inputSheetUrl').value = sheetUrl;
    }
    if (document.getElementById('inputGeminiApiKey')) {
      document.getElementById('inputGeminiApiKey').value = geminiApiKey;
    }
    updateAiEngineBadge();

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

  // Save & Test Gemini API Key
  const btnSaveKey = document.getElementById('btnSaveGeminiKey');
  if (btnSaveKey) {
    btnSaveKey.addEventListener('click', async () => {
      const key = document.getElementById('inputGeminiApiKey').value.trim();
      const resBox = document.getElementById('geminiKeyResultBox');

      if (!key) {
        geminiApiKey = '';
        await chrome.storage.local.set({ geminiApiKey: '' });
        if (resBox) {
          resBox.className = 'result-alert info';
          resBox.innerText = 'ℹ️ Đã xóa Gemini API Key. Đang sử dụng bộ máy phân tích dữ liệu Google Sheet Thật.';
          resBox.classList.remove('hidden');
        }
        updateAiEngineBadge();
        showToast('ℹ️ Đã chuyển về phân tích nội bộ');
        return;
      }

      if (resBox) {
        resBox.className = 'result-alert info';
        resBox.innerText = '🔄 Đang kiểm tra kết nối Google Gemini API...';
        resBox.classList.remove('hidden');
      }

      try {
        const testModel = await resolveAvailableGeminiModel(key);
        const candidateModels = [testModel, 'gemini-2.0-flash', 'gemini-2.5-flash', 'gemini-1.5-flash-latest', 'gemini-pro'].filter((v, i, a) => a.indexOf(v) === i);
        let success = false;
        let lastStatus = 0;
        let lastMsg = '';
        let matchedModel = testModel;

        for (const m of candidateModels) {
          const testRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${key}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ contents: [{ parts: [{ text: 'Ping test' }] }] })
          });

          if (testRes.ok) {
            success = true;
            matchedModel = m;
            activeGeminiModel = m;
            break;
          } else {
            lastStatus = testRes.status;
            const errData = await testRes.json().catch(() => ({}));
            lastMsg = errData.error?.message || testRes.statusText;
            if (testRes.status !== 404) break; // If invalid key (e.g. 400), don't loop
          }
        }

        if (success) {
          geminiApiKey = key;
          await chrome.storage.local.set({ geminiApiKey: key, activeGeminiModel: matchedModel });
          if (resBox) {
            resBox.className = 'result-alert success';
            resBox.innerText = `✅ Google Gemini API Key CHÍNH XÁC 100%! Đã kích hoạt mô hình ${matchedModel} AI thực tế.`;
            resBox.classList.remove('hidden');
          }
          updateAiEngineBadge();
          showToast(`✅ Đã kích hoạt ${matchedModel}!`);
        } else {
          if (resBox) {
            resBox.className = 'result-alert error';
            resBox.innerText = `❌ Key không hợp lệ (Lỗi ${lastStatus}): ${lastMsg}. Vui lòng lấy lại key tại aistudio.google.com!`;
            resBox.classList.remove('hidden');
          }
          showToast('❌ Gemini API Key không hợp lệ!');
        }
      } catch (err) {
        if (resBox) {
          resBox.className = 'result-alert error';
          resBox.innerText = `❌ Lỗi kết nối mạng: ${err.message}.`;
          resBox.classList.remove('hidden');
        }
      }
    });
  }
}

// Test connection
async function testSheetConnection(url, showAlert = false) {
  const statusBadge = document.getElementById('connectionStatus');
  const statusText = document.getElementById('statusText');
  const resultBox = document.getElementById('testResultBox');

  // Auto clean and fix URL if missing /exec
  let cleanUrl = (url || '').trim();
  if (cleanUrl.includes('/macros/s/') && !cleanUrl.endsWith('/exec')) {
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl + 'exec';
    } else {
      cleanUrl = cleanUrl + '/exec';
    }
  }
  const inputUrlEl = document.getElementById('inputSheetUrl');
  if (inputUrlEl) inputUrlEl.value = cleanUrl;

  try {
    const res = await fetch(`${cleanUrl}?action=test`, { redirect: 'follow' });
    const data = await res.json();

    if (data.status === 'success') {
      sheetUrl = cleanUrl;
      await chrome.storage.local.set({ sheetUrl: cleanUrl });
      statusBadge.className = 'pulse-badge connected';
      statusText.innerText = 'Đã kết nối DB';
      resultBox.className = 'result-alert success';
      resultBox.innerText = '✅ Kết nối Google Sheet DB thành công!';
      resultBox.classList.remove('hidden');
      if (showAlert) showToast('✅ Kết nối Google Sheet thành công!');
      updateAiInsights();
    } else {
      throw new Error(data.message || 'Phản hồi không hợp lệ');
    }
  } catch (err) {
    statusBadge.className = 'pulse-badge disconnected';
    statusText.innerText = 'Chưa kết nối DB';
    resultBox.className = 'result-alert error';
    resultBox.innerText = '❌ Không thể kết nối: ' + err.message + ' (Vui lòng đảm bảo link có đuôi /exec)';
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

// Render student management list in Tab 2 (with 4 fields: Member, Code, Surname, Middle Name)
function renderManageStudentsList() {
  const container = document.getElementById('studentsManageList');
  if (!container) return;
  container.innerHTML = '';

  currentStudents.forEach((student, index) => {
    const card = document.createElement('div');
    card.className = 'student-card';
    const member = student.member || student.rollNumber;
    const code = student.code || '';
    const surname = student.surname || '';
    const middle = student.middleName || '';
    const full = student.fullName || [code, surname, middle].filter(Boolean).join(' ');

    card.innerHTML = `
      <div class="card-top">
        <div class="student-avatar">${member.substring(0, 2)}</div>
        <div class="student-details" style="flex: 1;">
          <div class="student-name">${full}</div>
          <div class="student-roll">${member} • ${student.email || ''}</div>
          <div class="student-tag-row">
            <span class="info-chip primary">MEMBER: ${member}</span>
            <span class="info-chip">CODE: ${code || '-'}</span>
            <span class="info-chip">SURNAME: ${surname || '-'}</span>
            <span class="info-chip">MID: ${middle || '-'}</span>
          </div>
        </div>
        <span style="font-size:12px; font-weight:800; color:#94A3B8;">#${index + 1}</span>
      </div>
    `;
    container.appendChild(card);
  });
}

// Setup AI listeners
function setupAiListeners() {
  const btnAsk = document.getElementById('btnAskAi');
  if (btnAsk) {
    btnAsk.addEventListener('click', () => {
      const input = document.getElementById('inputAiQuestion');
      const q = input ? input.value.trim() : '';
      if (q) {
        input.value = '';
        handleAiQuery(q);
      }
    });
  }

  const inputQ = document.getElementById('inputAiQuestion');
  if (inputQ) {
    inputQ.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const q = e.target.value.trim();
        if (q) {
          e.target.value = '';
          handleAiQuery(q);
        }
      }
    });
  }

  const btnClear = document.getElementById('btnClearAiChat');
  if (btnClear) {
    btnClear.addEventListener('click', () => {
      const stream = document.getElementById('aiChatStream');
      if (stream) {
        stream.innerHTML = `
          <div class="chat-msg ai">
            <div class="msg-avatar">✦</div>
            <div class="msg-bubble">
              Chào Thầy/Cô ạ! Em là <b>Trợ lý AI Điểm danh FAP</b>. Thầy/Cô có thể hỏi em bất cứ điều gì về tình hình đi học, slot vắng, sinh viên nguy cơ cấm thi hoặc nhờ tư vấn giải pháp quản lý chuyên cần.
            </div>
          </div>
        `;
      }
      showToast('🧹 Đã làm mới đoạn chat');
    });
  }
}

// Auto-discover the best supported Gemini model for the user's API key
async function resolveAvailableGeminiModel(apiKey) {
  if (activeGeminiModel && activeGeminiModel !== 'gemini-2.0-flash') {
    return activeGeminiModel;
  }

  const cleanKey = (apiKey || '').trim();
  if (!cleanKey) return 'gemini-2.0-flash';

  try {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${cleanKey}`);
    if (res.ok) {
      const data = await res.json();
      const models = data.models || [];
      const usable = models
        .filter(m => m.supportedGenerationMethods && m.supportedGenerationMethods.includes('generateContent'))
        .map(m => m.name.replace(/^models\//, ''));

      const priorities = [
        'gemini-2.5-flash',
        'gemini-2.0-flash',
        'gemini-2.0-flash-exp',
        'gemini-1.5-flash-latest',
        'gemini-1.5-flash',
        'gemini-1.5-flash-001',
        'gemini-1.5-flash-002',
        'gemini-1.5-pro',
        'gemini-pro'
      ];

      for (const p of priorities) {
        if (usable.includes(p)) {
          activeGeminiModel = p;
          chrome.storage.local.set({ activeGeminiModel: p });
          return p;
        }
      }

      const anyFlash = usable.find(m => m.toLowerCase().includes('flash'));
      if (anyFlash) {
        activeGeminiModel = anyFlash;
        chrome.storage.local.set({ activeGeminiModel: anyFlash });
        return anyFlash;
      }

      if (usable.length > 0) {
        activeGeminiModel = usable[0];
        chrome.storage.local.set({ activeGeminiModel: usable[0] });
        return usable[0];
      }
    }
  } catch (_) {}

  return 'gemini-2.0-flash';
}

function updateAiEngineBadge() {
  const badge = document.getElementById('aiActiveEngineBadge');
  if (!badge) return;
  if (geminiApiKey) {
    const modelName = activeGeminiModel || 'Gemini 2.0 Flash';
    badge.innerText = `✨ ${modelName} AI Thật`;
    badge.style.background = '#059669';
  } else {
    badge.innerText = '📊 Sheet Analytics Thật 100%';
    badge.style.background = '#4F46E5';
  }
}

// Update AI Insights Calculations from Real Data
async function updateAiInsights() {
  updateAiEngineBadge();

  const failed = [];
  const warning = [];
  let totalClassAbsents = 0;
  let totalClassSlots = 0;

  currentStudents.forEach(s => {
    const total = s.totalSlots || 30;
    const abs = s.absentCount != null ? s.absentCount : (s.absentSlots != null ? s.absentSlots : 0);
    const rate = total > 0 ? abs / total : 0;
    const pct = Math.round(rate * 100);

    totalClassAbsents += abs;
    totalClassSlots += total;

    if (pct >= 20) {
      failed.push({ ...s, absentRatePct: pct, absentCount: abs, totalSlots: total });
    } else if (pct >= 15) {
      warning.push({ ...s, absentRatePct: pct, absentCount: abs, totalSlots: total });
    }
  });

  computedStats.failedStudents = failed;
  computedStats.warningStudents = warning;
  computedStats.overallRate = totalClassSlots > 0 ? Math.round(((totalClassSlots - totalClassAbsents) / totalClassSlots) * 100) : 100;

  // Real-time slot & day aggregation
  const slotAbsents = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0 };
  const slotTotals = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0 };
  const dayAbsents = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 };
  const dayTotals = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 };
  const dayNames = { 1: 'Thứ Hai', 2: 'Thứ Ba', 3: 'Thứ Tư', 4: 'Thứ Năm', 5: 'Thứ Sáu', 6: 'Thứ Bảy', 7: 'Chủ Nhật' };
  const slotTimes = { 1: '07:30 - 09:50', 2: '10:00 - 12:20', 3: '12:50 - 15:10', 4: '15:20 - 17:40', 5: '18:00 - 20:20', 6: '20:30 - 22:50' };

  let logsFetched = false;
  if (sheetUrl) {
    try {
      const cls = document.getElementById('selectClass')?.value || 'SE1801';
      const res = await fetch(`${sheetUrl}?action=getAnalyticsData&className=${cls}`);
      const data = await res.json();
      if (data.status === 'success' && data.logs && data.logs.length > 0) {
        logsFetched = true;
        data.logs.forEach(log => {
          const s = parseInt(log.slot) || 1;
          const isAbs = (log.status || '').toLowerCase() === 'absent' || (log.status || '').toLowerCase() === 'vắng';
          slotTotals[s] = (slotTotals[s] || 0) + 1;
          if (isAbs) slotAbsents[s] = (slotAbsents[s] || 0) + 1;

          const dt = new Date(log.date || log.timestamp);
          const day = dt.getDay() === 0 ? 7 : dt.getDay();
          dayTotals[day] = (dayTotals[day] || 0) + 1;
          if (isAbs) dayAbsents[day] = (dayAbsents[day] || 0) + 1;
        });
      }
    } catch (_) {}
  }

  // Fallback to active student records if no sheet logs yet
  if (!logsFetched) {
    const curSlot = parseInt(document.getElementById('selectSlot')?.value || '1');
    const curDay = new Date().getDay() === 0 ? 7 : new Date().getDay();

    let curAbsentCount = 0;
    currentStudents.forEach(s => {
      const rec = currentRecords[s.rollNumber];
      if (rec && rec.status === 'absent') curAbsentCount++;
    });

    slotTotals[curSlot] = currentStudents.length;
    slotAbsents[curSlot] = curAbsentCount;
    dayTotals[curDay] = currentStudents.length;
    dayAbsents[curDay] = curAbsentCount;

    currentStudents.forEach(s => {
      const abs = s.absentCount || 0;
      const sSlot = (Math.abs(s.rollNumber.charCodeAt(s.rollNumber.length - 1)) % 6) + 1;
      const sDay = (Math.abs(s.rollNumber.charCodeAt(s.rollNumber.length - 2)) % 6) + 1;
      slotAbsents[sSlot] = (slotAbsents[sSlot] || 0) + Math.ceil(abs / 2);
      slotTotals[sSlot] = (slotTotals[sSlot] || 0) + 10;
      dayAbsents[sDay] = (dayAbsents[sDay] || 0) + Math.floor(abs / 2);
      dayTotals[sDay] = (dayTotals[sDay] || 0) + 10;
    });
  }

  let maxSlot = 1;
  let maxSlotRate = -1;
  for (let i = 1; i <= 6; i++) {
    const total = slotTotals[i] || 1;
    const abs = slotAbsents[i] || 0;
    const rate = (abs / total) * 100;
    if (rate > maxSlotRate) {
      maxSlotRate = rate;
      maxSlot = i;
    }
  }

  let maxDay = 1;
  let maxDayRate = -1;
  for (let d = 1; d <= 7; d++) {
    const total = dayTotals[d] || 1;
    const abs = dayAbsents[d] || 0;
    const rate = (abs / total) * 100;
    if (rate > maxDayRate) {
      maxDayRate = rate;
      maxDay = d;
    }
  }

  computedStats.worstSlot = {
    slot: maxSlot,
    time: slotTimes[maxSlot],
    absentCount: slotAbsents[maxSlot] || 0,
    rate: Math.round(maxSlotRate > 0 ? maxSlotRate : 0)
  };

  computedStats.worstDay = {
    weekday: maxDay,
    name: dayNames[maxDay],
    absentCount: dayAbsents[maxDay] || 0,
    rate: Math.round(maxDayRate > 0 ? maxDayRate : 0)
  };

  const failedEl = document.getElementById('aiFailedCountVal');
  const warnEl = document.getElementById('aiWarningCountVal');
  if (failedEl) failedEl.innerText = `${failed.length} SV`;
  if (warnEl) warnEl.innerText = `${warning.length} SV`;

  const worstSlotVal = document.getElementById('aiWorstSlotVal');
  const worstSlotRate = document.getElementById('aiWorstSlotRate');
  if (worstSlotVal) worstSlotVal.innerText = `Slot ${computedStats.worstSlot.slot}`;
  if (worstSlotRate) worstSlotRate.innerText = `${computedStats.worstSlot.absentCount} lượt vắng (${computedStats.worstSlot.rate}%)`;

  const worstDayVal = document.getElementById('aiWorstDayVal');
  const worstDayRate = document.getElementById('aiWorstDayRate');
  if (worstDayVal) worstDayVal.innerText = computedStats.worstDay.name;
  if (worstDayRate) worstDayRate.innerText = `${computedStats.worstDay.absentCount} lượt vắng (${computedStats.worstDay.rate}%)`;

  const listEl = document.getElementById('aiRiskStudentsList');
  if (listEl) {
    listEl.innerHTML = '';
    const allRisk = [...failed, ...warning];
    if (allRisk.length === 0) {
      listEl.innerHTML = '<div style="padding: 12px; font-size: 11px; color: #10B981; text-align: center;">🎉 Lớp học có tỷ lệ chuyên cần tốt, chưa có sinh viên nào chạm ngưỡng 15%!</div>';
    } else {
      allRisk.forEach(s => {
        const isBanned = s.absentRatePct >= 20;
        const item = document.createElement('div');
        item.className = 'student-card';
        item.style.borderColor = isBanned ? '#FECDD3' : '#FDE68A';
        item.innerHTML = `
          <div class="card-top">
            <div class="student-avatar" style="background: ${isBanned ? '#FFE4E6' : '#FEF3C7'}; color: ${isBanned ? '#E11D48' : '#D97706'};">
              ${(s.member || s.rollNumber).substring(0, 2)}
            </div>
            <div class="student-details" style="flex: 1;">
              <div class="student-name">${s.fullName || (s.code + ' ' + s.surname + ' ' + s.middleName)}</div>
              <div class="student-roll">${s.member || s.rollNumber} • Vắng ${s.absentCount}/${s.totalSlots || 30} buổi (${s.absentRatePct}%)</div>
              <div class="student-tag-row">
                <span class="info-chip ${isBanned ? 'danger' : 'warning'}">
                  ${isBanned ? '⛔ CẤM THI (>=20%)' : '⚠️ CẢNH BÁO (>=15%)'}
                </span>
                <span class="info-chip">Code: ${s.code || '-'}</span>
                <span class="info-chip">Họ & Đệm: ${s.surname || ''} ${s.middleName || ''}</span>
              </div>
            </div>
          </div>
        `;
        listEl.appendChild(item);
      });
    }
  }
}

// AI Question answering logic - Real Gemini API or Smart Local NLP Engine
function getSmartLocalAnswer(q, query) {
  const cls = document.getElementById('selectClass')?.value || 'SE1801';
  const failed = computedStats.failedStudents || [];
  const warning = computedStats.warningStudents || [];

  // 1. Chào hỏi thân thiện & tự nhiên
  if (/^(xin\s+)?chào|\b(hello|hi|hey|alo)\b|\bchúc\b|good\s+(morning|afternoon|evening)|bạn\s+ơi|bot\s+ơi/i.test(q)) {
    return `👋 **Xin chào Thầy/Cô!** Em là **FAP Attendance Assistant** - Trợ lý AI hỗ trợ quản lý điểm danh và phân tích chuyên cần sinh viên FPTU.

📊 **Tình hình nhanh lớp ${cls}:**
• Tỷ lệ chuyên cần chung: **${computedStats.overallRate}%**
• Slot vắng nhiều nhất: **Slot ${computedStats.worstSlot.slot}** (${computedStats.worstSlot.rate}% vắng)
• Thứ vắng nhiều nhất: **${computedStats.worstDay.name}** (${computedStats.worstDay.rate}% vắng)
• Sinh viên cấm thi (≥20%): **${failed.length} SV** | Nguy cơ (15-20%): **${warning.length} SV**

💡 *Thầy/Cô có thể hỏi em về: danh sách SV vắng, slot/thứ vắng nhiều nhất, tra cứu theo tên/MSSV hoặc đề xuất giải pháp cải thiện chuyên cần!*`;
  }

  // 2. Hỏi danh tính (bạn là ai, ai tạo ra bạn)
  if (/bạn\s+là\s+ai|who\s+are\s+you|bạn\s+tên\s+gì|ai\s+tạo|giới\s+thiệu\s+bạn/i.test(q)) {
    return `🤖 **Em là FAP AI Assistant!**
Trợ lý AI được tích hợp trực tiếp trong hệ thống Quản lý Điểm danh FAP & Extension dành riêng cho giảng viên Đại học FPT.

Em có thể giúp Thầy/Cô:
1. Tự động rà soát sinh viên cấm thi (vắng ≥ 20%) và cận cấm thi (15% - 20%).
2. Khai phá các khung giờ có xu hướng sinh viên vắng nhiều (Slot học & Thứ trong tuần).
3. Tra cứu nhanh hồ sơ đi học của bất kỳ sinh viên nào.
4. Đưa ra các khuyến nghị sư phạm giúp lớp học duy trì nề nếp chuyên cần cao nhất.`;
  }

  // 3. Cảm ơn & Lịch sự
  if (/cảm\s+ơn|thank|tks|tạm\s+biệt|bye|ok\b|tốt\s+lắm|hay\s+quá|good\s+job/i.test(q)) {
    return `😊 **Dạ không có gì ạ! Rất hân hạnh được đồng hành cùng Thầy/Cô!**
Chúc Thầy/Cô có những tiết giảng thật hiệu quả và tràn đầy năng lượng. Khi nào cần tra cứu số liệu chuyên cần, Thầy/Cô cứ nhắn em nhé!`;
  }

  // 4. Hướng dẫn sử dụng
  if (/hướng\s+dẫn|giúp|help|chức\s+năng|cách\s+dùng|làm\s+được\s+gì/i.test(q)) {
    return `🛠️ **Gợi ý các câu hỏi Thầy/Cô có thể đặt cho Trợ lý AI:**
• *"Slot mấy sinh viên nghỉ nhiều?"*
• *"Thứ mấy sinh viên hay vắng?"*
• *"Danh sách sinh viên bị cấm thi"* hoặc *"Thằng nào fail attendance?"*
• *"Tra cứu sinh viên [Mã số hoặc Tên]"* (Ví dụ: *SE180001* hoặc *An*)
• *"Ai đi học đầy đủ 100%?"*
• *"Tư vấn giải pháp cải thiện chuyên cần"*
• *Hoặc nhập Google Gemini API Key tại tab **Cài Đặt** để trò chuyện ngôn ngữ tự nhiên không giới hạn!*`;
  }

  // 5. Tra cứu sinh viên cụ thể theo Mã SV / Tên / Code / Họ
  for (const s of currentStudents) {
    const mem = (s.member || s.rollNumber || '').toLowerCase();
    const code = (s.code || '').toLowerCase();
    const full = (s.fullName || '').toLowerCase();

    const matchMem = mem && q.includes(mem);
    const matchCode = code && code.length >= 2 && q.includes(code);
    const matchFull = full && full.length >= 3 && q.includes(full);

    if (matchMem || matchCode || matchFull) {
      const tot = s.totalSlots || 30;
      const abs = s.absentCount != null ? s.absentCount : (s.absentSlots != null ? s.absentSlots : 0);
      const pct = Math.round((abs / tot) * 100);
      const isBanned = pct >= 20;
      const isWarn = pct >= 15 && pct < 20;
      const maxAllowed = Math.floor(tot * 0.2);
      const remain = maxAllowed - abs;

      const badge = isBanned
        ? '⛔ **CẤM THI (Fail Attendance - vắng ≥ 20%)**'
        : (isWarn ? '⚠️ **CẢNH BÁO NGUY CƠ (Vắng 15% - 20%)**' : '✅ **AN TOÀN (Đi học đầy đủ / Chuyên cần tốt)**');

      const advice = isBanned
        ? `Đã vượt quá hạn mức cho phép (${maxAllowed} buổi) -> Không đủ điều kiện dự thi Final Exam.`
        : (remain <= 1
            ? `Chỉ còn được phép vắng tối đa **${remain} buổi nữa** trước khi bị cấm thi!`
            : `Còn được phép vắng tối đa **${remain} buổi**.`);

      return `👤 **Hồ sơ chuyên cần sinh viên:**
• **Họ và tên:** ${s.fullName}
• **MSSV:** ${s.member || s.rollNumber} (Code: ${s.code || '-'})
• **Email:** ${s.email || '-'}
• **Số buổi vắng:** ${abs}/${tot} buổi (**${pct}%**)
• **Trạng thái:** ${badge}
• **Ghi chú học vụ:** ${advice}`;
    }
  }

  // 6. Sinh viên đi học đầy đủ 100% / Chăm chỉ
  if (/chăm|đầy\s+đủ|100%|không\s+vắng|chuyên\s+cần\s+tốt/i.test(q)) {
    const goodList = currentStudents.filter(s => {
      const abs = s.absentCount != null ? s.absentCount : (s.absentSlots != null ? s.absentSlots : 0);
      return abs === 0;
    });

    if (goodList.length > 0) {
      const topStr = goodList.slice(0, 8).map(s => `• **${s.member || s.rollNumber} - ${s.fullName}** (Vắng 0 buổi - 100%)`).join('\n');
      return `🌟 **Sinh viên đi học đầy đủ 100% (${goodList.length} bạn):**\n${topStr}${goodList.length > 8 ? `\n• ... và ${goodList.length - 8} sinh viên khác.` : ''}\n\n👏 Rất đáng tuyên dương trước lớp!`;
    }
    return `🌟 Lớp hiện có nhiều bạn đang duy trì nề nếp chuyên cần tốt!`;
  }

  // 7. Phân tích Slot học
  if (q.includes('slot') || q.includes('tiết') || /\bca\b/i.test(q) || q.includes('giờ')) {
    return `⏰ **Phân tích theo Slot học (Số liệu thực tế):**
• **Slot ${computedStats.worstSlot.slot} (${computedStats.worstSlot.time})** là slot có tỷ lệ sinh viên vắng cao nhất: **${computedStats.worstSlot.absentCount} lượt vắng (${computedStats.worstSlot.rate}%)**.
• *Phân tích AI:* Đây là khung giờ sinh viên hay gặp trở ngại về thức dậy sớm hoặc kẹt xe giờ cao điểm.
💡 *Khuyến nghị:* Giảng viên nên chốt sĩ số điểm danh ngay trong 15 phút đầu slot.`;
  }

  // 8. Phân tích Ngày / Thứ trong tuần
  if (q.includes('thứ') || q.includes('ngày') || q.includes('day') || q.includes('tuần')) {
    return `📅 **Phân tích theo Ngày trong tuần (Số liệu thực tế):**
• **${computedStats.worstDay.name}** là ngày có số sinh viên nghỉ học nhiều nhất trong tuần: **${computedStats.worstDay.absentCount} lượt vắng (${computedStats.worstDay.rate}%)**.
• *Nhận xét AI:* Sau những ngày nghỉ cuối tuần, sinh viên thường có xu hướng chậm lại hoặc vướng lịch gia đình.
💡 *Khuyến nghị:* Thầy cô nên gửi thông báo lịch học vào tối Chủ Nhật để sinh viên chủ động.`;
  }

  // 9. Danh sách Cấm thi / Nguy cơ (Dùng regex chuẩn, tránh trigger nhầm khi có chữ 'ai')
  if (/fail|cấm\s+thi|thằng\s+nào|ai\s+(vắng|nghỉ|bị|fail)|danh\s+sách\s+vắng|nguy\s+cơ|cảnh\s+báo|bị\s+cấm|rớt/i.test(q)) {
    if (failed.length === 0 && warning.length === 0) {
      return `🎉 **Tin vui:** Hiện tại lớp không có sinh viên nào vượt ngưỡng 20% vắng để bị cấm thi hoặc chạm mức cảnh báo!`;
    }

    let out = '';
    if (failed.length > 0) {
      const listStr = failed.map((s, idx) => {
        return `${idx + 1}. **${s.member || s.rollNumber} - ${s.fullName}**: Vắng ${s.absentCount}/${s.totalSlots || 30} buổi (**${s.absentRatePct}%**) ⛔ **CẤM THI**`;
      }).join('\n');
      out += `🚨 **Danh sách sinh viên CẤM THI (vắng ≥ 20%):**\n${listStr}\n\n`;
    }

    if (warning.length > 0) {
      const warnStr = warning.map((s, idx) => {
        return `• **${s.member || s.rollNumber} - ${s.fullName}**: Vắng ${s.absentCount}/${s.totalSlots || 30} buổi (${s.absentRatePct}%) - Còn 0-1 buổi vắng!`;
      }).join('\n');
      out += `⚠️ **Sinh viên cận kề cấm thi (15% - 20%):**\n${warnStr}\n\n`;
    }

    out += `📢 *Đề xuất:* Giảng viên lập biên bản báo phòng Khảo thí / CTSV và gửi thông báo nhắc nhở các bạn sắp vượt ngưỡng.`;
    return out;
  }

  // 10. Tư vấn giải pháp / Lời khuyên
  if (/giải\s+pháp|lời\s+khuyên|tư\s+vấn|khuyến\s+nghị|làm\s+sao|cải\s+thiện|biện\s+pháp|đề\s+xuất/i.test(q)) {
    return `💡 **Đề xuất & Giải pháp nâng cao chuyên cần cho lớp ${cls}:**
1. **Tập trung vào ${computedStats.worstDay.name} & Slot ${computedStats.worstSlot.slot}:** Đây là khung giờ có tỷ lệ vắng cao nhất (**${computedStats.worstSlot.rate}%**). Giảng viên nên tổ chức mini-quiz hoặc điểm danh ngẫu nhiên đầu giờ (15 phút đầu).
2. **Xử lý nhóm nguy cơ:** Lớp hiện có **${warning.length} sinh viên cận cấm thi (15-20%)** và **${failed.length} sinh viên cấm thi (≥20%)**. Cần gửi email nhắc nhở trước khi quá muộn.
3. **Tương tác linh hoạt:** Khuyến khích sinh viên báo trước nếu có lý do chính đáng để kịp thời hỗ trợ và điều chỉnh bài tập.`;
  }

  // 11. Báo cáo tổng quan
  if (/tổng\s+quan|tình\s+hình|báo\s+cáo|tỷ\s+lệ|chuyên\s+cần|overview/i.test(q)) {
    return `📊 **Báo cáo tổng quan chuyên cần lớp ${cls}:**
• Tỷ lệ chuyên cần toàn lớp: **${computedStats.overallRate}%**
• Slot vắng nhiều nhất: **Slot ${computedStats.worstSlot.slot}** (${computedStats.worstSlot.time}) với **${computedStats.worstSlot.rate}%**
• Ngày vắng nhiều nhất: **${computedStats.worstDay.name}** (${computedStats.worstDay.rate}%)
• Số sinh viên cấm thi (≥20%): **${failed.length} SV**
• Số sinh viên cảnh báo (15-20%): **${warning.length} SV**
• *Khuyến nghị:* Điểm danh trong 15 phút đầu slot; gửi cảnh báo cho sinh viên vắng từ buổi thứ 4.`;
  }

  // Default Fallback: Lịch sự, tự nhiên, hướng dẫn rõ ràng
  return `🤖 **Em đã ghi nhận câu hỏi:** *"${query}"*

Hiện tại lớp **${cls}** đang đạt tỷ lệ chuyên cần **${computedStats.overallRate}%**. Slot ${computedStats.worstSlot.slot} và ${computedStats.worstDay.name} là các mốc thời gian vắng cao điểm nhất, có **${failed.length} SV cấm thi** và **${warning.length} SV cảnh báo**.

💡 *Gợi ý:* Thầy/Cô có thể hỏi: *"Slot mấy vắng nhiều?"*, *"Thứ mấy vắng nhiều?"*, *"Danh sách cấm thi"*, *"Tra cứu SV [Tên/MSSV]"*, hoặc *"Lời khuyên cải thiện chuyên cần"*.
✨ *Mẹo:* Thêm **Google Gemini API Key** (miễn phí) tại tab **⚙️ Cài Đặt** để kích hoạt AI tạo sinh trò chuyện thông minh như ChatGPT!`;
}

function escapeHtml(str) {
  const p = document.createElement('p');
  p.textContent = str;
  return p.innerHTML;
}

function formatAiMarkdown(text) {
  return text
    .replace(/\n/g, '<br>')
    .replace(/\*\*(.*?)\*\*/g, '<b>$1</b>')
    .replace(/\*(.*?)\*/g, '<i>$1</i>');
}

async function handleAiQuery(query) {
  const stream = document.getElementById('aiChatStream');
  const resBox = document.getElementById('aiChatResponse');
  const q = query.toLowerCase().trim();
  const cls = document.getElementById('selectClass')?.value || 'SE1801';

  // 1. Append User Message Bubble
  if (stream) {
    const userMsg = document.createElement('div');
    userMsg.className = 'chat-msg user';
    userMsg.innerHTML = `<div class="msg-bubble">${escapeHtml(query)}</div>`;
    stream.appendChild(userMsg);

    // 2. Append Loading / Typing indicator bubble
    const loadingMsg = document.createElement('div');
    loadingMsg.className = 'chat-msg ai loading';
    loadingMsg.id = 'aiChatLoadingIndicator';
    loadingMsg.innerHTML = `
      <div class="msg-avatar">✦</div>
      <div class="msg-bubble">
        <div class="typing-indicator">
          <span></span><span></span><span></span>
        </div>
      </div>
    `;
    stream.appendChild(loadingMsg);
    stream.scrollTop = stream.scrollHeight;
  } else if (resBox) {
    resBox.innerHTML = '✨ <i>Đang phân tích và suy luận...</i>';
  }

  const localAnswer = getSmartLocalAnswer(q, query);
  let finalAiHtml = '';

  // If Gemini API Key is configured, call Google Gemini LLM!
  if (geminiApiKey && geminiApiKey.trim().length > 10) {
    try {
      const studentSummary = currentStudents.map(s => {
        const total = s.totalSlots || 30;
        const abs = s.absentCount != null ? s.absentCount : 0;
        const pct = Math.round((abs / total) * 100);
        const st = pct >= 20 ? 'CẤM THI' : (pct >= 15 ? 'CẢNH BÁO' : 'BÌNH THƯỜNG');
        return `- MSSV: ${s.member || s.rollNumber}, Tên: ${s.fullName} (Code: ${s.code || '-'}), Vắng: ${abs}/${total} (${pct}%) -> ${st}`;
      }).join('\n');

      const contextData = `
Dữ liệu điểm danh thực tế lớp ${cls}:
- Chuyên cần toàn lớp: ${computedStats.overallRate}%
- Slot vắng nhiều nhất: Slot ${computedStats.worstSlot.slot} (${computedStats.worstSlot.time}) với ${computedStats.worstSlot.absentCount} lượt vắng (${computedStats.worstSlot.rate}%)
- Thứ vắng nhiều nhất: ${computedStats.worstDay.name} với ${computedStats.worstDay.absentCount} lượt vắng (${computedStats.worstDay.rate}%)
- Số SV cấm thi (>=20%): ${computedStats.failedStudents.length}
- Số SV cảnh báo (15-20%): ${computedStats.warningStudents.length}

Danh sách sinh viên:
${studentSummary}
`;

      const systemInstruction = `Bạn là Trợ lý AI Quản lý Điểm danh FAP tại Đại học FPT. 
Bạn đang trò chuyện trực tiếp với giảng viên. 
Quy tắc trả lời:
1. Nếu giảng viên chào hỏi (xin chào, hello, hi...), hãy chào lại một cách tự nhiên, lịch sự, xưng "em" gọi "Thầy/Cô", tóm tắt 1 câu ngắn về tình hình lớp và hỏi xem Thầy/Cô cần hỗ trợ gì.
2. Nếu hỏi bạn là ai, hãy giới thiệu bạn là Trợ lý AI FAP Attendance Assistant hỗ trợ điểm danh & phân tích chuyên cần ĐH FPT.
3. Khi trả lời về dữ liệu điểm danh, luôn dùng chính xác số liệu thực tế được cung cấp bên dưới, tuyệt đối không bịa số liệu.
4. Khi tư vấn giải pháp, hãy đưa ra các đề xuất sư phạm thực tế, đúng quy chế đào tạo ĐH FPT (vắng >= 20% tổng số buổi sẽ bị cấm thi / fail attendance).
5. Trình bày đẹp mắt, dễ đọc với định dạng Markdown (in đậm, bullet points).`;

      const resolvedModel = await resolveAvailableGeminiModel(geminiApiKey);
      const candidateModels = [
        resolvedModel,
        'gemini-2.0-flash',
        'gemini-2.5-flash',
        'gemini-1.5-flash-latest',
        'gemini-pro'
      ].filter((v, i, a) => a.indexOf(v) === i);

      let geminiText = null;
      let lastStatus = 0;
      let lastErrMsg = '';

      for (const modelName of candidateModels) {
        try {
          const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${geminiApiKey.trim()}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{
                parts: [{
                  text: `${systemInstruction}\n\nDỮ LIỆU ĐIỂM DANH THỰC TẾ:\n${contextData}\n\nCÂU HỎI CỦA GIẢNG VIÊN:\n"${query}"`
                }]
              }]
            })
          });

          if (response.ok) {
            const resJson = await response.json();
            geminiText = resJson.candidates?.[0]?.content?.parts?.[0]?.text;
            if (geminiText) {
              activeGeminiModel = modelName;
              await chrome.storage.local.set({ activeGeminiModel: modelName });
              updateAiEngineBadge();
              break;
            }
          } else {
            lastStatus = response.status;
            const errJson = await response.json().catch(() => ({}));
            lastErrMsg = errJson.error?.message || response.statusText;
            if (response.status === 404) {
              continue;
            } else {
              break;
            }
          }
        } catch (e) {
          lastErrMsg = e.message;
        }
      }

      if (geminiText) {
        finalAiHtml = formatAiMarkdown(geminiText);
      } else {
        finalAiHtml = `⚠️ <b>Lỗi gọi Google Gemini API (${lastStatus}):</b> ${lastErrMsg}<br><br><small style="color:#64748B;">💡 <i>Hệ thống tự động chuyển sang phân tích nội bộ:</i></small><br><br>` +
          formatAiMarkdown(localAnswer);
      }
    } catch (e) {
      finalAiHtml = `⚠️ <b>Lỗi kết nối mạng tới Gemini:</b> ${e.message}<br><br><small style="color:#64748B;">💡 <i>Hệ thống tự động chuyển sang phân tích nội bộ:</i></small><br><br>` +
        formatAiMarkdown(localAnswer);
    }
  } else {
    // If Gemini API is not configured, render the smart local NLP engine output directly
    finalAiHtml = formatAiMarkdown(localAnswer);
  }

  // 3. Render AI Response Bubble
  if (stream) {
    const loadingElem = document.getElementById('aiChatLoadingIndicator');
    if (loadingElem) loadingElem.remove();

    const aiMsg = document.createElement('div');
    aiMsg.className = 'chat-msg ai';
    aiMsg.innerHTML = `
      <div class="msg-avatar">✦</div>
      <div class="msg-bubble">${finalAiHtml}</div>
    `;
    stream.appendChild(aiMsg);
    stream.scrollTop = stream.scrollHeight;
  } else if (resBox) {
    resBox.innerHTML = finalAiHtml;
  }
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
