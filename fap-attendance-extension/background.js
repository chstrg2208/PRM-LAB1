// background.js - Service worker for FAP Attendance Assistant

// Configure Side Panel behavior: open side panel upon clicking the extension icon
chrome.runtime.onInstalled.addListener(() => {
  console.log('[FAP Assistant] Extension installed/updated.');
  if (chrome.sidePanel && chrome.sidePanel.setPanelBehavior) {
    chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true })
      .catch((error) => console.error('[FAP Assistant] Error setting panel behavior:', error));
  }
});

// Listen for messages from side panel or content scripts if needed
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'ping') {
    sendResponse({ status: 'ok' });
  }
  return true;
});
