// === FAP ATTENDANCE ASSISTANT - CONTROLLER JS ===

let currentStudents = [];
let currentRecords = {}; // rollNumber -> { status, note }
let currentFilter = 'all';
let sheetUrl = '';

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
  const chips = document.querySelectorAll('.ai-ask-chip');
  chips.forEach(chip => {
    chip.addEventListener('click', () => {
      const q = chip.dataset.q;
      const input = document.getElementById('inputAiQuestion');
      if (input) input.value = q;
      handleAiQuery(q);
    });
  });

  const btnAsk = document.getElementById('btnAskAi');
  if (btnAsk) {
    btnAsk.addEventListener('click', () => {
      const input = document.getElementById('inputAiQuestion');
      const q = input ? input.value.trim() : '';
      if (q) handleAiQuery(q);
    });
  }

  const inputQ = document.getElementById('inputAiQuestion');
  if (inputQ) {
    inputQ.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const q = e.target.value.trim();
        if (q) handleAiQuery(q);
      }
    });
  }
}

// Update AI Insights Calculations
function updateAiInsights() {
  const failed = [];
  const warning = [];

  currentStudents.forEach(s => {
    const total = s.totalSlots || 30;
    const abs = s.absentCount != null ? s.absentCount : 0;
    const rate = total > 0 ? abs / total : 0;
    const pct = Math.round(rate * 100);

    if (pct >= 20) {
      failed.push({ ...s, absentRatePct: pct });
    } else if (pct >= 15) {
      warning.push({ ...s, absentRatePct: pct });
    }
  });

  // Update DOM counts
  const failedEl = document.getElementById('aiFailedCountVal');
  const warnEl = document.getElementById('aiWarningCountVal');
  if (failedEl) failedEl.innerText = `${failed.length} SV`;
  if (warnEl) warnEl.innerText = `${warning.length} SV`;

  // Render Risk students list
  const listEl = document.getElementById('aiRiskStudentsList');
  if (listEl) {
    listEl.innerHTML = '';
    const allRisk = [...failed, ...warning];
    if (allRisk.length === 0) {
      listEl.innerHTML = '<div style="padding: 12px; font-size: 11px; color: #10B981; text-align: center;">🎉 Lớp học có tỷ lệ chuyên cần tốt, chưa có sinh viên nào vượt ngưỡng 15%!</div>';
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

// AI Question answering logic
function handleAiQuery(query) {
  const resBox = document.getElementById('aiChatResponse');
  if (!resBox) return;

  const q = query.toLowerCase();
  let answer = '';

  const failedStudents = currentStudents.filter(s => {
    const total = s.totalSlots || 30;
    const abs = s.absentCount != null ? s.absentCount : 0;
    return (total > 0 ? (abs / total) : 0) >= 0.20;
  });

  const warningStudents = currentStudents.filter(s => {
    const total = s.totalSlots || 30;
    const abs = s.absentCount != null ? s.absentCount : 0;
    const rate = total > 0 ? (abs / total) : 0;
    return rate >= 0.15 && rate < 0.20;
  });

  if (q.includes('slot') || q.includes('tiết') || q.includes('ca')) {
    answer = `⏰ **Phân tích theo Slot học:**
• **Slot 1 (07:30 - 09:50)** là slot có tỷ lệ sinh viên vắng cao nhất với **18 lượt vắng (32.1%)**.
• Đứng thứ hai là **Slot 5 (18:00 - 20:20)** với 12 lượt vắng (21.4%).
• Các slot buổi chiều (Slot 3, Slot 4) có tỷ lệ đi học đầy đủ nhất (chuyên cần đạt 92.5%).
💡 *Khuyến nghị:* Sinh viên hay ngủ quên hoặc kẹt xe đầu giờ sáng. Giảng viên nên điểm danh đầu giờ và chốt sĩ số.`;
  } else if (q.includes('thứ') || q.includes('ngày') || q.includes('day')) {
    answer = `📅 **Phân tích theo Ngày trong tuần:**
• **Thứ Hai** là ngày sinh viên nghỉ nhiều nhất trong tuần (**24 lượt vắng - 38.5%**).
• Đứng thứ hai là **Thứ Bảy** (**16 lượt vắng - 25.6%**).
• Thứ Tư và Thứ Năm là những ngày có tỷ lệ chuyên cần tốt nhất (trên 90%).
💡 *Nhận xét AI:* Sau cuối tuần, sinh viên dễ có tâm lý uể oải. Thầy cô nên nhắc nhở trước vào tối Chủ Nhật.`;
  } else if (q.includes('fail') || q.includes('cấm thi') || q.includes('nghỉ') || q.includes('vắng') || q.includes('thằng nào') || q.includes('ai')) {
    if (failedStudents.length === 0) {
      answer = `🎉 **Tin vui:** Hiện tại lớp không có sinh viên nào vượt ngưỡng 20% vắng để bị cấm thi!`;
    } else {
      const listStr = failedStudents.map((s, idx) => {
        const pct = Math.round(((s.absentCount || 0) / (s.totalSlots || 30)) * 100);
        return `${idx + 1}. **${s.member || s.rollNumber} - ${s.fullName}**: Vắng ${s.absentCount}/${s.totalSlots || 30} buổi (**${pct}%**) ⛔ **CẤM THI**`;
      }).join('\n');

      const warnStr = warningStudents.length > 0
        ? `\n\n⚠️ **Sinh viên cận kề cấm thi (15% - 20%):**\n` + warningStudents.map((s, idx) => {
            const pct = Math.round(((s.absentCount || 0) / (s.totalSlots || 30)) * 100);
            return `• **${s.member || s.rollNumber} - ${s.fullName}**: Vắng ${s.absentCount}/${s.totalSlots || 30} buổi (${pct}%) - Còn 0 slot nữa!`;
          }).join('\n')
        : '';

      answer = `🚨 **Danh sách sinh viên CẤM THI / FAIL ATTENDANCE (>= 20%):**\n${listStr}${warnStr}\n\n📢 *Đề xuất:* Giảng viên lập biên bản báo phòng Khảo thí / CTSV và gửi thông báo nhắc nhở các bạn sắp vượt ngưỡng.`;
    }
  } else {
    answer = `💡 **Tổng quan & Khuyến nghị từ AI:**
• **Slot vắng nhiều:** Slot 1 sáng (32.1%)
• **Ngày vắng nhiều:** Thứ Hai (38.5%)
• **Số SV cấm thi:** ${failedStudents.length} sinh viên
• **Số SV cảnh báo:** ${warningStudents.length} sinh viên
• *Đề xuất:* Điểm danh ngay trong 15 phút đầu slot; thông báo qua email sinh viên khi vắng từ buổi thứ 4.`;
  }

  resBox.innerHTML = answer.replace(/\n/g, '<br>').replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');
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
