// API Base URL (relative path since served by FastAPI backend)
const API_URL = '/api/v1';

let authToken = localStorage.getItem('s60_token') || null;
let currentAdmin = JSON.parse(localStorage.getItem('s60_admin') || 'null');
let currentSession = null;
let activeEventId = null;
let currentProfileStudentId = null;

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

function showSplash() {
  document.getElementById('splashView').style.display = 'flex';
  document.getElementById('appShell').style.display = 'none';
}

function switchAuthTab(tab) {
  const tabSignIn = document.getElementById('authTabSignIn');
  const tabSignUp = document.getElementById('authTabSignUp');
  const panelSignIn = document.getElementById('authPanelSignIn');
  const panelSignUp = document.getElementById('authPanelSignUp');

  if (tab === 'signin') {
    tabSignIn.style.background = 'var(--white)';
    tabSignIn.style.color = 'var(--primary-navy)';
    tabSignIn.style.boxShadow = '0 2px 6px rgba(0,0,0,0.06)';
    tabSignUp.style.background = 'transparent';
    tabSignUp.style.color = 'var(--text-gray)';
    tabSignUp.style.boxShadow = 'none';

    panelSignIn.style.display = 'block';
    panelSignUp.style.display = 'none';
  } else {
    tabSignUp.style.background = 'var(--white)';
    tabSignUp.style.color = 'var(--primary-navy)';
    tabSignUp.style.boxShadow = '0 2px 6px rgba(0,0,0,0.06)';
    tabSignIn.style.background = 'transparent';
    tabSignIn.style.color = 'var(--text-gray)';
    tabSignIn.style.boxShadow = 'none';

    panelSignUp.style.display = 'block';
    panelSignIn.style.display = 'none';
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
    if (roleEl) roleEl.textContent = (currentAdmin.role || 'COORDINATOR').replace('_', ' ');
  }
  loadDashboard();
}

function authHeaders() {
  return {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`
  };
}

function switchTab(tabName) {
  document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
  document.querySelectorAll('.nav-tab').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.mobile-nav-item').forEach(el => el.classList.remove('active'));

  const activeContent = document.getElementById(`tab-${tabName}`);
  if (activeContent) activeContent.style.display = 'block';

  // Desktop tab button
  const tabBtns = Array.from(document.querySelectorAll('.nav-tab'));
  const targetBtn = tabBtns.find(b => b.textContent.toLowerCase().includes(tabName));
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

// ---------------- DASHBOARD ----------------
async function loadDashboard() {
  try {
    const res = await fetch(`${API_URL}/dashboard`, { headers: authHeaders() });
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

    container.innerHTML = items.map(ev => `
      <div class="card" style="display: flex; flex-direction: column; justify-content: space-between;">
        <div>
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
            <span class="badge badge-active">${ev.event_uid}</span>
            <span class="badge ${ev.status === 'Active' ? 'badge-active' : (ev.status === 'Completed' ? 'badge-completed' : 'badge-upcoming')}">${ev.status}</span>
          </div>
          <h3 style="font-size: 16px; margin-bottom: 6px;">${ev.name}</h3>
          <p style="font-size: 12px; color: var(--text-gray); margin-bottom: 12px;">
            <i class="fa-solid fa-calendar"></i> ${ev.event_date} &nbsp;•&nbsp; 
            <i class="fa-solid fa-layer-group"></i> ${ev.semester_scheme} Sem (${ev.applicable_semesters.map(s => s + 'th').join(', ')})
          </p>
          <div style="font-size: 12px; color: var(--primary-navy); font-weight: 600; display: flex; justify-content: space-between; margin-bottom: 6px;">
            <span>${ev.total_inventory_items} Item Types</span>
            <span>${ev.distributed_quantity} / ${ev.total_quantity} Distributed</span>
          </div>
          <div class="progress-bar-bg" style="margin-bottom: 14px;">
            <div class="progress-bar-fill" style="width: ${ev.distribution_percentage}%;"></div>
          </div>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border-subtle); padding-top: 12px;">
          <span style="font-size: 12px; font-weight: 700; color: var(--primary-orange);">${ev.distribution_percentage}% Complete</span>
          <button class="btn-secondary" onclick="openEventDetails(${ev.id})" style="padding: 6px 14px; font-size: 12px;">
            View Event <i class="fa-solid fa-arrow-right"></i>
          </button>
        </div>
      </div>
    `).join('');

  } catch (err) {
    console.error('Failed to load events:', err);
  }
}

// ---------------- EVENT DETAILS MODAL ----------------
async function openEventDetails(eventId) {
  activeEventId = eventId;
  try {
    const res = await fetch(`${API_URL}/events/${eventId}`, { headers: authHeaders() });
    const result = await res.json();
    const ev = result.data;

    document.getElementById('evtDetUid').textContent = ev.event_uid;
    document.getElementById('evtDetName').textContent = ev.name;
    document.getElementById('evtDetDesc').textContent = ev.description || 'No description provided.';
    document.getElementById('evtDetDate').textContent = `${ev.event_date} (${ev.event_time || 'All Day'})`;
    document.getElementById('evtDetVenue').textContent = ev.venue || 'SVIET Campus';
    document.getElementById('evtDetSemesters').textContent = `${ev.semester_scheme} Scheme (${ev.applicable_semesters.map(s => s + 'th').join(', ')})`;

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

    document.getElementById('eventDetailModal').classList.add('active');
  } catch (err) {
    showToast('Failed to load event details', 'error');
  }
}

function goToEventDistribution() {
  closeModal('eventDetailModal');
  switchTab('distribution');
  setTimeout(() => {
    document.getElementById('distEventSelect').value = activeEventId;
    loadDistributionMatrix();
  }, 200);
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

// ---------------- CREATE EVENT ----------------
function openCreateEventModal() {
  updateEventModalSemesters();
  document.getElementById('createEventModal').classList.add('active');
}

function updateEventModalSemesters() {
  const scheme = document.getElementById('evScheme').value;
  const container = document.getElementById('evSemestersCheckboxes');
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
    `;
  }
}

