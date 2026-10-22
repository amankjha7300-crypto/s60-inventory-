// API Base URL (relative path since served by FastAPI backend)
const API_URL = '/api/v1';

// Resilient inline SVG trash icon that never collapses or fails even when webfonts/CDN are unavailable
const TRASH_ICON_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 448 512" fill="currentColor" style="display:inline-block; vertical-align:middle; pointer-events:none;"><path d="M135.2 17.7C140.6 6.8 151.7 0 163.8 0H284.2c12.1 0 23.2 6.8 28.6 17.7L320 32h96c17.7 0 32 14.3 32 32s-14.3 32-32 32H32C14.3 96 0 81.7 0 64S14.3 32 32 32h96l7.2-14.3zM32 128H416V448c0 35.3-28.7 64-64 64H96c-35.3 0-64-28.7-64-64V128zm96 64c-8.8 0-16 7.2-16 16V432c0 8.8 7.2 16 16 16s16-7.2 16-16V208c0-8.8-7.2-16-16-16zm96 0c-8.8 0-16 7.2-16 16V432c0 8.8 7.2 16 16 16s16-7.2 16-16V208c0-8.8-7.2-16-16-16zm96 0c-8.8 0-16 7.2-16 16V432c0 8.8 7.2 16 16 16s16-7.2 16-16V208c0-8.8-7.2-16-16-16z"/></svg>`;

let authToken = localStorage.getItem('s60_token') || null;
let currentAdmin = JSON.parse(localStorage.getItem('s60_admin') || 'null');
let currentSession = null;
let activeEventId = null;
let currentProfileStudentId = null;
let cachedMasterInventoryItems = [];
let targetDistributionItemId = null;
let targetDistributionItemName = null;

// Initialization
document.addEventListener('DOMContentLoaded', () => {
  if (authToken && currentAdmin) {
    showAppShell();
  } else {
    showSplash();
  }
});

function showToast(message, type = 'success') {
  const toast = document.getElementById('toast');
  toast.className = `toast-msg ${type}`;
  toast.innerHTML = `<i class="fa-solid ${type === 'success' ? 'fa-circle-check' : 'fa-circle-exclamation'}"></i> ${message}`;
  toast.style.display = 'flex';
  setTimeout(() => {
    toast.style.display = 'none';
  }, 3500);
}

function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function showSplash() {
  document.getElementById('splashView').style.display = 'flex';
  document.getElementById('appShell').style.display = 'none';
}

function switchAuthTab(tab) {
  const tabSignIn = document.getElementById('authTabSignIn');
  const tabSignUp = document.getElementById('authTabSignUp');
  const tabReset = document.getElementById('authTabReset');
  const panelSignIn = document.getElementById('authPanelSignIn');
  const panelSignUp = document.getElementById('authPanelSignUp');
  const panelReset = document.getElementById('authPanelReset');

  // Reset all tabs
  [tabSignIn, tabSignUp, tabReset].forEach(t => {
    if (t) {
      t.style.background = 'transparent';
      t.style.color = 'var(--text-gray)';
      t.style.boxShadow = 'none';
    }
  });
  if (panelSignIn) panelSignIn.style.display = 'none';
  if (panelSignUp) panelSignUp.style.display = 'none';
  if (panelReset) panelReset.style.display = 'none';

  if (tab === 'signin') {
    if (tabSignIn) {
      tabSignIn.style.background = 'var(--white)';
      tabSignIn.style.color = 'var(--primary-navy)';
      tabSignIn.style.boxShadow = '0 2px 6px rgba(0,0,0,0.06)';
    }
    if (panelSignIn) panelSignIn.style.display = 'block';
  } else if (tab === 'signup') {
    if (tabSignUp) {
      tabSignUp.style.background = 'var(--white)';
      tabSignUp.style.color = 'var(--primary-navy)';
      tabSignUp.style.boxShadow = '0 2px 6px rgba(0,0,0,0.06)';
    }
    if (panelSignUp) panelSignUp.style.display = 'block';
  } else if (tab === 'reset') {
    if (tabReset) {
      tabReset.style.background = 'var(--white)';
      tabReset.style.color = 'var(--primary-navy)';
      tabReset.style.boxShadow = '0 2px 6px rgba(0,0,0,0.06)';
    }
    if (panelReset) panelReset.style.display = 'block';
  }
}

function showLogin(tab = 'signin') {
  switchAuthTab(tab);
  document.getElementById('loginModal').classList.add('active');
}

function closeModal(modalId) {
  document.getElementById(modalId).classList.remove('active');
}

async function handleLogin(e) {
  e.preventDefault();
  const email = document.getElementById('loginEmail').value.trim();
  const password = document.getElementById('loginPassword').value.trim();

  try {
    const res = await fetch(`${API_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      authToken = data.data.access_token;
      currentAdmin = data.data.admin;
      localStorage.setItem('s60_token', authToken);
      localStorage.setItem('s60_admin', JSON.stringify(currentAdmin));
      closeModal('loginModal');
      showAppShell();
      showToast(`Welcome back, ${currentAdmin.full_name}!`);
    } else {
      showToast(data.detail || data.message || 'Login failed', 'error');
    }
  } catch (err) {
    showToast('Failed to connect to backend API', 'error');
  }
}

async function handleSignUp(e) {
  e.preventDefault();
  const full_name = document.getElementById('signupFullName').value.trim();
  const email = document.getElementById('signupEmail').value.trim();
  const username = document.getElementById('signupUsername').value.trim();
  const role = document.getElementById('signupRole').value;
  const password = document.getElementById('signupPassword').value.trim();
  const confirmPassword = document.getElementById('signupConfirmPassword').value.trim();

  if (password !== confirmPassword) {
    showToast('Passwords do not match. Please verify.', 'error');
    return;
  }
  if (password.length < 6) {
    showToast('Password must be at least 6 characters.', 'error');
    return;
  }

  try {
    const res = await fetch(`${API_URL}/auth/signup`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        full_name,
        email,
        username: username || undefined,
        role,
        password
      })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      authToken = data.data.access_token;
      currentAdmin = data.data.admin;
      localStorage.setItem('s60_token', authToken);
      localStorage.setItem('s60_admin', JSON.stringify(currentAdmin));
      closeModal('loginModal');
      showAppShell();
      showToast(data.message || `Welcome to Super60, ${currentAdmin.full_name}!`);
    } else {
      showToast(data.detail || data.message || 'Registration failed', 'error');
    }
  } catch (err) {
    showToast('Failed to connect to backend API', 'error');
  }
}

async function handleResetPassword(e) {
  e.preventDefault();
  const email = document.getElementById('resetEmail').value.trim();
  const new_password = document.getElementById('resetNewPassword').value.trim();
  const confirm_password = document.getElementById('resetConfirmPassword').value.trim();

  if (new_password !== confirm_password) {
    showToast('Passwords do not match. Please verify.', 'error');
    return;
  }
  if (new_password.length < 6) {
    showToast('Password must be at least 6 characters.', 'error');
    return;
  }

  try {
    const res = await fetch(`${API_URL}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, new_password })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      authToken = data.data.access_token;
      currentAdmin = data.data.admin;
      localStorage.setItem('s60_token', authToken);
      localStorage.setItem('s60_admin', JSON.stringify(currentAdmin));
      closeModal('loginModal');
      showAppShell();
      showToast(data.message || `Password reset successfully! Welcome, ${currentAdmin.full_name}!`);
    } else {
      showToast(data.detail || data.message || 'Password reset failed', 'error');
    }
  } catch (err) {
    showToast('Failed to connect to backend API', 'error');
  }
}

function handleLogout() {
  authToken = null;
  currentAdmin = null;
  localStorage.removeItem('s60_token');
  localStorage.removeItem('s60_admin');
  showSplash();
}

function showAppShell() {
  document.getElementById('splashView').style.display = 'none';
  document.getElementById('appShell').style.display = 'flex';
  if (currentAdmin) {
    document.getElementById('dashWelcome').textContent = `Good morning, ${currentAdmin.full_name || 'Admin'}`;
    const nameEl = document.getElementById('headerUserName');
    if (nameEl) nameEl.textContent = currentAdmin.full_name || currentAdmin.username || 'Admin';
    const roleEl = document.getElementById('headerUserRole');
    if (roleEl) {
      const r = (currentAdmin.role || 'COORDINATOR').toUpperCase();
      if (r === 'SUPER_ADMIN') roleEl.textContent = 'SUPER ADMIN';
      else if (r === 'HOD' || r === 'HEAD_OF_DEPARTMENT') roleEl.textContent = 'HEAD OF DEPARTMENT';
      else roleEl.textContent = 'INVENTORY COORDINATOR';
    }
  }
  loadDashboard();
}

