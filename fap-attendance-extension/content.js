// content.js - Injected into FAP attendance pages

console.log('[FAP Assistant] Content Script đã sẵn sàng kết nối!');

// Lắng nghe lệnh từ Side Panel
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'scrapeStudents') {
    const data = scrapeFapPage();
    sendResponse(data);
  } else if (request.action === 'applyAttendance') {
    const result = applyAttendanceToFap(request.records);
    sendResponse(result);
  } else if (request.action === 'ping') {
    sendResponse({ status: 'ok', isFap: isFapPage() });
  }
  return true;
});

function isFapPage() {
  return window.location.hostname.includes('fap.fpt.edu.vn') || window.location.pathname.includes('test-mock-fap');
}

// Bóc tách dữ liệu từ bảng FAP
function scrapeFapPage() {
  const students = [];
  const rows = document.querySelectorAll('table tr');
  const rollRegex = /\b([A-Z]{2}\d{5,7})\b/i;

  rows.forEach((row, index) => {
    const text = row.innerText || '';
    const match = rollRegex.exec(text);

    if (match) {
      const rollNumber = match[1].toUpperCase();

      // Tìm tên sinh viên
      const cells = row.querySelectorAll('td');
      let name = '';
      if (cells.length >= 3) {
        for (let i = 0; i < cells.length; i++) {
          const cellText = cells[i].innerText.trim();
          if (cellText && !cellText.includes(rollNumber) && !/^\d+$/.test(cellText) && cellText.length > 2 && !cellText.toLowerCase().includes('present') && !cellText.toLowerCase().includes('absent')) {
            name = cellText;
            break;
          }
        }
      }

      // Trạng thái radio hiện tại
      let currentStatus = 'present';
      const radios = row.querySelectorAll('input[type="radio"]');
      radios.forEach(r => {
        if (r.checked) {
          const pText = (r.parentElement ? r.parentElement.innerText : '').toLowerCase();
          if (pText.includes('absent') || r.value === '0' || r.id.toLowerCase().includes('absent')) {
            currentStatus = 'absent';
          }
        }
      });

      students.push({
        rollNumber: rollNumber,
        fullName: name || `Sinh viên ${rollNumber}`,
        status: currentStatus
      });
    }
  });

  return {
    success: students.length > 0,
    students: students,
    count: students.length
  };
}

// Áp dụng điểm danh tự động lên trang FAP
function applyAttendanceToFap(records) {
  if (!records || !Array.isArray(records)) {
    return { success: false, message: 'Dữ liệu điểm danh không hợp lệ!' };
  }

  let filled = 0;
  let presentCount = 0;
  let absentCount = 0;

  const rows = document.querySelectorAll('table tr');

  records.forEach(item => {
    const roll = item.rollNumber.toUpperCase();
    const targetStatus = (item.status || 'present').toLowerCase();

    rows.forEach(row => {
      const text = row.innerText || '';
      if (text.toUpperCase().includes(roll)) {
        const radios = row.querySelectorAll('input[type="radio"]');
        radios.forEach(radio => {
          const parentText = (radio.parentElement ? radio.parentElement.innerText : '').toLowerCase();
          const radioVal = (radio.value || '').toLowerCase();
          const radioId = (radio.id || '').toLowerCase();

          const isPresent = targetStatus === 'present';
          const isAbsent = targetStatus === 'absent';

          if (isPresent && (parentText.includes('present') || radioVal.includes('present') || radioId.includes('present') || radioVal === '1' || parentText.includes('có mặt'))) {
            radio.checked = true;
            radio.dispatchEvent(new Event('change', { bubbles: true }));
            radio.dispatchEvent(new Event('click', { bubbles: true }));
            row.style.backgroundColor = '#d1fae5'; // Xanh lá
            presentCount++;
          } else if (isAbsent && (parentText.includes('absent') || radioVal.includes('absent') || radioId.includes('absent') || radioVal === '0' || parentText.includes('vắng'))) {
            radio.checked = true;
            radio.dispatchEvent(new Event('change', { bubbles: true }));
            radio.dispatchEvent(new Event('click', { bubbles: true }));
            row.style.backgroundColor = '#fee2e2'; // Đỏ nhạt
            absentCount++;
          }
        });

        if (item.note && item.note.trim() !== '') {
          const noteInput = row.querySelector('input[type="text"], textarea');
          if (noteInput) {
            noteInput.value = item.note;
            noteInput.dispatchEvent(new Event('input', { bubbles: true }));
          }
        }

        filled++;
      }
    });
  });

  showFloatingToast(filled, presentCount, absentCount);

  return {
    success: true,
    filled: filled,
    present: presentCount,
    absent: absentCount
  };
}

function showFloatingToast(total, present, absent) {
  const existing = document.getElementById('fap-assistant-toast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.id = 'fap-assistant-toast';
  toast.style.position = 'fixed';
  toast.style.top = '20px';
  toast.style.right = '20px';
  toast.style.backgroundColor = '#0f172a';
  toast.style.color = '#ffffff';
  toast.style.padding = '16px 20px';
  toast.style.borderRadius = '12px';
  toast.style.boxShadow = '0 10px 25px rgba(0,0,0,0.4)';
  toast.style.zIndex = '999999';
  toast.style.fontFamily = 'Segoe UI, sans-serif';
  toast.style.border = '2px solid #F36F21';
  toast.innerHTML = `
    <div style="font-weight:bold; font-size:15px; color:#F36F21; margin-bottom:4px;">⚡ FAP Assistant: Đã tự động điền!</div>
    <div style="font-size:13px;">Đã chọn <b>${total}</b> sinh viên (Có mặt: <b style="color:#34d399">${present}</b>, Vắng: <b style="color:#f87171">${absent}</b>)</div>
    <div style="font-size:11px; margin-top:6px; color:#94a3b8;">Vui lòng kiểm tra lại các dòng được tô màu và bấm Save trên FAP.</div>
  `;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 6000);
}