async function handleCreateEvent(e) {
  e.preventDefault();
  const name = document.getElementById('evName').value.trim();
  const type = document.getElementById('evType').value;
  const date = document.getElementById('evDate').value.trim();
  const time = document.getElementById('evTime').value.trim();
  const venue = document.getElementById('evVenue').value.trim();
  const scheme = document.getElementById('evScheme').value;
  const desc = document.getElementById('evDesc').value.trim();

  const checkedBoxes = Array.from(document.querySelectorAll('input[name="evSem"]:checked'));
  if (checkedBoxes.length === 0) {
    showToast('Please select at least one semester (e.g. 3rd, 5th, 7th)', 'error');
    return;
  }
  const semesters = checkedBoxes.map(cb => parseInt(cb.value));

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
        description: desc,
        status: 'Upcoming'
      })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`Event '${data.data.name}' (${data.data.event_uid}) created!`);
      closeModal('createEventModal');
      loadSavedEvents();
      loadDashboard();
    } else {
      showToast(data.detail || data.message || 'Creation failed', 'error');
    }
  } catch (err) {
    showToast('Failed to create event', 'error');
  }
}

// ---------------- EVENT ITEM ALLOCATION ----------------
async function openAddEventItemModal() {
  if (!activeEventId) {
    showToast('No active event selected', 'error');
    return;
  }
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
    document.getElementById('addEventItemModal').classList.add('active');
  } catch (err) {
    showToast('Failed to load inventory catalog', 'error');
  }
}