// ---------------- PHOTO UPLOAD & OPTIMIZATION HELPERS ----------------
function handlePhotoSelect(event, previewId, dataInputId, removeBtnId) {
  const file = event.target.files && event.target.files[0];
  if (!file) return;

  if (!file.type.startsWith('image/')) {
    showToast('Please select a valid image file (PNG, JPG, WebP)', 'error');
    return;
  }

  const reader = new FileReader();
  reader.onload = function (e) {
    const img = new Image();
    img.onload = function () {
      // Optimize & scale down via canvas so DB/memory remains lightweight
      const canvas = document.createElement('canvas');
      const maxDim = 600;
      let width = img.width;
      let height = img.height;
      if (width > height && width > maxDim) {
        height = Math.round((height * maxDim) / width);
        width = maxDim;
      } else if (height > maxDim) {
        width = Math.round((width * maxDim) / height);
        height = maxDim;
      }
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, width, height);

      const compressedDataUrl = canvas.toDataURL('image/jpeg', 0.82);
      document.getElementById(dataInputId).value = compressedDataUrl;

      const previewBox = document.getElementById(previewId);
      if (previewBox) {
        previewBox.innerHTML = `<img src="${compressedDataUrl}" style="width: 100%; height: 100%; object-fit: cover;">`;
      }
      const removeBtn = document.getElementById(removeBtnId);
      if (removeBtn) removeBtn.style.display = 'inline-block';
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
}

function removePhoto(previewId, dataInputId, removeBtnId) {
  const dataInput = document.getElementById(dataInputId);
  if (dataInput) dataInput.value = '';
  const previewBox = document.getElementById(previewId);
  if (previewBox) {
    previewBox.innerHTML = `<i class="fa-solid fa-image" style="color: var(--text-gray); font-size: 20px;"></i>`;
  }
  const removeBtn = document.getElementById(removeBtnId);
  if (removeBtn) removeBtn.style.display = 'none';
}

function authHeaders() {
  return {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`
  };
}

const savedEventsMap = new Map();

function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function escapeJs(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '');
}

let currentActiveTab = 'dashboard';

function switchTab(tabName) {
  currentActiveTab = tabName;
  document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
  document.querySelectorAll('.nav-tab').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.mobile-nav-item').forEach(el => el.classList.remove('active'));

  const activeContent = document.getElementById(`tab-${tabName}`);
  if (activeContent) activeContent.style.display = 'block';

  // Desktop tab button
  const tabBtns = Array.from(document.querySelectorAll('.nav-tab'));
  const targetBtn = tabBtns.find(b => {
    if (tabName === 'inventory' && (b.id === 'navTab-inventory' || b.classList.contains('nav-tab-master'))) return true;
    return b.textContent.toLowerCase().includes(tabName);
  });
  if (targetBtn) targetBtn.classList.add('active');

  // Mobile bottom nav button
  const activeMBtn = document.getElementById(`mNav-${tabName}`);
  if (activeMBtn) activeMBtn.classList.add('active');

  // Scroll to top smoothly
  window.scrollTo({ top: 0, behavior: 'smooth' });

  if (tabName === 'dashboard') loadDashboard();
  if (tabName === 'events') loadSavedEvents();
  if (tabName === 'distribution') loadDistributionEventsDropdown();
  if (tabName === 'inventory') loadMasterInventory();
  if (tabName === 'students') loadStudentsList();
  if (tabName === 'reports') loadReportsData();
}

// ---------------- LIVE MULTI-USER CLOUD SYNC ----------------
let isAutoSyncing = false;

async function autoSyncActiveView(isManual = false) {
  if (isAutoSyncing || !authToken) return;

  // If user is actively typing in an input or textarea, skip this cycle to avoid interrupting them
  const activeEl = document.activeElement;
  if (!isManual && activeEl && (activeEl.tagName === 'INPUT' || activeEl.tagName === 'TEXTAREA')) {
    return;
  }

  isAutoSyncing = true;
  try {
    if (currentActiveTab === 'dashboard') {
      await loadDashboard();
    } else if (currentActiveTab === 'events') {
      await loadSavedEvents();
    } else if (currentActiveTab === 'distribution') {
      if (activeEventId) await loadDistributionMatrix();
    } else if (currentActiveTab === 'inventory') {
      await loadMasterInventory();
    } else if (currentActiveTab === 'students') {
      await loadStudentsList();
    }
    if (isManual) {
      showToast('✓ Cloud data synchronized');
    }
  } catch (err) {
    console.debug('[Cloud Sync] Background poll notice:', err);
  } finally {
    isAutoSyncing = false;
  }
}

// Background auto-sync every 6 seconds so changes made on other laptops appear automatically
setInterval(() => {
  autoSyncActiveView(false);
}, 6000);

// Auto-sync immediately whenever the user switches focus to this window / application
window.addEventListener('focus', () => {
  autoSyncActiveView(false);
});

// ---------------- DASHBOARD ----------------
async function loadDashboard() {
  try {
    const res = await fetch(`${API_URL}/dashboard?_t=${Date.now()}`, {
      headers: authHeaders(),
      cache: 'no-store'
    });
    if (res.status === 401) return handleLogout();
    const result = await res.json();
    const d = result.data;

    document.getElementById('sessionBadge').innerHTML = `<i class="fa-solid fa-circle-check" style="color: var(--primary-orange); margin-right: 5px;"></i> ${d.academic_session_name} • ${d.current_scheme}`;
    document.getElementById('dashStudents').textContent = d.active_students_count;
    document.getElementById('dashEvents').textContent = d.total_events_count;
    document.getElementById('dashActiveEvents').textContent = `${d.active_events_count} active/ongoing events`;
    document.getElementById('dashDistributed').textContent = d.total_distributed_units;
    document.getElementById('dashPending').textContent = `${d.total_pending_units} pending units`;
    document.getElementById('dashInventory').textContent = `${d.total_inventory_units}+`;

    // Low stock alerts
    const lowStockSection = document.getElementById('lowStockSection');
    const lowStockList = document.getElementById('lowStockList');
    if (d.low_stock_alerts && d.low_stock_alerts.length > 0) {
      lowStockSection.style.display = 'block';
      lowStockList.innerHTML = d.low_stock_alerts.map(a => `
        <div style="background: rgba(245, 158, 11, 0.08); border: 1px solid rgba(245, 158, 11, 0.3); padding: 12px 16px; border-radius: 12px; display: flex; align-items: center; gap: 10px;">
          <i class="fa-solid fa-triangle-exclamation" style="color: var(--status-orange);"></i>
          <div style="font-size: 12px; color: var(--primary-navy);">
            <strong>${a.item_name}</strong> in <em>${a.event_name}</em>: <strong>${a.remaining} units</strong> left (${a.status})
          </div>
        </div>
      `).join('');
    } else {
      lowStockSection.style.display = 'none';
    }

    // Recent events list
    const recentCont = document.getElementById('dashRecentEvents');
    recentCont.innerHTML = d.recent_events.map(ev => `
      <div style="border: 1px solid var(--border-subtle); padding: 16px; border-radius: 14px; display: flex; justify-content: space-between; align-items: center; cursor: pointer;" onclick="openEventDetails(${ev.id})">
        <div style="flex: 1;">
          <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
            <span class="badge badge-active">${ev.event_uid}</span>
            <span class="badge ${ev.status === 'Active' ? 'badge-active' : (ev.status === 'Completed' ? 'badge-completed' : 'badge-upcoming')}">${ev.status}</span>
          </div>
          <h4 style="font-size: 15px; margin-bottom: 4px;">${ev.name}</h4>
          <p style="font-size: 12px; color: var(--text-gray);">${ev.event_date} • ${ev.event_type} • ${ev.distributed_quantity} / ${ev.total_quantity} items distributed</p>
          <div class="progress-bar-bg" style="margin-top: 8px; max-width: 320px;">
            <div class="progress-bar-fill" style="width: ${ev.distribution_percentage}%;"></div>
          </div>
        </div>
        <button class="btn-secondary" style="padding: 6px 14px; font-size: 12px;">View <i class="fa-solid fa-arrow-right"></i></button>
      </div>
    `).join('');

  } catch (err) {
    console.error('Failed to load dashboard:', err);
  }
}

// ---------------- SAVED EVENTS (CRITICAL SECTION) ----------------
async function loadSavedEvents() {
  const search = document.getElementById('eventSearchInput').value.trim();
  const status = document.getElementById('eventStatusFilter').value;
  const scheme = document.getElementById('eventSchemeFilter').value;
  const semester = document.getElementById('eventSemesterFilter').value;

  const params = new URLSearchParams();
  if (search) params.append('search', search);
  if (status !== 'ALL') params.append('status', status);
  if (scheme !== 'ALL') params.append('scheme', scheme);
  if (semester) params.append('semester', semester);

  try {
    const res = await fetch(`${API_URL}/events?${params.toString()}`, { headers: authHeaders() });
    const result = await res.json();
    const items = result.data.items || [];

    const container = document.getElementById('savedEventsContainer');
    if (items.length === 0) {
      container.innerHTML = `
        <div class="card" style="grid-column: 1 / -1; text-align: center; padding: 48px 24px;">
          <div style="width: 56px; height: 56px; border-radius: 16px; background: rgba(244, 123, 32, 0.12); display: inline-flex; align-items: center; justify-content: center; margin-bottom: 16px;">
            <i class="fa-solid fa-calendar-plus" style="font-size: 28px; color: var(--primary-orange);"></i>
          </div>
          <h3 style="font-size: 18px; margin-bottom: 8px; color: var(--primary-navy);">No Saved Events Yet</h3>
          <p style="font-size: 13px; color: var(--text-gray); max-width: 480px; margin: 0 auto 20px;">
            The event history is clean with zero predefined records. Click below to create your first Super60 event.
          </p>
          <button class="btn-primary" onclick="openCreateEventModal()" style="display: inline-flex;">
            <i class="fa-solid fa-plus"></i> Create New Event
          </button>
        </div>
      `;
      return;
    }

    savedEventsMap.clear();
    items.forEach(ev => savedEventsMap.set(ev.id, ev));

    container.innerHTML = items.map(ev => `
      <div class="card" style="display: flex; flex-direction: column; justify-content: space-between;">
        <div>
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
            <span class="badge badge-active">${ev.event_uid}</span>
            <span class="badge ${ev.status === 'Active' ? 'badge-active' : (ev.status === 'Completed' ? 'badge-completed' : 'badge-upcoming')}">${ev.status}</span>
          </div>
          <h3 style="font-size: 16px; margin-bottom: 6px;">${escapeHtml(ev.name)}</h3>
          <p style="font-size: 12px; color: var(--text-gray); margin-bottom: 12px;">
            <i class="fa-solid fa-calendar"></i> ${ev.event_date} &nbsp;•&nbsp; 
            <i class="fa-solid fa-layer-group"></i> ${ev.semester_scheme} Sem (${ev.applicable_semesters.map(s => s + 'th').join(', ')})${ev.custom_audience ? ` &nbsp;•&nbsp; <i class="fa-solid fa-user-tag" style="color: var(--primary-orange);"></i> ${escapeHtml(ev.custom_audience)}` : ''}
          </p>
          ${ev.image_url ? `
            <div style="display: flex; justify-content: flex-end; margin-bottom: 6px;">
              <button type="button" class="btn-sm" onclick="viewEventPhotoById(${ev.id})" style="border: 1px solid rgba(244, 123, 32, 0.35); background: rgba(244, 123, 32, 0.12); color: var(--primary-orange); padding: 3px 10px; border-radius: 6px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 5px; font-size: 11px; transition: all 0.2s ease;" title="Click to view full event photo">
                <i class="fa-solid fa-camera"></i> View Photo
              </button>
            </div>
          ` : ''}
          <div style="font-size: 12px; color: var(--primary-navy); font-weight: 600; display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
            <span>${ev.total_inventory_items} Item Types</span>
            <span>${ev.distributed_quantity} / ${ev.total_quantity} Distributed</span>
          </div>
          <div class="progress-bar-bg" style="margin-bottom: 14px;">
            <div class="progress-bar-fill" style="width: ${ev.distribution_percentage}%;"></div>
          </div>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border-subtle); padding-top: 12px; gap: 8px;">
          <span style="font-size: 12px; font-weight: 700; color: var(--primary-orange);">${ev.distribution_percentage}% Complete</span>
          <div style="display: flex; gap: 6px; align-items: center;">
            ${ev.status !== 'Completed' ? `
              <button class="btn-primary" onclick="quickCompleteEvent(${ev.id}, '${escapeJs(ev.name)}')" style="padding: 6px 10px; font-size: 12px; background: #059669; border-color: #059669;" title="Mark Event as Completed">
                <i class="fa-solid fa-circle-check"></i> Complete
              </button>
            ` : `
              <span class="badge badge-completed" style="font-size: 11px; padding: 4px 8px;"><i class="fa-solid fa-check"></i> Done</span>
            `}
            <button class="btn-secondary" onclick="openEventDetails(${ev.id})" style="padding: 6px 12px; font-size: 12px;">
              View <i class="fa-solid fa-arrow-right"></i>
            </button>
            <button class="btn-danger" onclick="confirmDeleteEvent(${ev.id}, '${escapeJs(ev.name)}', '${ev.event_uid}')" style="padding: 6px 10px; font-size: 12px; min-width: 32px; min-height: 32px; display: inline-flex; align-items: center; justify-content: center;" title="Delete Event">
              ${TRASH_ICON_SVG}
            </button>
          </div>
        </div>
      </div>
    `).join('');

  } catch (err) {
    console.error('Failed to load events:', err);
  }
}

// ---------------- EVENT DETAILS MODAL ----------------
let activeEventName = '';
let activeEventUid = '';

async function openEventDetails(eventId) {
  activeEventId = eventId;
  try {
    const res = await fetch(`${API_URL}/events/${eventId}`, { headers: authHeaders() });
    const result = await res.json();
    const ev = result.data;
    activeEventName = ev.name;
    activeEventUid = ev.event_uid;

    document.getElementById('evtDetUid').textContent = ev.event_uid;
    document.getElementById('evtDetName').textContent = ev.name;
    document.getElementById('evtDetDesc').textContent = ev.description || 'No description provided.';
    document.getElementById('evtDetDate').textContent = `${ev.event_date} (${ev.event_time || 'All Day'})`;
    document.getElementById('evtDetVenue').textContent = ev.venue || 'SVIET Campus';
    let semText = `${ev.semester_scheme} Scheme (${ev.applicable_semesters.map(s => s + 'th').join(', ')})`;
    if (ev.custom_audience) {
      semText += ` • Guest: ${ev.custom_audience}`;
    }
    document.getElementById('evtDetSemesters').textContent = semText;

    const photoBtnContainer = document.getElementById('evtDetPhotoBtnContainer');
    if (photoBtnContainer) {
      if (ev.image_url) {
        photoBtnContainer.style.display = 'inline-block';
        photoBtnContainer.innerHTML = `
          <button type="button" class="btn-sm" onclick="openEventPhotoModal('${escapeJs(ev.image_url)}', '${escapeJs(ev.name)}', '${escapeJs(ev.event_uid)}', '${escapeJs(ev.event_date)}')" style="border: 1px solid rgba(244,123,32,0.3); background: rgba(244,123,32,0.12); color: var(--primary-orange); padding: 3px 8px; border-radius: 6px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 4px; font-size: 11px;">
            <i class="fa-solid fa-camera"></i> View Event Photo
          </button>
        `;
      } else {
        photoBtnContainer.style.display = 'none';
        photoBtnContainer.innerHTML = '';
      }
    }

    const invTable = document.getElementById('evtDetInventoryTable');
    if (ev.inventories && ev.inventories.length > 0) {
      invTable.innerHTML = `
        <table style="width: 100%; border-collapse: collapse; font-size: 12px; text-align: left;">
          <thead style="background: var(--surface-gray); color: var(--primary-navy);">
            <tr>
              <th style="padding: 10px;">Item</th>
              <th style="padding: 10px;">Category</th>
              <th style="padding: 10px;">Initial</th>
              <th style="padding: 10px;">Distributed</th>
              <th style="padding: 10px;">Remaining</th>
              <th style="padding: 10px;">Status</th>
            </tr>
          </thead>
          <tbody>
            ${ev.inventories.map(i => `
              <tr style="border-bottom: 1px solid var(--border-subtle);">
                <td style="padding: 10px; font-weight: 600;">${i.item_name}</td>
                <td style="padding: 10px;">${i.category}</td>
                <td style="padding: 10px;">${i.initial_quantity}</td>
                <td style="padding: 10px; color: var(--status-green); font-weight: bold;">${i.distributed_quantity}</td>
                <td style="padding: 10px; font-weight: bold; color: var(--primary-navy);">${i.remaining_quantity}</td>
                <td style="padding: 10px;"><span class="badge ${i.status === 'Available' ? 'badge-completed' : (i.status === 'Low Stock' ? 'badge-low' : 'badge-out')}">${i.status}</span></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `;
    } else {
      invTable.innerHTML = `<p style="font-size: 12px; color: var(--text-gray); font-style: italic;">No inventory items allocated yet.</p>`;
    }

    const completeBtnBox = document.getElementById('evtDetCompleteBtnContainer');
    if (completeBtnBox) {
      if (ev.status !== 'Completed') {
        completeBtnBox.innerHTML = `
          <button class="btn-primary" onclick="quickCompleteEvent(${ev.id}, '${escapeHtml(ev.name)}', true)" style="background: #059669; border-color: #059669;">
            <i class="fa-solid fa-circle-check"></i> Complete Event
          </button>
        `;
      } else {
        completeBtnBox.innerHTML = `
          <button class="btn-secondary" onclick="quickReopenEvent(${ev.id}, '${escapeHtml(ev.name)}', true)">
            <i class="fa-solid fa-rotate-left"></i> Reopen Event
          </button>
        `;
      }
    }

    document.getElementById('eventDetailModal').classList.add('active');
  } catch (err) {
    showToast('Failed to load event details', 'error');
  }
}

function goToEventDistribution() {
  closeModal('eventDetailModal');
  targetDistributionItemId = null;
  targetDistributionItemName = null;
  switchTab('distribution');
}

async function archiveCurrentEvent() {
  if (!confirm('Are you sure you want to archive this event? Historical records will remain intact.')) return;
  try {
    const res = await fetch(`${API_URL}/events/${activeEventId}/archive`, {
      method: 'POST',
      headers: authHeaders()
    });
    if (res.ok) {
      showToast('Event archived successfully.');
      closeModal('eventDetailModal');
      loadSavedEvents();
    }
  } catch (err) {
    showToast('Failed to archive event', 'error');
  }
}

async function deleteCurrentEvent() {
  if (!activeEventId) return;
  await confirmDeleteEvent(activeEventId, activeEventName, activeEventUid);
}

async function confirmDeleteEvent(eventId, eventName, eventUid) {
  if (!confirm(`Are you sure you want to delete event "${eventName}" (${eventUid})?\n\nThis will permanently delete the event and its item records.`)) {
    return;
  }
  try {
    const res = await fetch(`${API_URL}/events/${eventId}?force=true`, {
      method: 'DELETE',
      headers: authHeaders()
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(data.message || `Event '${eventName}' deleted successfully.`);
      closeModal('eventDetailModal');
      loadSavedEvents();
      loadDashboard();
      loadDistributionEventsDropdown();
      cachedMasterInventoryItems = [];
      loadMasterInventory();
    } else {
      showToast(data.detail || data.message || 'Failed to delete event', 'error');
    }
  } catch (err) {
    showToast('Failed to delete event', 'error');
  }
}

// ---------------- CREATE EVENT ----------------
function openCreateEventModal() {
  const form = document.getElementById('createEventForm');
  if (form) form.reset();
  removeEventPhoto();
  const guestBox = document.getElementById('evCustomAudienceContainer');
  if (guestBox) guestBox.style.display = 'none';
  const guestTxt = document.getElementById('evCustomAudienceText');
  if (guestTxt) guestTxt.value = '';
  const dateInp = document.getElementById('evDate');
  if (dateInp && !dateInp.value) dateInp.value = '15 Oct 2026';
  const timeInp = document.getElementById('evTime');
  if (timeInp && !timeInp.value) timeInp.value = '10:00 AM';
  const venueInp = document.getElementById('evVenue');
  if (venueInp && !venueInp.value) venueInp.value = 'SVIET Campus Lab';

  updateEventModalSemesters();
  document.getElementById('createEventModal').classList.add('active');
}

function updateEventModalSemesters() {
  const scheme = document.getElementById('evScheme').value;
  const container = document.getElementById('evSemestersCheckboxes');
  const wasGuestChecked = !!document.getElementById('evCustomAudienceCheckbox')?.checked;
  if (scheme === 'ODD') {
    container.innerHTML = `
      <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; cursor: pointer; color: var(--primary-navy);">
        <input type="checkbox" name="evSem" value="3" checked> 3rd Semester (Odd)
      </label>
      <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; cursor: pointer; color: var(--primary-navy);">
        <input type="checkbox" name="evSem" value="5" checked> 5th Semester (Odd)
      </label>
      <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; cursor: pointer; color: var(--primary-navy);">
        <input type="checkbox" name="evSem" value="7" checked> 7th Semester (Odd)
      </label>
      <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 700; cursor: pointer; color: var(--primary-orange);">
        <input type="checkbox" id="evCustomAudienceCheckbox" onchange="toggleCustomAudienceInput()" ${wasGuestChecked ? 'checked' : ''}> Custom Guest (Non-S60)
      </label>
    `;
  } else {
    container.innerHTML = `
      <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; cursor: pointer; color: var(--primary-navy);">
        <input type="checkbox" name="evSem" value="4" checked> 4th Semester (Even)
      </label>
      <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; cursor: pointer; color: var(--primary-navy);">
        <input type="checkbox" name="evSem" value="6" checked> 6th Semester (Even)
      </label>
      <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; cursor: pointer; color: var(--primary-navy);">
        <input type="checkbox" name="evSem" value="8" checked> 8th Semester (Even)
      </label>
      <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 700; cursor: pointer; color: var(--primary-orange);">
        <input type="checkbox" id="evCustomAudienceCheckbox" onchange="toggleCustomAudienceInput()" ${wasGuestChecked ? 'checked' : ''}> Custom Guest (Non-S60)
      </label>
    `;
  }
}

function toggleCustomAudienceInput() {
  const cb = document.getElementById('evCustomAudienceCheckbox');
  const box = document.getElementById('evCustomAudienceContainer');
  if (cb && box) {
    box.style.display = cb.checked ? 'block' : 'none';
    if (cb.checked) {
      const txt = document.getElementById('evCustomAudienceText');
      if (txt) txt.focus();
    }
  }
}

function handleEventPhotoSelect(event) {
  const file = event.target.files && event.target.files[0];
  if (!file) return;

  if (!file.type.startsWith('image/')) {
    showToast('Please select a valid image file (PNG, JPG, WebP)', 'error');
    return;
  }

  const reader = new FileReader();
  reader.onload = function(e) {
    const img = new Image();
    img.onload = function() {
      // Resize down via canvas to keep Base64 payload lightweight and crisp
      const canvas = document.createElement('canvas');
      const maxDim = 1200;
      let width = img.width;
      let height = img.height;
      if (width > height && width > maxDim) {
        height = Math.round((height * maxDim) / width);
        width = maxDim;
      } else if (height > maxDim) {
        width = Math.round((width * maxDim) / height);
        height = maxDim;
      }
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, width, height);

      const base64Data = canvas.toDataURL('image/jpeg', 0.85);
      const urlInput = document.getElementById('evPhotoUrl');
      if (urlInput) urlInput.value = base64Data;

      const previewBox = document.getElementById('evPhotoPreviewBox');
      const previewImg = document.getElementById('evPhotoPreviewImg');
      const uploadBtn = document.getElementById('evPhotoUploadBtn');
      const statusSpan = document.getElementById('evPhotoUploadStatus');

      if (previewImg) previewImg.src = base64Data;
      if (previewBox) previewBox.style.display = 'flex';
      if (uploadBtn) uploadBtn.innerHTML = '<i class="fa-solid fa-check"></i> Change Photo';
      if (statusSpan) statusSpan.textContent = `${file.name} ready (Base64 encoded)`;
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
}

function removeEventPhoto() {
  const fileInp = document.getElementById('evPhotoInput');
  if (fileInp) fileInp.value = '';
  const urlInput = document.getElementById('evPhotoUrl');
  if (urlInput) urlInput.value = '';
  const previewBox = document.getElementById('evPhotoPreviewBox');
  if (previewBox) previewBox.style.display = 'none';
  const previewImg = document.getElementById('evPhotoPreviewImg');
  if (previewImg) previewImg.src = '';
  const uploadBtn = document.getElementById('evPhotoUploadBtn');
  if (uploadBtn) uploadBtn.innerHTML = '<i class="fa-solid fa-camera"></i> Upload Photo';
  const statusSpan = document.getElementById('evPhotoUploadStatus');
  if (statusSpan) statusSpan.textContent = 'Banner, certificate sample, or venue photo';
}

function openEventPhotoPreviewModal() {
  const urlInput = document.getElementById('evPhotoUrl');
  if (urlInput && urlInput.value) {
    const name = document.getElementById('evName')?.value?.trim() || 'New Event';
    openEventPhotoModal(urlInput.value, name, 'Draft Preview', 'Photo Preview');
  }
}

function viewEventPhotoById(eventId) {
  const ev = savedEventsMap.get(eventId);
  if (!ev) return;
  openEventPhotoModal(ev.image_url, ev.name, ev.event_uid, ev.event_date);
}

function openEventPhotoModal(photoUrl, eventName, eventUid, eventDate) {
  const modal = document.getElementById('eventPhotoModal');
  const title = document.getElementById('evPhotoModalTitle');
  const subtitle = document.getElementById('evPhotoModalSubtitle');
  const img = document.getElementById('evPhotoModalImg');
  const downloadBtn = document.getElementById('evPhotoModalDownloadBtn');
  const body = document.getElementById('evPhotoModalBody');

  if (title) title.textContent = eventName || 'Event Photo';
  if (subtitle) subtitle.textContent = `${eventUid || ''} • ${eventDate || ''}`;

  if (photoUrl && photoUrl.trim()) {
    if (img) {
      img.src = photoUrl;
      img.style.display = 'block';
    }
    if (downloadBtn) {
      downloadBtn.href = photoUrl;
      downloadBtn.download = `${(eventUid || 'event')}_photo.jpg`;
      downloadBtn.style.display = 'inline-flex';
    }
    if (body) {
      const emptyMsg = body.querySelector('.empty-photo-msg');
      if (emptyMsg) emptyMsg.remove();
    }
  } else {
    if (img) img.style.display = 'none';
    if (downloadBtn) downloadBtn.style.display = 'none';
    if (body) {
      let emptyMsg = body.querySelector('.empty-photo-msg');
      if (!emptyMsg) {
        emptyMsg = document.createElement('div');
        emptyMsg.className = 'empty-photo-msg';
        emptyMsg.style.textAlign = 'center';
        emptyMsg.style.padding = '40px 20px';
        body.appendChild(emptyMsg);
      }
      emptyMsg.innerHTML = `
        <div style="width: 60px; height: 60px; border-radius: 50%; background: rgba(15, 43, 91, 0.08); display: inline-flex; align-items: center; justify-content: center; margin-bottom: 14px;">
          <i class="fa-regular fa-image" style="font-size: 28px; color: var(--text-gray);"></i>
        </div>
        <h4 style="font-size: 16px; color: var(--primary-navy); margin-bottom: 6px;">No Photo Uploaded</h4>
        <p style="font-size: 13px; color: var(--text-gray); max-width: 340px; margin: 0 auto;">No photo was attached when creating this event.</p>
      `;
    }
  }

  if (modal) modal.classList.add('active');
}

let isSubmittingEvent = false;

async function handleCreateEvent(e) {
  e.preventDefault();
  if (isSubmittingEvent) return; // Prevent double submission!

  const name = document.getElementById('evName').value.trim();
  const type = document.getElementById('evType').value;
  const date = document.getElementById('evDate').value.trim();
  const time = document.getElementById('evTime').value.trim();
  const venue = document.getElementById('evVenue').value.trim();
  const scheme = document.getElementById('evScheme').value;
  const desc = document.getElementById('evDesc').value.trim();

  const checkedBoxes = Array.from(document.querySelectorAll('input[name="evSem"]:checked'));
  const isCustomGuest = !!document.getElementById('evCustomAudienceCheckbox')?.checked;
  const customGuestText = document.getElementById('evCustomAudienceText')?.value?.trim();

  if (checkedBoxes.length === 0 && !isCustomGuest) {
    showToast('Please select at least one semester or Custom Guest', 'error');
    return;
  }
  const semesters = checkedBoxes.map(cb => parseInt(cb.value));
  const customAudience = isCustomGuest ? (customGuestText || 'Custom Guest') : null;
  const imageUrl = document.getElementById('evPhotoUrl')?.value?.trim() || null;

  const submitBtn = e.target.querySelector('button[type="submit"]');
  isSubmittingEvent = true;
  if (submitBtn) {
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Saving Event...';
  }

  try {
    const res = await fetch(`${API_URL}/events`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        name,
        event_type: type,
        event_date: date,
        event_time: time,
        venue,
        semester_scheme: scheme,
        applicable_semesters: semesters,
        custom_audience: customAudience,
        image_url: imageUrl,
        description: desc,
        status: 'Upcoming'
      })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`Event '${data.data.name}' (${data.data.event_uid}) created!`);
      closeModal('createEventModal');
      removeEventPhoto();
      loadSavedEvents();
      loadDashboard();
      loadDistributionEventsDropdown();
    } else {
      showToast(data.detail || data.message || 'Creation failed', 'error');
    }
  } catch (err) {
    showToast(err.message || 'Failed to create event', 'error');
  } finally {
    isSubmittingEvent = false;
    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.innerHTML = 'Save Event Permanently';
    }
  }
}