async function handleAllocateEventInventory(e) {
  e.preventDefault();
  if (!activeEventId) return;
  const inventory_item_id = parseInt(document.getElementById('allocItemSelect').value);
  const initial_quantity = parseInt(document.getElementById('allocQty').value);
  const eligibility_type = document.getElementById('allocEligibility').value;

  try {
    const res = await fetch(`${API_URL}/events/${activeEventId}/inventory`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        inventory_item_id,
        initial_quantity,
        eligibility_type
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
async function loadDistributionEventsDropdown() {
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

    select.innerHTML = events.map(ev => `
      <option value="${ev.id}" ${activeEventId === ev.id ? 'selected' : ''}>${ev.event_uid} • ${ev.name}</option>
    `).join('');

    if (!activeEventId || !events.some(ev => ev.id === activeEventId)) {
      activeEventId = events[0].id;
      select.value = activeEventId;
    }
    loadDistributionMatrix();
  } catch (err) {
    console.error('Failed to load events for distribution:', err);
  }
}

async function loadDistributionMatrix() {
  const eventId = document.getElementById('distEventSelect').value;
  if (!eventId) return;
  activeEventId = eventId;
  const search = document.getElementById('distStudentSearch').value.trim();
  const semester = document.getElementById('distSemesterFilter').value;
  const status = document.getElementById('distStatusFilter').value;

  const params = new URLSearchParams();
  if (search) params.append('search', search);
  if (semester) params.append('semester', semester);
  if (status !== 'ALL') params.append('status_filter', status);

  try {
    const res = await fetch(`${API_URL}/distribution/event/${eventId}/matrix?${params.toString()}`, { headers: authHeaders() });
    const result = await res.json();
    const d = result.data;

    document.getElementById('distSummaryText').textContent = `Total Students: ${d.total_students} | Distributed: ${d.summary.total_distributed_items} / ${d.summary.total_eligible_items}`;
    document.getElementById('distCompletionRate').textContent = `${d.summary.completion_rate}% Complete`;

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
        return `
          <div style="display: flex; justify-content: space-between; align-items: center; background: var(--surface-gray); padding: 8px 12px; border-radius: 8px; margin-top: 6px;">
            <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 13px; font-weight: ${item.received ? '700' : '500'}; color: ${item.received ? 'var(--primary-navy)' : 'var(--text-gray)'};">
              <input type="checkbox" ${item.received ? 'checked disabled' : ''} onchange="confirmDistribution(${row.student_id}, ${invId}, '${row.name}', '${item.item_name}')">
              <span>${item.item_name}</span>
            </label>
            <div>
              ${item.received
                ? `<button class="btn-danger" style="padding: 2px 8px; font-size: 11px;" onclick="undoDistribution(${item.distribution_id}, '${row.name}', '${item.item_name}')"><i class="fa-solid fa-undo"></i> Undo</button>`
                : `<span style="font-size: 11px; color: var(--text-gray);">${item.remaining_stock} available</span>`
              }
            </div>
          </div>
        `;
      }).join('');

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
            ${itemsHtml}
          </div>
        </div>
      `;
    }).join('');

  } catch (err) {
    console.error('Failed to load matrix:', err);
  }
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

// ---------------- MASTER INVENTORY ----------------
function openAddMasterItemModal() {
  document.getElementById('masterItemName').value = '';
  document.getElementById('masterItemDesc').value = '';
  document.getElementById('addMasterItemModal').classList.add('active');
}

async function handleCreateMasterItem(e) {
  e.preventDefault();
  const name = document.getElementById('masterItemName').value.trim();
  const category = document.getElementById('masterItemCategory').value;
  const unit = document.getElementById('masterItemUnit').value.trim() || 'units';
  const description = document.getElementById('masterItemDesc').value.trim();

  try {
    const res = await fetch(`${API_URL}/inventory`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ name, category, unit, description })
    });
    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`Added item '${data.data.name}' to catalog!`);
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

async function loadMasterInventory() {
  try {
    const res = await fetch(`${API_URL}/inventory`, { headers: authHeaders() });
    const data = await res.json();
    const items = data.data || [];

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

    container.innerHTML = items.map(item => `
      <div class="card">
        <div style="display: flex; gap: 14px; align-items: flex-start;">
          <div style="width: 44px; height: 44px; border-radius: 12px; background: rgba(244, 123, 32, 0.12); display: flex; align-items: center; justify-content: center;">
            <i class="fa-solid fa-box" style="color: var(--primary-orange); font-size: 20px;"></i>
          </div>
          <div style="flex: 1;">
            <h3 style="font-size: 16px;">${item.name}</h3>
            <p style="font-size: 12px; color: var(--text-gray);">${item.category} • ${item.events_count} Events Linked</p>
            <div style="margin-top: 12px; display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; text-align: center; background: var(--surface-gray); padding: 8px; border-radius: 10px;">
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
        </div>
      </div>
    `).join('');
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

  try {
    const res = await fetch(`${API_URL}/students?${params.toString()}`, { headers: authHeaders() });
    const data = await res.json();
    const students = data.data.items || [];

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

// ---------------- REPORTS & CSV EXPORT ----------------
async function loadReportsData() {
  try {
    const res = await fetch(`${API_URL}/reports/events`, { headers: authHeaders() });
    const data = await res.json();
    const events = data.data || [];

    const container = document.getElementById('reportsContainer');
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
          </tr>
        </thead>
        <tbody>
          ${events.map(ev => `
            <tr style="border-bottom: 1px solid var(--border-subtle);">
              <td style="padding: 12px; font-weight: bold; color: var(--primary-orange);">${ev.event_uid}</td>
              <td style="padding: 12px; font-weight: 600;">${ev.event_name}</td>
              <td style="padding: 12px;">${ev.event_type}</td>
              <td style="padding: 12px;">${ev.event_date}</td>
              <td style="padding: 12px;">${ev.total_quantity}</td>
              <td style="padding: 12px; color: var(--status-green); font-weight: bold;">${ev.distributed_quantity}</td>
              <td style="padding: 12px; font-weight: bold;">${ev.remaining_quantity}</td>
              <td style="padding: 12px;"><span class="badge badge-active">${ev.completion_percentage}%</span></td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  } catch (err) {
    console.error('Failed to load reports:', err);
  }
}

function downloadCsvReport(type) {
  window.open(`${API_URL}/reports/export-csv?report_type=${type}`, '_blank');
}