// ---------------- EVENT ITEM ALLOCATION ----------------
async function openAddEventItemModal() {
  if (!activeEventId) {
    showToast('No active event selected', 'error');
    return;
  }
  // Reset photo upload inputs
  removePhoto('allocItemPhotoPreview', 'allocItemPhotoData', 'allocItemRemovePhotoBtn');
  const fileInp = document.getElementById('allocItemPhotoInput');
  if (fileInp) fileInp.value = '';

  try {
    const res = await fetch(`${API_URL}/inventory`, { headers: authHeaders() });
    const data = await res.json();
    const items = data.data || [];
    const select = document.getElementById('allocItemSelect');

    if (items.length === 0) {
      showToast('No catalog items found! Please add items in Master Inventory first.', 'error');
      closeModal('eventDetailModal');
      switchTab('inventory');
      setTimeout(() => openAddMasterItemModal(), 300);
      return;
    }

    select.innerHTML = items.map(i => `<option value="${i.id}">${i.name} (${i.category})</option>`).join('');

    // Pre-populate photo preview from catalog if available
    function updateSelectedCatalogPhoto() {
      const selectedId = parseInt(select.value);
      const selItem = items.find(i => i.id === selectedId);
      if (selItem && selItem.image_url) {
        document.getElementById('allocItemPhotoData').value = selItem.image_url;
        document.getElementById('allocItemPhotoPreview').innerHTML = `<img src="${selItem.image_url}" style="width: 100%; height: 100%; object-fit: cover;">`;
        document.getElementById('allocItemRemovePhotoBtn').style.display = 'inline-block';
      } else {
        removePhoto('allocItemPhotoPreview', 'allocItemPhotoData', 'allocItemRemovePhotoBtn');
      }
    }

    select.onchange = updateSelectedCatalogPhoto;
    updateSelectedCatalogPhoto();

    toggleWebAllocMode('catalog');
    document.getElementById('addEventItemModal').classList.add('active');
  } catch (err) {
    showToast('Failed to load inventory catalog', 'error');
  }
}

let currentWebAllocMode = 'catalog';
function toggleWebAllocMode(mode) {
  currentWebAllocMode = mode;
  const tabCat = document.getElementById('webAllocTabCatalog');
  const tabCust = document.getElementById('webAllocTabCustom');
  const groupCat = document.getElementById('webAllocCatalogGroup');
  const groupCust = document.getElementById('webAllocCustomGroup');

  if (mode === 'catalog') {
    tabCat.style.background = '#fff';
    tabCat.style.color = 'var(--primary-navy)';
    tabCat.style.fontWeight = 'bold';
    tabCust.style.background = 'transparent';
    tabCust.style.color = 'var(--text-gray)';
    tabCust.style.fontWeight = 'normal';
    groupCat.style.display = 'block';
    groupCust.style.display = 'none';
  } else {
    tabCust.style.background = '#fff';
    tabCust.style.color = 'var(--primary-orange)';
    tabCust.style.fontWeight = 'bold';
    tabCat.style.background = 'transparent';
    tabCat.style.color = 'var(--text-gray)';
    tabCat.style.fontWeight = 'normal';
    groupCat.style.display = 'none';
    groupCust.style.display = 'block';
  }
}

async function handleAllocateEventInventory(e) {
  e.preventDefault();
  if (!activeEventId) return;

  const initial_quantity = parseInt(document.getElementById('allocQty').value);
  const eligibility_type = document.getElementById('allocEligibility').value;
  const photoData = document.getElementById('allocItemPhotoData').value.trim() || null;
  let targetItemId = null;

  try {
    if (currentWebAllocMode === 'custom') {
      const name = document.getElementById('allocCustomName').value.trim();
      const category = document.getElementById('allocCustomCategory').value;
      const unit = document.getElementById('allocCustomUnit').value.trim() || 'units';

      if (!name) {
        showToast('Please enter custom item name', 'error');
        return;
      }

      // Create new inventory item in catalog with photo
      const createRes = await fetch(`${API_URL}/inventory`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({
          name,
          category,
          unit,
          description: 'Added via event allocation',
          created_source: 'EVENT',
          image_url: photoData
        })
      });
      const createData = await createRes.json();
      if (!createRes.ok || !createData.success) {
        showToast(createData.detail || createData.message || 'Failed to create custom item', 'error');
        return;
      }
      targetItemId = createData.data.id;
    } else {
      targetItemId = parseInt(document.getElementById('allocItemSelect').value);
      if (!targetItemId) {
        showToast('Please select a catalog item', 'error');
        return;
      }
    }

    const res = await fetch(`${API_URL}/events/${activeEventId}/inventory`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        inventory_item_id: targetItemId,
        initial_quantity,
        eligibility_type,
        image_url: photoData
      })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`Allocated ${initial_quantity} units of ${data.data.item_name} to event!`);
      closeModal('addEventItemModal');
      openEventDetails(activeEventId);
      loadSavedEvents();
      loadDashboard();
    } else {
      showToast(data.detail || data.message || 'Failed to allocate item', 'error');
    }
  } catch (err) {
    showToast('Failed to allocate item', 'error');
  }
}

// ---------------- REWARDS & DISTRIBUTION (CRITICAL WORKFLOW) ----------------
async function loadDistributionEventsDropdown(preferredEventId = null) {
  try {
    const res = await fetch(`${API_URL}/events?status=ALL`, { headers: authHeaders() });
    const data = await res.json();
    const events = data.data.items || [];
    const select = document.getElementById('distEventSelect');

    if (events.length === 0) {
      select.innerHTML = '<option value="">-- No events created yet --</option>';
      document.getElementById('distSummaryText').textContent = 'No events available';
      document.getElementById('distCompletionRate').textContent = '0% Complete';
      document.getElementById('distRowsContainer').innerHTML = `
        <div class="card" style="text-align: center; padding: 48px 24px;">
          <div style="width: 56px; height: 56px; border-radius: 16px; background: rgba(244, 123, 32, 0.12); display: inline-flex; align-items: center; justify-content: center; margin-bottom: 16px;">
            <i class="fa-solid fa-clipboard-check" style="font-size: 28px; color: var(--primary-orange);"></i>
          </div>
          <h3 style="font-size: 18px; margin-bottom: 8px; color: var(--primary-navy);">No Events for Distribution</h3>
          <p style="font-size: 13px; color: var(--text-gray); max-width: 480px; margin: 0 auto 20px;">
            Create an event and allocate rewards to start tracking distributions.
          </p>
          <button class="btn-primary" onclick="openCreateEventModal()" style="display: inline-flex;">
            <i class="fa-solid fa-plus"></i> Create New Event
          </button>
        </div>
      `;
      return;
    }

    if (preferredEventId && events.some(ev => ev.id == preferredEventId)) {
      activeEventId = preferredEventId;
    } else if (!activeEventId || !events.some(ev => ev.id == activeEventId)) {
      activeEventId = events[0].id;
    }

    select.innerHTML = events.map(ev => `
      <option value="${ev.id}" ${activeEventId == ev.id ? 'selected' : ''}>${ev.event_uid} • ${ev.name}</option>
    `).join('');
    select.value = activeEventId;

    await loadDistributionMatrix();
  } catch (err) {
    console.error('Failed to load events for distribution:', err);
  }
}

async function loadDistributionMatrix() {
  const select = document.getElementById('distEventSelect');
  if (!select) return;
  const eventId = select.value;
  if (!eventId) return;
  activeEventId = eventId;

  const search = document.getElementById('distStudentSearch').value.trim();
  const semester = document.getElementById('distSemesterFilter').value;
  const status = document.getElementById('distStatusFilter').value;
  const itemFilterSelect = document.getElementById('distItemFilter');

  const params = new URLSearchParams();
  if (search) params.append('search', search);
  if (semester) params.append('semester', semester);
  if (status !== 'ALL') params.append('status_filter', status);

  try {
    const res = await fetch(`${API_URL}/distribution/event/${eventId}/matrix?${params.toString()}`, { headers: authHeaders() });
    const result = await res.json();
    const d = result.data;
    const cols = d.inventory_columns || [];

    // Sync Item Filter dropdown options
    let selectedItemFilter = 'ALL';
    if (itemFilterSelect) {
      const prevFilterVal = itemFilterSelect.value;
      let optionsHtml = `<option value="ALL">All Event Rewards (${cols.length})</option>`;
      cols.forEach(col => {
        optionsHtml += `<option value="${col.id}" data-item-id="${col.inventory_item_id || ''}" data-name="${col.item_name}">${col.item_name} (${col.remaining_quantity} left)</option>`;
      });
      itemFilterSelect.innerHTML = optionsHtml;

      // Determine active filter
      if (targetDistributionItemId) {
        const match = cols.find(c => (c.inventory_item_id && c.inventory_item_id == targetDistributionItemId) || c.id == targetDistributionItemId || (c.item_name && targetDistributionItemName && c.item_name.toLowerCase().trim() === targetDistributionItemName.toLowerCase().trim()));
        if (match) {
          itemFilterSelect.value = match.id;
          selectedItemFilter = String(match.id);
        } else {
          itemFilterSelect.value = 'ALL';
          selectedItemFilter = 'ALL';
        }
      } else if (prevFilterVal && cols.some(c => c.id == prevFilterVal)) {
        itemFilterSelect.value = prevFilterVal;
        selectedItemFilter = String(prevFilterVal);
      } else {
        itemFilterSelect.value = 'ALL';
        selectedItemFilter = 'ALL';
      }
    }

    // Active item banner
    const banner = document.getElementById('distActiveItemBanner');
    const bannerName = document.getElementById('distActiveItemName');
    if (banner && bannerName) {
      if (selectedItemFilter !== 'ALL') {
        const activeCol = cols.find(c => c.id == selectedItemFilter);
        if (activeCol) {
          bannerName.textContent = `${activeCol.item_name} (${activeCol.remaining_quantity} available stock in event)`;
          banner.style.display = 'flex';
        } else {
          banner.style.display = 'none';
        }
      } else {
        banner.style.display = 'none';
      }
    }

    document.getElementById('distSummaryText').textContent = `Total Students: ${d.total_students} | Distributed: ${d.summary.total_distributed_items} / ${d.summary.total_eligible_items}`;
    document.getElementById('distCompletionRate').textContent = `${d.summary.completion_rate}% Complete`;

    // Event status badge
    const statusBadge = document.getElementById('distEventStatusBadge');
    if (statusBadge) {
      statusBadge.textContent = d.event_status || 'Upcoming';
      statusBadge.className = `badge ${d.event_status === 'Completed' ? 'badge-completed' : (d.event_status === 'Active' || d.event_status === 'Ongoing' ? 'badge-active' : 'badge-upcoming')}`;
    }

    // Complete Event button container
    const completeBtnContainer = document.getElementById('distCompleteEventBtnContainer');
    if (completeBtnContainer) {
      if (d.event_status === 'Completed') {
        completeBtnContainer.innerHTML = `
          <div style="display: flex; gap: 8px; align-items: center;">
            <span class="badge badge-completed" style="font-size: 12px; padding: 6px 12px;"><i class="fa-solid fa-circle-check"></i> Event Completed</span>
            <button class="btn-secondary" onclick="handleReopenCurrentEvent()" style="padding: 4px 10px; font-size: 11px;" title="Reopen Event to Ongoing"><i class="fa-solid fa-rotate-left"></i> Reopen</button>
          </div>
        `;
      } else {
        const canComplete = d.summary.can_complete;
        completeBtnContainer.innerHTML = `
          <button class="btn-primary" id="btnDistCompleteEvent" onclick="handleCompleteCurrentEvent()" 
            style="padding: 6px 16px; font-size: 13px; font-weight: 700; background: linear-gradient(135deg, #10b981, #059669); border-color: #059669; box-shadow: 0 3px 8px rgba(16, 185, 129, 0.3);"
            title="${canComplete ? 'All eligible students accounted for! Click to complete event.' : `${d.summary.unaccounted_count} student item(s) pending without remark.`}">
            <i class="fa-solid fa-flag-checkered"></i> Complete Event
          </button>
        `;
      }
    }

    const container = document.getElementById('distRowsContainer');
    if (!d.rows || d.rows.length === 0) {
      container.innerHTML = `<div class="card" style="text-align: center; padding: 30px;">No eligible students found for this filter.</div>`;
      return;
    }

    container.innerHTML = d.rows.map(row => {
      let statusClass = 'badge-upcoming';
      if (row.status === 'COMPLETED') statusClass = 'badge-completed';
      if (row.status === 'PARTIAL') statusClass = 'badge-active';

      const itemsHtml = Object.entries(row.items).map(([invId, item]) => {
        if (!item.eligible) return '';
        // If an item filter is selected, only show the matching item
        if (selectedItemFilter !== 'ALL' && invId != selectedItemFilter) return '';

        if (item.received) {
          return `
            <div style="background: var(--surface-gray); padding: 10px 14px; border-radius: 8px; margin-top: 6px; border: 1px solid rgba(16, 185, 129, 0.25);">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 700; color: var(--primary-navy);">
                  <input type="checkbox" checked disabled>
                  <span>${escapeHtml(item.item_name)}</span>
                </label>
                <div style="display: flex; align-items: center; gap: 8px;">
                  <span class="badge badge-completed" style="font-size: 11px;"><i class="fa-solid fa-circle-check"></i> Distributed</span>
                  <button class="btn-danger" style="padding: 2px 8px; font-size: 11px;" onclick="undoDistribution(${item.distribution_id}, '${escapeHtml(row.name)}', '${escapeHtml(item.item_name)}')">
                    <i class="fa-solid fa-undo"></i> Undo
                  </button>
                </div>
              </div>
              ${item.remarks ? `<div style="font-size: 11px; color: var(--text-gray); margin-top: 4px;"><i class="fa-regular fa-comment"></i> Remark: <em>${escapeHtml(item.remarks)}</em></div>` : ''}
            </div>
          `;
        }

        return `
          <div style="background: var(--surface-gray); padding: 12px; border-radius: 8px; margin-top: 8px; border: 1.5px solid ${item.has_remark ? 'rgba(16, 185, 129, 0.45)' : 'rgba(239, 68, 68, 0.35)'};">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 13px; font-weight: 600; color: var(--text-gray);">
                <input type="checkbox" onchange="confirmDistribution(${row.student_id}, ${invId}, '${escapeHtml(row.name)}', '${escapeHtml(item.item_name)}')">
                <span style="color: var(--primary-navy); font-weight: 700;">${escapeHtml(item.item_name)}</span>
              </label>
              <div style="display: flex; align-items: center; gap: 8px;">
                <span style="font-size: 11px; color: var(--text-gray); font-weight: 500;">${item.remaining_stock} available</span>
                ${item.has_remark
            ? `<span class="badge badge-completed" style="font-size: 10px; padding: 2px 8px;"><i class="fa-solid fa-check"></i> Remark Updated</span>`
            : `<span class="badge" style="background: #fee2e2; color: #dc2626; font-size: 10px; padding: 2px 8px;"><i class="fa-solid fa-triangle-exclamation"></i> Remark Required to Complete</span>`}
              </div>
            </div>

            <!-- Pending Remark Section -->
            <div style="background: #ffffff; border-radius: 6px; padding: 10px; border: 1px dashed ${item.has_remark ? '#10b981' : '#f59e0b'}; margin-top: 6px;">
              <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; flex-wrap: wrap; gap: 6px;">
                <label style="font-size: 11px; font-weight: 700; color: var(--primary-navy); display: flex; align-items: center; gap: 5px;">
                  <i class="fa-regular fa-comment-dots" style="color: var(--primary-orange);"></i> Add Remark / Reason for Non-Distribution:
                </label>
                ${item.has_remark
            ? `<span style="font-size: 11px; color: #059669; font-weight: 600;"><i class="fa-solid fa-circle-check"></i> Saved: "${escapeHtml(item.remarks)}"</span>`
            : `<span style="font-size: 11px; color: #d97706; font-style: italic;">Required if student did not receive item</span>`}
              </div>

              <div style="display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 8px;">
                <span style="font-size: 10px; color: var(--text-gray); align-self: center;">Quick tags:</span>
                <button type="button" class="btn-secondary" style="padding: 2px 8px; font-size: 10px; border-radius: 12px;" onclick="setQuickRemark(${row.student_id}, ${invId}, 'Absent')">Absent</button>
                <button type="button" class="btn-secondary" style="padding: 2px 8px; font-size: 10px; border-radius: 12px;" onclick="setQuickRemark(${row.student_id}, ${invId}, 'Size Unavailable')">Size Unavailable</button>
                <button type="button" class="btn-secondary" style="padding: 2px 8px; font-size: 10px; border-radius: 12px;" onclick="setQuickRemark(${row.student_id}, ${invId}, 'Expelled from S60')">Expelled from S60</button>
                <button type="button" class="btn-secondary" style="padding: 2px 8px; font-size: 10px; border-radius: 12px;" onclick="setQuickRemark(${row.student_id}, ${invId}, 'Opted Out')">Opted Out</button>
              </div>

              <input type="text" id="remarkInput_${row.student_id}_${invId}" 
                class="form-control" 
                placeholder="Type remark here (e.g., Absent on event day, size unavailable, etc.)..." 
                value="${escapeHtml(item.remarks || '')}" 
                style="width: 100%; padding: 7px 10px; font-size: 12px; border: 1px solid var(--border-subtle); border-radius: 6px; box-sizing: border-box; margin-bottom: 8px;">

              <div style="display: flex; justify-content: flex-end; align-items: center; gap: 8px;">
                <button type="button" class="btn-primary" 
                  style="padding: 5px 16px; font-size: 12px; font-weight: 700; background: var(--primary-orange); border-color: var(--primary-orange);" 
                  onclick="savePendingRemark(${eventId}, ${row.student_id}, ${invId}, '${escapeHtml(row.name)}', '${escapeHtml(item.item_name)}')">
                  <i class="fa-solid fa-floppy-disk"></i> Update
                </button>
              </div>
            </div>
          </div>
        `;
      }).join('');

      const renderedItems = itemsHtml.trim() ? itemsHtml : `<div style="font-size: 12px; color: var(--text-gray); padding: 6px; font-style: italic;">No items eligible under current filter</div>`;

      return `
        <div class="card" style="padding: 16px;">
          <div style="display: flex; justify-content: space-between; align-items: flex-start;">
            <div>
              <h4 style="font-size: 15px;">${row.name}</h4>
              <p style="font-size: 12px; color: var(--text-gray);">
                ${row.student_uid} • Roll: ${row.roll_number} • Sem ${row.semester}
                ${row.is_winner ? `&nbsp;•&nbsp;<strong style="color: var(--primary-orange);"><i class="fa-solid fa-trophy"></i> ${row.winner_position}</strong>` : ''}
              </p>
            </div>
            <span class="badge ${statusClass}">${row.total_received} / ${row.total_eligible} Received</span>
          </div>
          <div style="margin-top: 10px;">
            ${renderedItems}
          </div>
        </div>
      `;
    }).join('');

  } catch (err) {
    console.error('Failed to load matrix:', err);
  }
}

function onDistItemFilterChange() {
  const select = document.getElementById('distItemFilter');
  if (select && select.value === 'ALL') {
    targetDistributionItemId = null;
    targetDistributionItemName = null;
  } else if (select) {
    const opt = select.options[select.selectedIndex];
    targetDistributionItemId = opt ? (opt.getAttribute('data-item-id') || select.value) : null;
    targetDistributionItemName = opt ? (opt.getAttribute('data-name') || '') : null;
  }
  loadDistributionMatrix();
}

function clearDistributionItemFilter() {
  targetDistributionItemId = null;
  targetDistributionItemName = null;
  const select = document.getElementById('distItemFilter');
  if (select) select.value = 'ALL';
  const banner = document.getElementById('distActiveItemBanner');
  if (banner) banner.style.display = 'none';
  loadDistributionMatrix();
}

async function confirmDistribution(studentId, eventInventoryId, studentName, itemName) {
  try {
    const res = await fetch(`${API_URL}/distribution/save`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        student_id: studentId,
        event_inventory_id: eventInventoryId,
        quantity: 1
      })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`✓ Recorded: ${studentName} received ${itemName}`);
      loadDistributionMatrix();
      loadDashboard();
    } else {
      showToast(data.detail || data.message || 'Distribution failed', 'error');
      loadDistributionMatrix();
    }
  } catch (err) {
    showToast('Failed to record distribution', 'error');
  }
}

async function undoDistribution(distributionId, studentName, itemName) {
  if (!confirm(`Reversing will return 1 unit of ${itemName} back to inventory for ${studentName}. Confirm?`)) return;

  try {
    const res = await fetch(`${API_URL}/distribution/${distributionId}/reverse`, {
      method: 'POST',
      headers: authHeaders()
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`Distribution reversed: 1 unit returned to stock.`);
      loadDistributionMatrix();
      loadDashboard();
    } else {
      showToast(data.detail || 'Reversal failed', 'error');
    }
  } catch (err) {
    showToast('Failed to reverse distribution', 'error');
  }
}

// ---------------- DISTRIBUTION REMARKS & EVENT COMPLETION ----------------
function setQuickRemark(studentId, invId, text) {
  const input = document.getElementById(`remarkInput_${studentId}_${invId}`);
  if (input) {
    input.value = text;
    input.focus();
  }
}

async function savePendingRemark(eventId, studentId, invId, studentName, itemName) {
  const input = document.getElementById(`remarkInput_${studentId}_${invId}`);
  const remarkVal = input ? input.value.trim() : '';

  try {
    const res = await fetch(`${API_URL}/distribution/remark`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        event_id: Number(eventId),
        student_id: Number(studentId),
        event_inventory_id: Number(invId),
        remarks: remarkVal
      })
    });
    const result = await res.json();
    if (res.ok && result.success) {
      showToast(remarkVal ? `✓ Remark updated for ${studentName}!` : `Remark cleared for ${studentName}`);
      loadDistributionMatrix();
    } else {
      showToast(result.detail || result.message || 'Failed to update remark', 'error');
    }
  } catch (err) {
    console.error('Failed to update remark:', err);
    showToast('Network error while updating remark', 'error');
  }
}

async function handleCompleteCurrentEvent() {
  if (!activeEventId) {
    showToast('No active event selected', 'error');
    return;
  }

  if (!confirm('Are you sure you want to complete this event?\n\nAll eligible students must either have received their item or have an updated remark.')) {
    return;
  }

  try {
    const res = await fetch(`${API_URL}/events/${activeEventId}/complete`, {
      method: 'POST',
      headers: authHeaders()
    });
    const result = await res.json();

    if (res.ok && result.success) {
      showToast(result.message || 'Event marked as Completed!', 'success');
      await loadDistributionMatrix();
      if (document.getElementById('tab-events') && document.getElementById('tab-events').style.display !== 'none') {
        loadSavedEvents();
      }
    } else {
      const errorMsg = result.detail || result.message || 'Cannot complete event.';
      alert(`⚠️ Action Blocked:\n\n${errorMsg}\n\nPlease filter by "Pending (None received)" to add remarks or distribute items.`);
      const statusFilter = document.getElementById('distStatusFilter');
      if (statusFilter && statusFilter.value !== 'PENDING') {
        statusFilter.value = 'PENDING';
        loadDistributionMatrix();
      }
    }
  } catch (err) {
    console.error('Error completing event:', err);
    showToast('Failed to complete event', 'error');
  }
}

async function handleReopenCurrentEvent() {
  if (!activeEventId) return;
  if (!confirm('Reopen this event to Ongoing status?')) return;

  try {
    const res = await fetch(`${API_URL}/events/${activeEventId}/reopen`, {
      method: 'POST',
      headers: authHeaders()
    });
    const result = await res.json();
    if (res.ok && result.success) {
      showToast('Event reopened successfully.');
      loadDistributionMatrix();
      if (document.getElementById('tab-events') && document.getElementById('tab-events').style.display !== 'none') {
        loadSavedEvents();
      }
    } else {
      showToast(result.detail || 'Failed to reopen event', 'error');
    }
  } catch (err) {
    showToast('Network error reopening event', 'error');
  }
}

async function quickCompleteEvent(eventId, eventName, fromModal = false) {
  if (!confirm(`Mark event "${eventName}" as Completed?\n\nAll students must either have received items or have an updated remark.`)) {
    return;
  }

  try {
    const res = await fetch(`${API_URL}/events/${eventId}/complete`, {
      method: 'POST',
      headers: authHeaders()
    });
    const result = await res.json();

    if (res.ok && result.success) {
      showToast(`Event "${eventName}" completed successfully!`, 'success');
      loadSavedEvents();
      if (fromModal) {
        closeModal('eventDetailModal');
      }
      if (activeEventId == eventId) {
        loadDistributionMatrix();
      }
    } else {
      const errorMsg = result.detail || result.message || 'Cannot complete event.';
      if (confirm(`⚠️ Cannot Complete Event:\n\n${errorMsg}\n\nWould you like to open the Distribution Portal to review pending students and add remarks?`)) {
        if (fromModal) closeModal('eventDetailModal');
        activeEventId = eventId;
        const select = document.getElementById('distEventSelect');
        if (select) select.value = eventId;
        const statusFilter = document.getElementById('distStatusFilter');
        if (statusFilter) statusFilter.value = 'PENDING';
        switchTab('distribution');
      }
    }
  } catch (err) {
    showToast('Failed to complete event', 'error');
  }
}

async function quickReopenEvent(eventId, eventName, fromModal = false) {
  if (!confirm(`Reopen event "${eventName}" to Ongoing status?`)) return;
  try {
    const res = await fetch(`${API_URL}/events/${eventId}/reopen`, {
      method: 'POST',
      headers: authHeaders()
    });
    const result = await res.json();
    if (res.ok && result.success) {
      showToast(`Event reopened to Ongoing.`, 'success');
      loadSavedEvents();
      if (fromModal) openEventDetails(eventId);
      if (activeEventId == eventId) loadDistributionMatrix();
    } else {
      showToast(result.detail || 'Failed to reopen event', 'error');
    }
  } catch (err) {
    showToast('Failed to reopen event', 'error');
  }
}

// ---------------- MASTER INVENTORY ----------------
function openAddMasterItemModal() {
  document.getElementById('masterItemName').value = '';
  document.getElementById('masterItemQuantity').value = '1';
  document.getElementById('masterItemUnit').value = 'units';
  document.getElementById('masterItemDesc').value = '';
  removePhoto('masterItemPhotoPreview', 'masterItemPhotoData', 'masterItemRemovePhotoBtn');
  const fileInp = document.getElementById('masterItemPhotoInput');
  if (fileInp) fileInp.value = '';
  document.getElementById('addMasterItemModal').classList.add('active');
}

async function handleCreateMasterItem(e) {
  e.preventDefault();
  const name = document.getElementById('masterItemName').value.trim();
  const category = document.getElementById('masterItemCategory').value;
  const unit = document.getElementById('masterItemUnit').value.trim() || 'units';
  const initial_stock = parseInt(document.getElementById('masterItemQuantity').value) || 0;
  const description = document.getElementById('masterItemDesc').value.trim();
  const image_url = document.getElementById('masterItemPhotoData').value.trim() || null;

  try {
    const res = await fetch(`${API_URL}/inventory`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ name, category, unit, initial_stock, description, image_url })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`Added item '${data.data.name}' with ${initial_stock} units to catalog!`);
      closeModal('addMasterItemModal');
      loadMasterInventory();
      loadDashboard();
    } else {
      showToast(data.detail || data.message || 'Failed to add item', 'error');
    }
  } catch (err) {
    showToast('Failed to add item', 'error');
  }
}

function openEditStockModal(id, name, currentStock) {
  document.getElementById('editStockItemId').value = id;
  document.getElementById('editStockItemName').textContent = name;
  document.getElementById('editStockQuantity').value = currentStock || 0;
  document.getElementById('editStockModal').classList.add('active');
}

async function handleUpdateStock(e) {
  e.preventDefault();
  const id = document.getElementById('editStockItemId').value;
  const initial_stock = parseInt(document.getElementById('editStockQuantity').value) || 0;

  try {
    const res = await fetch(`${API_URL}/inventory/${id}`, {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({ initial_stock })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`Updated units to ${initial_stock}!`);
      closeModal('editStockModal');
      await loadMasterInventory();
      await loadDashboard();
    } else {
      showToast(data.detail || data.message || 'Failed to update units', 'error');
    }
  } catch (err) {
    showToast('Failed to update units', 'error');
  }
}

async function deleteMasterItem(id, name, eventsCount = 0) {
  let promptMsg = `Are you sure you want to delete "${name}" from Master Inventory?\n\nThis action cannot be undone.`;
  if (eventsCount > 0) {
    promptMsg = `"${name}" is currently linked to ${eventsCount} event(s).\n\nDeleting it will remove its allocations from those events as well.\n\nAre you sure you want to proceed with deleting "${name}"?`;
  }
  if (!confirm(promptMsg)) {
    return;
  }

  try {
    const res = await fetch(`${API_URL}/inventory/${id}?force=true`, {
      method: 'DELETE',
      headers: authHeaders()
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(data.message || `Deleted '${name}' from catalog.`);
      cachedMasterInventoryItems = [];
      await loadMasterInventory();
      await loadDashboard();
    } else {
      showToast(data.detail || data.message || 'Failed to delete item', 'error');
    }
  } catch (err) {
    showToast('Failed to delete item', 'error');
  }
}

async function openMasterDistribute(itemId) {
  let item = cachedMasterInventoryItems.find(i => i.id === itemId);
  if (!item) {
    try {
      const res = await fetch(`${API_URL}/inventory`, { headers: authHeaders() });
      const data = await res.json();
      cachedMasterInventoryItems = data.data || [];
      item = cachedMasterInventoryItems.find(i => i.id === itemId);
    } catch (e) {
      console.error(e);
    }
  }

  if (!item) {
    showToast('Item not found in master inventory', 'error');
    return;
  }

  const linkedEvents = item.events || [];
  const eventIds = item.event_ids || [];

  // Case 1: Item is linked to exactly 1 event -> directly open distribution
  if (eventIds.length === 1) {
    const targetEventId = eventIds[0];
    directDistributeItemInEvent(targetEventId, item.id, item.name);
    return;
  }

  // Case 2: Item is linked to multiple events -> show selection modal
  if (eventIds.length > 1) {
    openMasterDistributeMultiEventModal(item);
    return;
  }

  // Case 3: Item has 0 events linked -> prompt to link to an event and start distribution
  openMasterDistributeAllocateModal(item);
}

function directDistributeItemInEvent(eventId, itemId, itemName) {
  activeEventId = eventId;
  targetDistributionItemId = itemId;
  targetDistributionItemName = itemName;
  switchTab('distribution');
  showToast(`Opened distribution portal for '${itemName}'`);
}

function openMasterDistributeMultiEventModal(item) {
  document.getElementById('mDistItemName').textContent = item.name;
  document.getElementById('mDistStockInfo').textContent = `${item.category} • ${item.total_remaining} remaining units in master stock`;
  document.getElementById('mDistItemId').value = item.id;

  const eventListContainer = document.getElementById('mDistEventList');
  eventListContainer.innerHTML = (item.events || []).map(ev => `
    <div style="display: flex; justify-content: space-between; align-items: center; background: var(--surface-gray); padding: 10px 14px; border-radius: 8px; border: 1px solid var(--border-subtle);">
      <div>
        <div style="font-weight: 700; font-size: 13px; color: var(--primary-navy);">${ev.event_uid} • ${ev.name}</div>
        <div style="font-size: 11px; color: var(--text-gray); margin-top: 2px;">
          Allocated: ${ev.initial_quantity} | Distributed: ${ev.distributed_quantity} | Remaining: <strong style="color: var(--primary-orange);">${ev.remaining_quantity}</strong>
        </div>
      </div>
      <button type="button" class="btn-primary" style="padding: 6px 14px; font-size: 12px;" onclick="closeModal('masterDistributeModal'); directDistributeItemInEvent(${ev.id}, ${item.id}, '${item.name.replace(/'/g, "\\'")}')">
        <i class="fa-solid fa-clipboard-check"></i> Distribute
      </button>
    </div>
  `).join('');

  document.getElementById('mDistMultiEventSection').style.display = 'block';
  document.getElementById('mDistAllocateForm').style.display = 'none';
  document.getElementById('masterDistributeModal').classList.add('active');
}

async function openMasterDistributeAllocateModal(item) {
  document.getElementById('mDistItemName').textContent = item.name;
  document.getElementById('mDistStockInfo').textContent = `${item.category} • Master Stock: ${item.total_remaining} remaining units`;
  document.getElementById('mDistItemId').value = item.id;

  // Update photo in distribute modal header
  const photoBox = document.getElementById('mDistPhotoBox');
  if (photoBox) {
    if (item.image_url) {
      photoBox.innerHTML = `<img src="${item.image_url}" style="width: 100%; height: 100%; object-fit: cover;">`;
    } else {
      photoBox.innerHTML = `<i class="fa-solid fa-box" style="font-size: 18px;"></i>`;
    }
  }

  // Load events into dropdown - TARGET EVENT IS OPTIONAL
  try {
    const res = await fetch(`${API_URL}/events?status=ALL`, { headers: authHeaders() });
    const data = await res.json();
    const events = (data.data && data.data.items) ? data.data.items : [];
    const targetSelect = document.getElementById('mDistTargetEvent');

    targetSelect.innerHTML = `
      <option value="">-- No Specific Event (General / Master Inventory) --</option>
    ` + events.map(ev => `
      <option value="${ev.id}">${ev.event_uid} • ${ev.name} (${ev.event_date})</option>
    `).join('');
    targetSelect.value = ''; // Do NOT preselect any event!

    // Pre-fill quantity
    const defaultQty = item.total_remaining > 0 ? item.total_remaining : 50;
    const qtyInput = document.getElementById('mDistQty');
    qtyInput.value = defaultQty;
    qtyInput.max = item.total_remaining > 0 ? item.total_remaining : 9999;

    document.getElementById('mDistEligibility').value = 'ALL';
    document.getElementById('mDistSemesterGroup').style.display = 'none';

    document.getElementById('mDistHelpText').textContent = `Target event is optional. You can allocate '${item.name}' to a specific event or manage it directly under Master Inventory.`;
    document.getElementById('mDistMultiEventSection').style.display = 'none';
    document.getElementById('mDistAllocateForm').style.display = 'block';
    document.getElementById('masterDistributeModal').classList.add('active');
  } catch (err) {
    showToast('Failed to load events for allocation', 'error');
  }
}

function showMasterDistributeLinkNewForm() {
  const itemId = parseInt(document.getElementById('mDistItemId').value);
  const item = cachedMasterInventoryItems.find(i => i.id === itemId);
  if (item) openMasterDistributeAllocateModal(item);
}

function toggleMDistSemesterFilter() {
  const el = document.getElementById('mDistEligibility').value;
  document.getElementById('mDistSemesterGroup').style.display = (el === 'SEMESTER') ? 'block' : 'none';
}

async function handleMasterDistributeAllocate(e) {
  e.preventDefault();
  const itemId = parseInt(document.getElementById('mDistItemId').value);
  const eventIdVal = document.getElementById('mDistTargetEvent').value;
  const eventId = eventIdVal ? parseInt(eventIdVal) : null;
  const qty = parseInt(document.getElementById('mDistQty').value);
  const eligibility = document.getElementById('mDistEligibility').value;
  const semFilter = eligibility === 'SEMESTER' ? parseInt(document.getElementById('mDistSemester').value) : null;

  const item = cachedMasterInventoryItems.find(i => i.id === itemId);
  const itemName = item ? item.name : 'Item';

  // If no target event was selected: keep/update standalone master inventory
  if (!eventId) {
    showToast(`✓ Master stock confirmed: ${qty} units of '${itemName}' (Standalone Inventory, no event tied).`);
    closeModal('masterDistributeModal');
    loadMasterInventory();
    return;
  }

  try {
    const res = await fetch(`${API_URL}/events/${eventId}/inventory`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        inventory_item_id: itemId,
        initial_quantity: qty,
        eligibility_type: eligibility,
        semester_filter: semFilter,
        low_stock_threshold: 5
      })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`'${itemName}' allocated to event! Opening distribution...`);
      closeModal('masterDistributeModal');
      loadMasterInventory();
      directDistributeItemInEvent(eventId, itemId, itemName);
    } else if (data.detail && data.detail.includes('already added')) {
      showToast(`'${itemName}' is already in this event. Opening distribution...`);
      closeModal('masterDistributeModal');
      directDistributeItemInEvent(eventId, itemId, itemName);
    } else {
      showToast(data.detail || data.message || 'Failed to allocate item', 'error');
    }
  } catch (err) {
    showToast('Failed to allocate item to event', 'error');
  }
}

async function loadMasterInventory() {
  try {
    const res = await fetch(`${API_URL}/inventory?_t=${Date.now()}`, {
      headers: authHeaders(),
      cache: 'no-store'
    });
    const data = await res.json();
    const items = data.data || [];
    cachedMasterInventoryItems = items;

    const isSuperAdmin = currentAdmin && (currentAdmin.role === 'SUPER_ADMIN');

    const container = document.getElementById('masterInventoryContainer');
    if (items.length === 0) {
      container.innerHTML = `
        <div class="card" style="grid-column: 1 / -1; text-align: center; padding: 48px 24px;">
          <div style="width: 56px; height: 56px; border-radius: 16px; background: rgba(244, 123, 32, 0.12); display: inline-flex; align-items: center; justify-content: center; margin-bottom: 16px;">
            <i class="fa-solid fa-box-open" style="font-size: 28px; color: var(--primary-orange);"></i>
          </div>
          <h3 style="font-size: 18px; margin-bottom: 8px; color: var(--primary-navy);">Master Inventory is Empty</h3>
          <p style="font-size: 13px; color: var(--text-gray); max-width: 480px; margin: 0 auto 20px;">
            No predefined rewards or items exist. Click below to add items to your catalog (e.g., T-Shirts, Certificates, Medals, Kits).
          </p>
          <button class="btn-primary" onclick="openAddMasterItemModal()" style="display: inline-flex;">
            <i class="fa-solid fa-plus"></i> Add Item to Catalog
          </button>
        </div>
      `;
      return;
    }

    container.innerHTML = items.map(item => {
      const isEventCreated = item.is_event_created || (item.created_source === 'EVENT');
      const safeName = item.name.replace(/'/g, "\\'").replace(/"/g, '&quot;');
      return `
      <div class="card" style="display: flex; flex-direction: column; justify-content: space-between;">
        <div>
          <div style="display: flex; gap: 14px; align-items: flex-start; margin-bottom: 12px;">
            <div style="width: 46px; height: 46px; border-radius: 12px; background: rgba(244, 123, 32, 0.12); display: flex; align-items: center; justify-content: center; flex-shrink: 0; overflow: hidden; border: 1px solid var(--border-subtle);">
              ${item.image_url ?
          `<img src="${item.image_url}" alt="${item.name}" style="width: 100%; height: 100%; object-fit: cover;">` :
          `<i class="fa-solid fa-box" style="color: var(--primary-orange); font-size: 20px;"></i>`
        }
            </div>
            <div style="flex: 1; min-width: 0;">
              <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px;">
                <h3 style="font-size: 16px; margin: 0; word-break: break-word;">${item.name}</h3>
                ${isEventCreated ?
          `<span style="font-size: 10px; color: var(--primary-navy); background: rgba(15,43,91,0.08); padding: 2px 6px; border-radius: 4px; white-space: nowrap; font-weight: 600;"><i class="fa-solid fa-calendar-day"></i> Event Item</span>` :
          `<span style="font-size: 10px; color: var(--primary-orange); background: rgba(244,123,32,0.1); padding: 2px 6px; border-radius: 4px; white-space: nowrap; font-weight: 600;"><i class="fa-solid fa-boxes-stacked"></i> Master Stock</span>`
        }
              </div>
              <p style="font-size: 12px; color: var(--text-gray); margin-top: 2px;">${item.category} • ${item.events_count} Events Linked</p>
            </div>
          </div>
          <div style="margin-top: 10px; display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; text-align: center; background: var(--surface-gray); padding: 8px; border-radius: 10px; margin-bottom: 14px;">
            <div>
              <div style="font-size: 10px; color: var(--text-gray);">Allocated</div>
              <div style="font-size: 15px; font-weight: bold; color: var(--primary-navy);">${item.total_allocated}</div>
            </div>
            <div>
              <div style="font-size: 10px; color: var(--text-gray);">Distributed</div>
              <div style="font-size: 15px; font-weight: bold; color: var(--status-green);">${item.total_distributed}</div>
            </div>
            <div>
              <div style="font-size: 10px; color: var(--text-gray);">Remaining</div>
              <div style="font-size: 15px; font-weight: bold; color: var(--primary-orange);">${item.total_remaining}</div>
            </div>
          </div>
        </div>
        <div style="display: flex; gap: 8px; align-items: center; border-top: 1px solid var(--border-subtle); padding-top: 12px;">
          <button class="btn-primary" onclick="openMasterDistribute(${item.id})" style="padding: 6px 12px; font-size: 12px; flex: 1; justify-content: center;" title="Open Rewards & Distribution Portal">
            <i class="fa-solid fa-clipboard-check"></i> Distribute
          </button>
          <button class="btn-secondary" onclick="openEditStockModal(${item.id}, '${safeName}', ${item.total_allocated})" style="padding: 6px 10px; font-size: 12px;" title="Update Allocated Units / Stock">
            <i class="fa-solid fa-pen-to-square"></i> Edit
          </button>
          <button class="btn-danger" onclick="deleteMasterItem(${item.id}, '${safeName}', ${item.events_count})" style="padding: 6px 10px; font-size: 12px; min-width: 32px; min-height: 32px; display: inline-flex; align-items: center; justify-content: center;" title="Delete Item">
            ${TRASH_ICON_SVG}
          </button>
        </div>
      </div>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to load master inventory:', err);
  }
}

// ---------------- STUDENTS & PROMOTION ----------------
function openAddStudentModal() {
  document.getElementById('newStudentId').value = '';
  document.getElementById('newStudentRoll').value = '';
  document.getElementById('newStudentName').value = '';
  document.getElementById('newStudentEmail').value = '';
  document.getElementById('newStudentPhone').value = '';
  document.getElementById('addStudentModal').classList.add('active');
}

async function handleCreateStudent(e) {
  e.preventDefault();
  const student_id = document.getElementById('newStudentId').value.trim();
  const roll_number = document.getElementById('newStudentRoll').value.trim();
  const name = document.getElementById('newStudentName').value.trim();
  const current_semester = parseInt(document.getElementById('newStudentSemester').value);
  const batch = document.getElementById('newStudentBatch').value.trim() || '2025';
  const email = document.getElementById('newStudentEmail').value.trim() || null;
  const phone = document.getElementById('newStudentPhone').value.trim() || null;

  try {
    const res = await fetch(`${API_URL}/students`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        student_id,
        roll_number,
        name,
        current_semester,
        batch,
        branch: 'CSE',
        email,
        phone,
        status: 'ACTIVE'
      })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`Student ${data.data.name} (${data.data.student_id}) inserted successfully!`);
      closeModal('addStudentModal');
      loadStudentsList();
      loadDashboard();
    } else {
      showToast(data.detail || data.message || 'Failed to insert student', 'error');
    }
  } catch (err) {
    showToast('Failed to insert student', 'error');
  }
}

async function loadStudentsList() {
  const search = document.getElementById('studentSearchInput').value.trim();
  const semester = document.getElementById('studentSemesterFilter').value;
  const status = document.getElementById('studentStatusFilter').value;

  const params = new URLSearchParams();
  if (search) params.append('search', search);
  if (semester) params.append('semester', semester);
  params.append('status', status);
  params.append('page_size', '500');
  params.append('_t', Date.now());

  try {
    const res = await fetch(`${API_URL}/students?${params.toString()}`, {
      headers: authHeaders(),
      cache: 'no-store'
    });
    const data = await res.json();
    const students = data.data.items || [];
    const totalCount = (data.data && typeof data.data.total === 'number') ? data.data.total : students.length;

    const countFooter = document.getElementById('studentsTotalCountText');
    if (countFooter) {
      countFooter.innerHTML = `<i class="fa-solid fa-users" style="color: var(--primary-orange);"></i> Total Students: <strong>${totalCount}</strong>`;
    }

    const tbody = document.getElementById('studentsTableBody');
    if (students.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="7" style="text-align: center; padding: 48px 24px;">
            <div style="width: 56px; height: 56px; border-radius: 16px; background: rgba(244, 123, 32, 0.12); display: inline-flex; align-items: center; justify-content: center; margin-bottom: 16px;">
              <i class="fa-solid fa-user-graduate" style="font-size: 28px; color: var(--primary-orange);"></i>
            </div>
            <h4 style="font-size: 18px; margin-bottom: 8px; color: var(--primary-navy);">No Students Found</h4>
            <p style="font-size: 13px; color: var(--text-gray); max-width: 480px; margin: 0 auto 20px;">
              The student list is completely clean with zero predefined records. Click below to insert students or use Bulk Import.
            </p>
            <div style="display: flex; gap: 12px; justify-content: center;">
              <button class="btn-primary" onclick="openAddStudentModal()" style="display: inline-flex;">
                <i class="fa-solid fa-user-plus"></i> Insert Student
              </button>
              <button class="btn-secondary" onclick="openBulkImportModal()" style="display: inline-flex;">
                <i class="fa-solid fa-file-csv"></i> Bulk CSV Import
              </button>
            </div>
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = students.map(st => `
      <tr style="border-bottom: 1px solid var(--border-subtle); cursor: pointer;" onclick="openStudentProfile(${st.id})">
        <td style="padding: 12px 18px; font-weight: bold; color: var(--primary-orange);">${st.student_id}</td>
        <td style="padding: 12px 18px;">${st.roll_number}</td>
        <td style="padding: 12px 18px; font-weight: 600; color: var(--primary-navy);">${st.name}</td>
        <td style="padding: 12px 18px;">${st.current_semester}th Sem</td>
        <td style="padding: 12px 18px;">${st.batch}</td>
        <td style="padding: 12px 18px;"><span class="badge ${st.status === 'ACTIVE' ? 'badge-completed' : 'badge-out'}">${st.status}</span></td>
        <td style="padding: 12px 18px; text-align: right;"><button class="btn-secondary" style="padding: 4px 10px; font-size: 11px;">Profile <i class="fa-solid fa-chevron-right"></i></button></td>
      </tr>
    `).join('');
  } catch (err) {
    console.error('Failed to load students:', err);
  }
}

async function openStudentProfile(studentId) {
  currentProfileStudentId = studentId;
  try {
    const res = await fetch(`${API_URL}/students/${studentId}`, { headers: authHeaders() });
    const result = await res.json();
    const d = result.data;
    const st = d.student;

    document.getElementById('profName').textContent = st.name;
    document.getElementById('profAvatar').textContent = st.name ? st.name.trim()[0].toUpperCase() : 'S';
    document.getElementById('profSidBadge').textContent = st.student_id;
    document.getElementById('profRollBadge').textContent = 'Roll: ' + st.roll_number;
    document.getElementById('profSemBadge').textContent = st.current_semester + 'th Semester';
    document.getElementById('profSubtitle').innerHTML = `<i class="fa-solid fa-graduation-cap"></i> ${st.branch || 'CSE'} • Batch ${st.batch || '2025'} ${st.email ? `• <i class="fa-solid fa-envelope"></i> ${st.email}` : ''}`;

    const totalRew = d.total_rewards_received || (d.reward_history ? d.reward_history.length : 0);
    document.getElementById('profRewardsCount').textContent = totalRew;
    document.getElementById('profWinsCount').textContent = (d.wins ? d.wins.length : 0);
    document.getElementById('profEventsCount').textContent = d.total_events_attended || 0;

    const winsContainer = document.getElementById('profWinsContainer');
    const winsList = document.getElementById('profWinsList');
    if (d.wins && d.wins.length > 0) {
      winsContainer.style.display = 'block';
      winsList.innerHTML = d.wins.map(w => `
        <div style="background: rgba(244, 123, 32, 0.08); padding: 10px 14px; border-radius: 10px; font-size: 13px; border: 1px solid rgba(244, 123, 32, 0.2);">
          <div style="font-weight: 700; color: var(--primary-navy);"><i class="fa-solid fa-medal" style="color: var(--primary-orange);"></i> ${w.position} in <em>${w.event_name}</em></div>
          ${w.prize_title ? `<div style="font-size: 12px; color: var(--primary-orange); margin-top: 2px;">Prize: ${w.prize_title}</div>` : ''}
          ${w.notes ? `<div style="font-size: 11px; color: var(--text-gray); margin-top: 2px;">${w.notes}</div>` : ''}
        </div>
      `).join('');
    } else {
      winsContainer.style.display = 'none';
    }

    const rewList = document.getElementById('profRewardsList');
    if (d.reward_history && d.reward_history.length > 0) {
      rewList.innerHTML = d.reward_history.map(r => `
        <div style="background: var(--surface-gray); padding: 12px 14px; border-radius: 12px; display: flex; justify-content: space-between; align-items: center; border: 1px solid var(--border-subtle);">
          <div style="display: flex; align-items: center; gap: 12px;">
            <div style="width: 36px; height: 36px; border-radius: 10px; background: rgba(16, 185, 129, 0.12); color: var(--status-green); display: flex; align-items: center; justify-content: center; font-size: 16px;">
              <i class="fa-solid fa-gift"></i>
            </div>
            <div>
              <div style="font-weight: 700; color: var(--primary-navy); font-size: 13px;">${r.quantity}x ${r.item_name}</div>
              <div style="font-size: 11px; color: var(--text-gray); margin-top: 2px;">
                ${r.event_name} • Awarded in <strong style="color: var(--primary-orange);">${r.semester_at_distribution}th Sem</strong> (${r.session_at_distribution || ''})
              </div>
            </div>
          </div>
          <div style="text-align: right; font-size: 11px; color: var(--text-gray);">
            <div style="font-weight: 600; color: var(--primary-navy);">${r.distributed_by}</div>
            <span class="badge badge-completed" style="font-size: 10px; padding: 2px 6px;"><i class="fa-solid fa-check-circle"></i> Verified</span>
          </div>
        </div>
      `).join('');
    } else {
      rewList.innerHTML = `<p style="font-size: 12px; color: var(--text-gray); font-style: italic; text-align: center; padding: 16px;">No historical rewards recorded yet.</p>`;
    }

    const badge = document.getElementById('profStatusBadge');
    badge.className = `badge ${st.status === 'ACTIVE' ? 'badge-completed' : 'badge-out'}`;
    badge.textContent = st.status;

    const deactBtn = document.getElementById('profDeactivateBtn');
    deactBtn.innerHTML = st.status === 'ACTIVE' ? '<i class="fa-solid fa-user-slash"></i> Deactivate' : '<i class="fa-solid fa-user-plus"></i> Activate';
    deactBtn.className = st.status === 'ACTIVE' ? 'btn-danger' : 'btn-primary';

    document.getElementById('studentProfileModal').classList.add('active');
  } catch (err) {
    showToast('Failed to load profile', 'error');
  }
}

async function toggleStudentStatus() {
  if (!currentProfileStudentId) return;
  const isDeactivate = document.getElementById('profDeactivateBtn').textContent.includes('Deactivate');

  if (isDeactivate && !confirm('Deactivate this student? All their historical reward records will remain completely intact.')) return;

  const endpoint = isDeactivate ? 'deactivate' : 'activate';
  try {
    const res = await fetch(`${API_URL}/students/${currentProfileStudentId}/${endpoint}`, {
      method: 'POST',
      headers: authHeaders()
    });
    if (res.ok) {
      showToast(isDeactivate ? 'Student deactivated.' : 'Student activated.');
      closeModal('studentProfileModal');
      loadStudentsList();
    }
  } catch (err) {
    showToast('Failed to update student status', 'error');
  }
}

// ---------------- SEMESTER PROMOTION ----------------
async function openPromoteDialog() {
  try {
    const sessRes = await fetch(`${API_URL}/academic-sessions/current`, { headers: authHeaders() });
    const sessData = (await sessRes.json()).data;
    currentSession = sessData;

    const res = await fetch(`${API_URL}/academic-sessions/${sessData.id}/promote-preview`, { headers: authHeaders() });
    const preview = (await res.json()).data;

    const content = document.getElementById('promotePreviewContent');
    content.innerHTML = `
      <p style="margin-bottom: 12px;">Are you sure you want to transition academic scheme from <strong>${preview.scheme_from}</strong> to <strong>${preview.scheme_to}</strong>?</p>
      <div style="background: var(--surface-gray); padding: 12px; border-radius: 10px; margin-bottom: 12px;">
        ${Object.entries(preview.transitions).map(([k, v]) => `
          <div style="display: flex; justify-content: space-between; font-size: 13px; padding: 4px 0;">
            <span style="font-weight: 600; color: var(--primary-navy);">${k}</span>
            <span style="color: var(--primary-orange); font-weight: bold;">${v} students</span>
          </div>
        `).join('')}
      </div>
      <p style="font-size: 11px; color: var(--text-gray); font-style: italic;">
        ✓ Student IDs remain unchanged.<br>
        ✓ All past reward records stay attached to their historical semester context.
      </p>
    `;

    document.getElementById('promoteModal').classList.add('active');
  } catch (err) {
    showToast('Failed to load promotion preview', 'error');
  }
}

async function executePromotion() {
  if (!currentSession) return;
  try {
    const res = await fetch(`${API_URL}/academic-sessions/${currentSession.id}/promote`, {
      method: 'POST',
      headers: authHeaders()
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(data.message);
      closeModal('promoteModal');
      loadDashboard();
      loadStudentsList();
    } else {
      showToast(data.detail || 'Promotion failed', 'error');
    }
  } catch (err) {
    showToast('Failed to execute promotion', 'error');
  }
}

// ---------------- BULK IMPORT ----------------
function openBulkImportModal() {
  document.getElementById('bulkImportModal').classList.add('active');
}

async function executeBulkImport() {
  const text = document.getElementById('bulkCsvInput').value.trim();
  const lines = text.split('\n');
  if (lines.length <= 1) {
    showToast('Please paste CSV with headers', 'error');
    return;
  }

  const items = [];
  for (let i = 1; i < lines.length; i++) {
    const parts = lines[i].split(',');
    if (parts.length >= 3) {
      items.push({
        student_id: parts[0].trim(),
        name: parts[1].trim(),
        roll_number: parts[2].trim(),
        email: parts[3] ? parts[3].trim() : null,
        phone: parts[4] ? parts[4].trim() : null,
        batch: parts[5] ? parts[5].trim() : '2025',
        semester: parts[6] ? parseInt(parts[6].trim()) : 3
      });
    }
  }

  try {
    const res = await fetch(`${API_URL}/students/import`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify(items)
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`Import complete: ${data.data.imported_count} added, ${data.data.skipped_count} skipped.`);
      closeModal('bulkImportModal');
      loadStudentsList();
      loadDashboard();
    } else {
      showToast(data.detail || 'Import failed', 'error');
    }
  } catch (err) {
    showToast('Failed to import students', 'error');
  }
}

// ---------------- REPORTS & CSV EXPORT SUITE ----------------
let currentReportSubTab = 'events';

function switchReportsSubTab(subTab) {
  currentReportSubTab = subTab;
  const btnEvents = document.getElementById('repSubTabEvents');
  const btnInventory = document.getElementById('repSubTabInventory');
  const viewEvents = document.getElementById('repEventsView');
  const viewInventory = document.getElementById('repInventoryView');

  if (subTab === 'events') {
    if (btnEvents) btnEvents.classList.add('active');
    if (btnInventory) btnInventory.classList.remove('active');
    if (viewEvents) viewEvents.style.display = 'block';
    if (viewInventory) viewInventory.style.display = 'none';
    loadReportsData();
  } else {
    if (btnInventory) btnInventory.classList.add('active');
    if (btnEvents) btnEvents.classList.remove('active');
    if (viewEvents) viewEvents.style.display = 'none';
    if (viewInventory) viewInventory.style.display = 'block';
    loadMasterInventoryReports();
  }
}

function arrayBufferToBase64(buffer) {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return window.btoa(binary);
}

async function downloadReport(type, params = {}, format = 'excel') {
  try {
    const isExcel = format === 'excel';
    showToast(`Generating ${isExcel ? 'Excel (.xlsx)' : 'CSV'} report for ${type.replace(/_/g, ' ')}...`);
    const qParams = new URLSearchParams({ report_type: type, ...params });
    if (authToken) qParams.append('token', authToken);

    const endpoint = isExcel ? `${API_URL}/reports/export-excel` : `${API_URL}/reports/export-csv`;
    const res = await fetch(`${endpoint}?${qParams.toString()}`, {
      headers: authHeaders()
    });

    if (!res.ok) {
      showToast('Export failed. Please check your credentials.', 'error');
      return;
    }

    // Determine filename from Content-Disposition header
    let defaultExt = isExcel ? 'xlsx' : 'csv';
    let filename = `S60_${type}_Report.${defaultExt}`;
    const cd = res.headers.get('content-disposition');
    if (cd && cd.includes('filename=')) {
      const match = cd.match(/filename="?([^"]+)"?/);
      if (match && match[1]) filename = match[1];
    }

    if (isExcel) {
      const arrayBuffer = await res.arrayBuffer();
      const b64Data = arrayBufferToBase64(arrayBuffer);
      const mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      const blob = new Blob([arrayBuffer], { type: mimeType });

      // --- STRATEGY 1: Desktop App PyWebView Native Windows "Save As" Dialog ---
      if (window.pywebview && window.pywebview.api && typeof window.pywebview.api.save_file_dialog === 'function') {
        try {
          const dialogRes = await window.pywebview.api.save_file_dialog(filename, b64Data);
          if (dialogRes && dialogRes.cancelled) {
            showToast('Export save cancelled.', 'warning');
            return;
          }
          if (dialogRes && dialogRes.success) {
            showToast(`✓ Excel report saved: ${dialogRes.saved_path}`);
            return;
          }
        } catch (err) {
          console.warn('PyWebView save dialog error:', err);
        }
      }

      // --- STRATEGY 2: Modern Browser File System Access API ---
      if (typeof window.showSaveFilePicker === 'function' && !window.pywebview) {
        try {
          const handle = await window.showSaveFilePicker({
            suggestedName: filename,
            types: [{
              description: 'Microsoft Excel Workbook (*.xlsx)',
              accept: { 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'] }
            }]
          });
          const writable = await handle.createWritable();
          await writable.write(blob);
          await writable.close();
          showToast(`✓ Excel saved: ${filename}`);
          return;
        } catch (err) {
          if (err.name === 'AbortError') {
            showToast('Save cancelled.', 'warning');
            return;
          }
          console.warn('showSaveFilePicker fallback:', err);
        }
      }

      // --- STRATEGY 3: Local Backend Direct Save to PC Downloads Folder ---
      try {
        const diskRes = await fetch(`${API_URL}/reports/save-to-disk`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...authHeaders()
          },
          body: JSON.stringify({
            filename: filename,
            content: b64Data,
            is_base64: true
          })
        });
        if (diskRes.ok) {
          const diskJson = await diskRes.json();
          if (diskJson.success && diskJson.data && diskJson.data.saved_path) {
            showToast(`✓ Excel saved to PC: ${diskJson.data.saved_path}`);
            return;
          }
        }
      } catch (diskErr) {
        console.warn('Direct disk save error:', diskErr);
      }

      // --- STRATEGY 4: Browser Blob Anchor Download Fallback ---
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
      showToast(`✓ Excel Downloaded: ${filename}`);
    } else {
      // CSV Export
      const csvText = await res.text();

      // --- STRATEGY 1: Desktop App PyWebView Native Windows "Save As" Dialog ---
      if (window.pywebview && window.pywebview.api && typeof window.pywebview.api.save_file_dialog === 'function') {
        try {
          const dialogRes = await window.pywebview.api.save_file_dialog(filename, csvText);
          if (dialogRes && dialogRes.cancelled) {
            showToast('Export save cancelled.', 'warning');
            return;
          }
          if (dialogRes && dialogRes.success) {
            showToast(`✓ CSV saved to: ${dialogRes.saved_path}`);
            return;
          }
        } catch (err) {
          console.warn('PyWebView save dialog error:', err);
        }
      }

      // --- STRATEGY 2: Browser File System Access API ---
      if (typeof window.showSaveFilePicker === 'function' && !window.pywebview) {
        try {
          const handle = await window.showSaveFilePicker({
            suggestedName: filename,
            types: [{
              description: 'CSV Spreadsheet (*.csv)',
              accept: { 'text/csv': ['.csv'] }
            }]
          });
          const writable = await handle.createWritable();
          await writable.write(csvText);
          await writable.close();
          showToast(`✓ Saved: ${filename}`);
          return;
        } catch (err) {
          if (err.name === 'AbortError') {
            showToast('Save cancelled.', 'warning');
            return;
          }
          console.warn('showSaveFilePicker fallback:', err);
        }
      }

      // --- STRATEGY 3: Local Backend Direct Save to PC Downloads Folder ---
      try {
        const diskRes = await fetch(`${API_URL}/reports/save-to-disk`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...authHeaders()
          },
          body: JSON.stringify({
            filename: filename,
            content: csvText,
            is_base64: false
          })
        });
        if (diskRes.ok) {
          const diskJson = await diskRes.json();
          if (diskJson.success && diskJson.data && diskJson.data.saved_path) {
            showToast(`✓ Saved to PC: ${diskJson.data.saved_path}`);
            return;
          }
        }
      } catch (diskErr) {
        console.warn('Direct disk save error:', diskErr);
      }

      // --- STRATEGY 4: Browser Blob Anchor Download Fallback ---
      const blob = new Blob([csvText], { type: 'text/csv;charset=utf-8;' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
      showToast(`✓ Downloaded: ${filename}`);
    }
  } catch (err) {
    console.error('Download report failed:', err);
    showToast('Download error', 'error');
  }
}

// Backwards-compatible wrapper so all existing buttons export Excel (.xlsx) by default
async function downloadCsvReport(type, params = {}) {
  return downloadReport(type, params, 'excel');
}

async function loadReportsData() {
  try {
    const res = await fetch(`${API_URL}/reports/events`, { headers: authHeaders() });
    const data = await res.json();
    const events = data.data || [];

    const container = document.getElementById('reportsContainer');
    if (!container) return;

    if (events.length === 0) {
      container.innerHTML = `<p style="padding: 20px; text-align: center; color: var(--text-gray); font-style: italic;">No events available for reporting.</p>`;
      return;
    }

    container.innerHTML = `
      <table style="width: 100%; border-collapse: collapse; font-size: 13px; text-align: left;">
        <thead style="background: var(--surface-gray); color: var(--primary-navy);">
          <tr>
            <th style="padding: 12px;">Event UID</th>
            <th style="padding: 12px;">Event Name</th>
            <th style="padding: 12px;">Type</th>
            <th style="padding: 12px;">Date</th>
            <th style="padding: 12px;">Total Items</th>
            <th style="padding: 12px;">Distributed</th>
            <th style="padding: 12px;">Remaining</th>
            <th style="padding: 12px;">Completion</th>
            <th style="padding: 12px; text-align: right;">Action</th>
          </tr>
        </thead>
        <tbody>
          ${events.map(ev => `
            <tr style="border-bottom: 1px solid var(--border-subtle); transition: background 0.2s;">
              <td style="padding: 12px;">
                <a href="javascript:void(0)" onclick="openEventReportDetailModal(${ev.event_id})" class="table-click-link" title="Click to view event report & distribution list">
                  ${ev.event_uid} <i class="fa-solid fa-arrow-up-right-from-square" style="font-size: 10px;"></i>
                </a>
              </td>
              <td style="padding: 12px; font-weight: 600;">
                <a href="javascript:void(0)" onclick="openEventReportDetailModal(${ev.event_id})" class="table-click-link" style="color: var(--primary-navy);" title="Click to view event report">
                  ${ev.event_name}
                </a>
              </td>
              <td style="padding: 12px;">${ev.event_type}</td>
              <td style="padding: 12px;">${ev.event_date}</td>
              <td style="padding: 12px; font-weight: 600;">${ev.total_quantity}</td>
              <td style="padding: 12px; color: var(--status-green); font-weight: bold;">${ev.distributed_quantity}</td>
              <td style="padding: 12px; font-weight: bold; color: var(--primary-orange);">${ev.remaining_quantity}</td>
              <td style="padding: 12px;"><span class="badge badge-active">${ev.completion_percentage}%</span></td>
              <td style="padding: 12px; text-align: right;">
                <button class="btn-secondary" onclick="downloadCsvReport('event_detail', { event_id: ${ev.event_id} })" style="padding: 5px 10px; font-size: 11px;" title="Download Specific Report for ${ev.event_name}">
                  <i class="fa-solid fa-download"></i> CSV
                </button>
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  } catch (err) {
    console.error('Failed to load reports:', err);
  }
}

async function loadMasterInventoryReports() {
  try {
    const res = await fetch(`${API_URL}/reports/inventory-master`, { headers: authHeaders() });
    const data = await res.json();
    const items = data.data || [];

    const container = document.getElementById('masterReportsContainer');
    if (!container) return;

    if (items.length === 0) {
      container.innerHTML = `<p style="padding: 20px; text-align: center; color: var(--text-gray); font-style: italic;">No master inventory items found in database.</p>`;
      return;
    }

    container.innerHTML = `
      <table style="width: 100%; border-collapse: collapse; font-size: 13px; text-align: left;">
        <thead style="background: var(--surface-gray); color: var(--primary-navy);">
          <tr>
            <th style="padding: 12px;">Item</th>
            <th style="padding: 12px;">Category</th>
            <th style="padding: 12px;">Unit</th>
            <th style="padding: 12px;">Initial Stock</th>
            <th style="padding: 12px;">Allocated to Events</th>
            <th style="padding: 12px;">Distributed</th>
            <th style="padding: 12px;">Master Remaining</th>
            <th style="padding: 12px;">Status</th>
            <th style="padding: 12px; text-align: right;">Action</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(i => {
      const statusClass = i.status === 'In Stock' ? 'badge-completed' : (i.status === 'Low Stock' ? 'badge-low' : 'badge-out');
      return `
            <tr style="border-bottom: 1px solid var(--border-subtle); transition: background 0.2s;">
              <td style="padding: 12px;">
                <div style="display: flex; align-items: center; gap: 10px;">
                  <div style="width: 34px; height: 34px; border-radius: 8px; background: rgba(244, 123, 32, 0.1); display: flex; align-items: center; justify-content: center; overflow: hidden; flex-shrink: 0; border: 1px solid var(--border-subtle);">
                    ${i.image_url ?
          `<img src="${i.image_url}" alt="${i.name}" style="width: 100%; height: 100%; object-fit: cover;">` :
          `<i class="fa-solid fa-box" style="color: var(--primary-orange); font-size: 15px;"></i>`
        }
                  </div>
                  <div>
                    <a href="javascript:void(0)" onclick="openItemReportDetailModal(${i.id})" class="table-click-link" title="Click to view detailed item report & distributions">
                      ${i.name} <i class="fa-solid fa-arrow-up-right-from-square" style="font-size: 10px;"></i>
                    </a>
                  </div>
                </div>
              </td>
              <td style="padding: 12px;">${i.category}</td>
              <td style="padding: 12px;">${i.unit}</td>
              <td style="padding: 12px; font-weight: 600;">${i.initial_stock}</td>
              <td style="padding: 12px; font-weight: 600; color: var(--primary-navy);">${i.total_allocated}</td>
              <td style="padding: 12px; color: var(--status-green); font-weight: bold;">${i.total_distributed}</td>
              <td style="padding: 12px; font-weight: bold; color: var(--primary-orange);">${i.total_remaining}</td>
              <td style="padding: 12px;"><span class="badge ${statusClass}">${i.status}</span></td>
              <td style="padding: 12px; text-align: right;">
                <button class="btn-secondary" onclick="downloadCsvReport('item_detail', { inventory_item_id: ${i.id} })" style="padding: 5px 10px; font-size: 11px;" title="Download Specific Report for ${i.name}">
                  <i class="fa-solid fa-download"></i> CSV
                </button>
              </td>
            </tr>
            `;
    }).join('')}
        </tbody>
      </table>
    `;
  } catch (err) {
    console.error('Failed to load master inventory reports:', err);
  }
}

// ---------------- REPORT DETAIL DRILLDOWN MODALS ----------------
async function openEventReportDetailModal(eventId) {
  try {
    const res = await fetch(`${API_URL}/reports/event/${eventId}/detail`, { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok || !data.success) {
      showToast('Could not load event report details', 'error');
      return;
    }
    const d = data.data;

    document.getElementById('evRepModalTitle').textContent = d.event_name;
    document.getElementById('evRepModalSubtitle').textContent = `${d.event_uid} • ${d.event_type} • ${d.event_date} • Scheme: ${d.semester_scheme}`;

    // Download button handler
    const dlBtn = document.getElementById('evRepModalDownloadBtn');
    dlBtn.onclick = () => downloadCsvReport('event_detail', { event_id: d.event_id });

    // Stats strip
    document.getElementById('evRepStatsStrip').innerHTML = `
      <div style="background: var(--surface-gray); padding: 10px 14px; border-radius: 10px; text-align: center;">
        <div style="font-size: 11px; color: var(--text-gray);">Total Allocated</div>
        <div style="font-size: 18px; font-weight: bold; color: var(--primary-navy);">${d.total_items} units</div>
      </div>
      <div style="background: rgba(16, 185, 129, 0.08); padding: 10px 14px; border-radius: 10px; text-align: center; border: 1px solid rgba(16, 185, 129, 0.2);">
        <div style="font-size: 11px; color: var(--status-green);">Distributed</div>
        <div style="font-size: 18px; font-weight: bold; color: var(--status-green);">${d.distributed_items} units</div>
      </div>
      <div style="background: rgba(244, 123, 32, 0.08); padding: 10px 14px; border-radius: 10px; text-align: center; border: 1px solid rgba(244, 123, 32, 0.2);">
        <div style="font-size: 11px; color: var(--primary-orange);">Remaining</div>
        <div style="font-size: 18px; font-weight: bold; color: var(--primary-orange);">${d.remaining_items} units</div>
      </div>
      <div style="background: var(--surface-gray); padding: 10px 14px; border-radius: 10px; text-align: center;">
        <div style="font-size: 11px; color: var(--text-gray);">Completion</div>
        <div style="font-size: 18px; font-weight: bold; color: var(--primary-navy);">${d.completion_percentage}%</div>
      </div>
    `;

    // Items list
    const itemsContainer = document.getElementById('evRepItemsContainer');
    if (d.items.length === 0) {
      itemsContainer.innerHTML = `<p style="font-size: 12px; color: var(--text-gray); font-style: italic;">No inventory items allocated to this event.</p>`;
    } else {
      itemsContainer.innerHTML = `
        <table style="width: 100%; border-collapse: collapse; font-size: 12px; text-align: left;">
          <thead style="background: var(--surface-gray); color: var(--primary-navy);">
            <tr>
              <th style="padding: 8px;">Item</th>
              <th style="padding: 8px;">Category</th>
              <th style="padding: 8px;">Allocated</th>
              <th style="padding: 8px;">Distributed</th>
              <th style="padding: 8px;">Remaining</th>
              <th style="padding: 8px;">Eligibility</th>
            </tr>
          </thead>
          <tbody>
            ${d.items.map(it => `
              <tr style="border-bottom: 1px solid var(--border-subtle);">
                <td style="padding: 8px; font-weight: 600; display: flex; align-items: center; gap: 8px;">
                  ${it.image_url ?
          `<img src="${it.image_url}" style="width: 26px; height: 26px; border-radius: 6px; object-fit: cover; border: 1px solid var(--border-subtle);">` :
          `<i class="fa-solid fa-box" style="color: var(--primary-orange);"></i>`
        }
                  <span>${it.item_name}</span>
                </td>
                <td style="padding: 8px;">${it.category}</td>
                <td style="padding: 8px; font-weight: 600;">${it.initial_quantity}</td>
                <td style="padding: 8px; color: var(--status-green); font-weight: bold;">${it.distributed_quantity}</td>
                <td style="padding: 8px; font-weight: bold; color: var(--primary-orange);">${it.remaining_quantity}</td>
                <td style="padding: 8px;"><span class="badge badge-active">${it.eligibility_type}</span></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `;
    }

    // Distributions list
    const distsContainer = document.getElementById('evRepDistsContainer');
    if (d.distributions.length === 0) {
      distsContainer.innerHTML = `<p style="font-size: 12px; color: var(--text-gray); font-style: italic; padding: 8px 0;">No reward distributions recorded yet for this event.</p>`;
    } else {
      distsContainer.innerHTML = `
        <table style="width: 100%; border-collapse: collapse; font-size: 12px; text-align: left;">
          <thead style="background: var(--surface-gray); color: var(--primary-navy);">
            <tr>
              <th style="padding: 8px;">Student ID</th>
              <th style="padding: 8px;">Roll No</th>
              <th style="padding: 8px;">Name</th>
              <th style="padding: 8px;">Item</th>
              <th style="padding: 8px;">Qty</th>
              <th style="padding: 8px;">Distributed At</th>
              <th style="padding: 8px;">Issued By</th>
            </tr>
          </thead>
          <tbody>
            ${d.distributions.map(dist => `
              <tr style="border-bottom: 1px solid var(--border-subtle);">
                <td style="padding: 8px; font-weight: 600; color: var(--primary-orange);">${dist.student_id}</td>
                <td style="padding: 8px;">${dist.roll_number}</td>
                <td style="padding: 8px; font-weight: 600;">${dist.student_name} (Sem ${dist.semester})</td>
                <td style="padding: 8px;">${dist.item_name}</td>
                <td style="padding: 8px; font-weight: bold;">${dist.quantity}</td>
                <td style="padding: 8px; color: var(--text-gray);">${dist.distributed_at}</td>
                <td style="padding: 8px; font-size: 11px;">${dist.distributed_by}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `;
    }

    document.getElementById('eventReportDetailModal').classList.add('active');
  } catch (err) {
    console.error('Failed to open event report detail:', err);
    showToast('Failed to load event report', 'error');
  }
}

async function openItemReportDetailModal(itemId) {
  try {
    const res = await fetch(`${API_URL}/reports/inventory/${itemId}/detail`, { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok || !data.success) {
      showToast('Could not load item report details', 'error');
      return;
    }
    const d = data.data;

    document.getElementById('itemRepModalTitle').textContent = d.name;
    document.getElementById('itemRepModalSubtitle').textContent = `${d.category} • Unit: ${d.unit} • Initial Catalog Units: ${d.initial_stock}`;

    // Update photo box
    const photoBox = document.getElementById('itemRepPhotoBox');
    if (d.image_url) {
      photoBox.innerHTML = `<img src="${d.image_url}" style="width: 100%; height: 100%; object-fit: cover;">`;
    } else {
      photoBox.innerHTML = `<i class="fa-solid fa-box-open" style="font-size: 20px;"></i>`;
    }

    // Download button
    const dlBtn = document.getElementById('itemRepModalDownloadBtn');
    dlBtn.onclick = () => downloadCsvReport('item_detail', { inventory_item_id: d.id });

    // Stats strip
    document.getElementById('itemRepStatsStrip').innerHTML = `
      <div style="background: var(--surface-gray); padding: 10px 14px; border-radius: 10px; text-align: center;">
        <div style="font-size: 11px; color: var(--text-gray);">Master Stock</div>
        <div style="font-size: 18px; font-weight: bold; color: var(--primary-navy);">${d.initial_stock}</div>
      </div>
      <div style="background: rgba(15, 43, 91, 0.08); padding: 10px 14px; border-radius: 10px; text-align: center;">
        <div style="font-size: 11px; color: var(--primary-navy);">Allocated to Events</div>
        <div style="font-size: 18px; font-weight: bold; color: var(--primary-navy);">${d.total_allocated}</div>
      </div>
      <div style="background: rgba(16, 185, 129, 0.08); padding: 10px 14px; border-radius: 10px; text-align: center; border: 1px solid rgba(16, 185, 129, 0.2);">
        <div style="font-size: 11px; color: var(--status-green);">Distributed</div>
        <div style="font-size: 18px; font-weight: bold; color: var(--status-green);">${d.total_distributed}</div>
      </div>
      <div style="background: rgba(244, 123, 32, 0.08); padding: 10px 14px; border-radius: 10px; text-align: center; border: 1px solid rgba(244, 123, 32, 0.2);">
        <div style="font-size: 11px; color: var(--primary-orange);">Master Remaining</div>
        <div style="font-size: 18px; font-weight: bold; color: var(--primary-orange);">${d.total_remaining}</div>
      </div>
    `;

    // Events breakdown
    const eventsContainer = document.getElementById('itemRepEventsContainer');
    if (d.events.length === 0) {
      eventsContainer.innerHTML = `<p style="font-size: 12px; color: var(--text-gray); font-style: italic;">This item is currently retained solely in Master Inventory (not yet assigned to any events).</p>`;
    } else {
      eventsContainer.innerHTML = `
        <table style="width: 100%; border-collapse: collapse; font-size: 12px; text-align: left;">
          <thead style="background: var(--surface-gray); color: var(--primary-navy);">
            <tr>
              <th style="padding: 8px;">Event UID</th>
              <th style="padding: 8px;">Event Name</th>
              <th style="padding: 8px;">Date</th>
              <th style="padding: 8px;">Allocated</th>
              <th style="padding: 8px;">Distributed</th>
              <th style="padding: 8px;">Remaining</th>
            </tr>
          </thead>
          <tbody>
            ${d.events.map(ev => `
              <tr style="border-bottom: 1px solid var(--border-subtle);">
                <td style="padding: 8px; font-weight: 600; color: var(--primary-orange);">${ev.event_uid}</td>
                <td style="padding: 8px; font-weight: 600;">${ev.event_name}</td>
                <td style="padding: 8px;">${ev.event_date}</td>
                <td style="padding: 8px; font-weight: bold;">${ev.initial_quantity}</td>
                <td style="padding: 8px; color: var(--status-green); font-weight: bold;">${ev.distributed_quantity}</td>
                <td style="padding: 8px; color: var(--primary-orange); font-weight: bold;">${ev.remaining_quantity}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `;
    }

    // Distributions history
    const distsContainer = document.getElementById('itemRepDistsContainer');
    if (d.distributions.length === 0) {
      distsContainer.innerHTML = `<p style="font-size: 12px; color: var(--text-gray); font-style: italic; padding: 8px 0;">No distributions recorded yet for this item.</p>`;
    } else {
      distsContainer.innerHTML = `
        <table style="width: 100%; border-collapse: collapse; font-size: 12px; text-align: left;">
          <thead style="background: var(--surface-gray); color: var(--primary-navy);">
            <tr>
              <th style="padding: 8px;">Student ID</th>
              <th style="padding: 8px;">Roll No</th>
              <th style="padding: 8px;">Student Name</th>
              <th style="padding: 8px;">Event</th>
              <th style="padding: 8px;">Qty</th>
              <th style="padding: 8px;">Distributed At</th>
              <th style="padding: 8px;">Issued By</th>
            </tr>
          </thead>
          <tbody>
            ${d.distributions.map(dist => `
              <tr style="border-bottom: 1px solid var(--border-subtle);">
                <td style="padding: 8px; font-weight: 600; color: var(--primary-orange);">${dist.student_id}</td>
                <td style="padding: 8px;">${dist.roll_number}</td>
                <td style="padding: 8px; font-weight: 600;">${dist.student_name}</td>
                <td style="padding: 8px;">${dist.event_name}</td>
                <td style="padding: 8px; font-weight: bold;">${dist.quantity}</td>
                <td style="padding: 8px; color: var(--text-gray);">${dist.distributed_at}</td>
                <td style="padding: 8px; font-size: 11px;">${dist.distributed_by}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `;
    }

    document.getElementById('itemReportDetailModal').classList.add('active');
  } catch (err) {
    console.error('Failed to open item report detail:', err);
    showToast('Failed to load item report', 'error');
  }
}

