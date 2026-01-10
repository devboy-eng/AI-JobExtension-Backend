# Chrome Extension Frontend Implementation Guide

## 🔄 Complete Integration Flow

Your Rails backend at `http://localhost:3000` is fully ready. Here's how to build the Chrome extension frontend:

### 1. Project Structure

```
chrome-extension/
├── manifest.json
├── popup.html
├── popup.js
├── content.js
├── background.js
├── styles.css
├── api/
│   └── api.js
└── components/
    ├── auth.js
    ├── payment.js
    ├── resume-builder.js
    └── job-parser.js
```

### 2. Manifest Configuration

```json
{
  "manifest_version": 3,
  "name": "AI Job Extension",
  "version": "1.0.0",
  "description": "AI-powered resume customization for job applications",
  "permissions": [
    "storage",
    "activeTab",
    "scripting",
    "tabs"
  ],
  "host_permissions": [
    "https://*.linkedin.com/*",
    "https://*.indeed.com/*",
    "https://*.naukri.com/*",
    "https://*.glassdoor.com/*",
    "http://localhost:3000/*"
  ],
  "action": {
    "default_popup": "popup.html",
    "default_title": "AI Job Extension"
  },
  "content_scripts": [
    {
      "matches": [
        "https://*.linkedin.com/*",
        "https://*.indeed.com/*",
        "https://*.naukri.com/*"
      ],
      "js": ["content.js"]
    }
  ],
  "background": {
    "service_worker": "background.js"
  },
  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self';"
  }
}
```

### 3. API Service (api/api.js)

```javascript
class JobExtensionAPI {
  constructor() {
    this.baseURL = 'http://localhost:3000/api';
    this.token = null;
  }

  async setToken(token) {
    this.token = token;
    await chrome.storage.local.set({ authToken: token });
  }

  async getToken() {
    if (!this.token) {
      const result = await chrome.storage.local.get(['authToken']);
      this.token = result.authToken;
    }
    return this.token;
  }

  async request(endpoint, options = {}) {
    const token = await this.getToken();
    const url = `${this.baseURL}${endpoint}`;

    const defaultOptions = {
      headers: {
        'Content-Type': 'application/json',
        ...(token && { 'Authorization': `Bearer ${token}` })
      }
    };

    const response = await fetch(url, { ...defaultOptions, ...options });

    if (!response.ok) {
      throw new Error(`API Error: ${response.status}`);
    }

    return response.json();
  }

  // Auth methods
  async login(email, password = 'temp123') {
    const data = await this.request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password })
    });

    if (data.success && data.token) {
      await this.setToken(data.token);
    }

    return data;
  }

  async getProfile() {
    return this.request('/profile');
  }

  async updateProfile(profileData) {
    return this.request('/profile', {
      method: 'POST',
      body: JSON.stringify(profileData)
    });
  }

  // Coins methods
  async getCoinBalance() {
    return this.request('/coins/balance');
  }

  // Payment methods
  async createPaymentOrder(amount) {
    return this.request('/payments/create-order', {
      method: 'POST',
      body: JSON.stringify({ amount })
    });
  }

  async verifyPayment(paymentData) {
    return this.request('/payments/verify', {
      method: 'POST',
      body: JSON.stringify(paymentData)
    });
  }

  // Resume methods
  async parseResume(fileData) {
    return this.request('/parse-resume', {
      method: 'POST',
      body: JSON.stringify({ fileData })
    });
  }

  async customizeResume(jobData, profileData) {
    return this.request('/ai/customize', {
      method: 'POST',
      body: JSON.stringify({ jobData, profileData })
    });
  }

  async getCustomizationHistory() {
    return this.request('/customization-history');
  }

  async downloadPDF(htmlContent) {
    const response = await this.request('/download/pdf', {
      method: 'POST',
      body: JSON.stringify({ htmlContent })
    });
    return response;
  }
}

// Export for use in other files
window.JobExtensionAPI = JobExtensionAPI;
```

### 4. Payment Integration (components/payment.js)

```javascript
class PaymentManager {
  constructor(api) {
    this.api = api;
  }

  async loadRazorpayScript() {
    return new Promise((resolve) => {
      if (window.Razorpay) {
        resolve(true);
        return;
      }

      const script = document.createElement('script');
      script.src = 'https://checkout.razorpay.com/v1/checkout.js';
      script.onload = () => resolve(true);
      script.onerror = () => resolve(false);
      document.head.appendChild(script);
    });
  }

  async buyCoins(amount) {
    try {
      // Load Razorpay script
      const scriptLoaded = await this.loadRazorpayScript();
      if (!scriptLoaded) {
        throw new Error('Failed to load payment gateway');
      }

      // Create order
      const orderResponse = await this.api.createPaymentOrder(amount);
      if (!orderResponse.success) {
        throw new Error('Failed to create payment order');
      }

      const order = orderResponse.order;

      // Open Razorpay checkout
      return new Promise((resolve, reject) => {
        const options = {
          key: order.key_id,
          amount: order.amount,
          currency: order.currency,
          name: order.name,
          description: order.description,
          order_id: order.id,
          prefill: order.prefill,
          theme: order.theme,
          handler: async (response) => {
            try {
              // Verify payment
              const verification = await this.api.verifyPayment({
                razorpay_order_id: response.razorpay_order_id,
                razorpay_payment_id: response.razorpay_payment_id,
                razorpay_signature: response.razorpay_signature
              });

              resolve(verification);
            } catch (error) {
              reject(error);
            }
          },
          modal: {
            ondismiss: () => {
              reject(new Error('Payment cancelled'));
            }
          }
        };

        const razorpay = new window.Razorpay(options);
        razorpay.open();
      });

    } catch (error) {
      console.error('Payment error:', error);
      throw error;
    }
  }
}

window.PaymentManager = PaymentManager;
```

### 5. Main Popup (popup.html)

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      width: 380px;
      min-height: 500px;
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }

    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 20px;
      text-align: center;
    }

    .balance {
      background: rgba(255,255,255,0.2);
      padding: 10px;
      border-radius: 8px;
      margin-top: 10px;
    }

    .content {
      padding: 20px;
    }

    .btn {
      background: #667eea;
      color: white;
      border: none;
      padding: 12px 20px;
      border-radius: 6px;
      cursor: pointer;
      width: 100%;
      margin: 8px 0;
      font-size: 14px;
    }

    .btn:hover {
      background: #5a6fd8;
    }

    .btn-secondary {
      background: #6c757d;
    }

    .coin-packages {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
      margin: 15px 0;
    }

    .coin-package {
      border: 1px solid #ddd;
      padding: 15px;
      border-radius: 8px;
      text-align: center;
      cursor: pointer;
      transition: all 0.2s;
    }

    .coin-package:hover {
      border-color: #667eea;
      background: #f8f9ff;
    }

    .hidden {
      display: none;
    }

    .loading {
      text-align: center;
      color: #666;
    }

    .error {
      color: #dc3545;
      background: #f8d7da;
      padding: 10px;
      border-radius: 4px;
      margin: 10px 0;
    }

    .success {
      color: #155724;
      background: #d4edda;
      padding: 10px;
      border-radius: 4px;
      margin: 10px 0;
    }
  </style>
</head>
<body>
  <div class="header">
    <h2>AI Job Extension</h2>
    <div id="balanceSection" class="balance hidden">
      <div>💰 <span id="coinBalance">0</span> Coins</div>
    </div>
  </div>

  <div class="content">
    <!-- Login Section -->
    <div id="loginSection">
      <h3>Sign In</h3>
      <input type="email" id="emailInput" placeholder="Email" style="width: 100%; padding: 10px; margin: 8px 0; border: 1px solid #ddd; border-radius: 4px;">
      <button class="btn" onclick="login()">Sign In</button>
      <div id="loginStatus"></div>
    </div>

    <!-- Main Dashboard -->
    <div id="dashboardSection" class="hidden">
      <!-- Resume Builder -->
      <div class="section">
        <h3>📄 Resume Builder</h3>
        <button class="btn" onclick="showJobForm()">Customize Resume for Job</button>
        <button class="btn btn-secondary" onclick="showHistory()">View History</button>
      </div>

      <!-- Buy Coins -->
      <div class="section">
        <h3>💰 Buy Coins</h3>
        <div class="coin-packages">
          <div class="coin-package" onclick="buyCoins(10)">
            <div><strong>100 Coins</strong></div>
            <div>₹10</div>
          </div>
          <div class="coin-package" onclick="buyCoins(50)">
            <div><strong>600 Coins</strong></div>
            <div>₹50</div>
            <small>20% Bonus</small>
          </div>
          <div class="coin-package" onclick="buyCoins(100)">
            <div><strong>1300 Coins</strong></div>
            <div>₹100</div>
            <small>30% Bonus</small>
          </div>
          <div class="coin-package" onclick="buyCoins(500)">
            <div><strong>7500 Coins</strong></div>
            <div>₹500</div>
            <small>50% Bonus</small>
          </div>
        </div>
      </div>
    </div>

    <!-- Job Form -->
    <div id="jobFormSection" class="hidden">
      <h3>Job Details</h3>
      <div id="autoDetectedJob" class="hidden">
        <div><strong>Auto-detected:</strong></div>
        <div id="detectedJobInfo"></div>
        <button class="btn" onclick="useDetectedJob()">Use This Job</button>
        <button class="btn btn-secondary" onclick="manualJobEntry()">Manual Entry</button>
      </div>

      <div id="manualJobForm">
        <input type="text" id="jobTitle" placeholder="Job Title" style="width: 100%; padding: 8px; margin: 5px 0; border: 1px solid #ddd; border-radius: 4px;">
        <input type="text" id="companyName" placeholder="Company Name" style="width: 100%; padding: 8px; margin: 5px 0; border: 1px solid #ddd; border-radius: 4px;">
        <textarea id="jobDescription" placeholder="Job Description..." style="width: 100%; height: 100px; padding: 8px; margin: 5px 0; border: 1px solid #ddd; border-radius: 4px;"></textarea>
        <button class="btn" onclick="generateResume()">Generate Resume (10 coins)</button>
        <button class="btn btn-secondary" onclick="backToDashboard()">Back</button>
      </div>
    </div>

    <!-- Status Messages -->
    <div id="statusMessage"></div>
  </div>

  <!-- Scripts -->
  <script src="api/api.js"></script>
  <script src="components/payment.js"></script>
  <script src="popup.js"></script>
</body>
</html>
```

### 6. Main Popup Logic (popup.js)

```javascript
// Initialize API and Payment Manager
const api = new JobExtensionAPI();
const paymentManager = new PaymentManager(api);

let currentUser = null;
let coinBalance = 0;

// Initialize popup
document.addEventListener('DOMContentLoaded', async () => {
  await checkAuthStatus();
  await detectCurrentJob();
});

// Authentication functions
async function checkAuthStatus() {
  try {
    const token = await api.getToken();
    if (token) {
      const profile = await api.getProfile();
      if (profile) {
        currentUser = profile;
        showDashboard();
        await updateCoinBalance();
      } else {
        showLogin();
      }
    } else {
      showLogin();
    }
  } catch (error) {
    console.error('Auth check failed:', error);
    showLogin();
  }
}

async function login() {
  const email = document.getElementById('emailInput').value.trim();
  if (!email) {
    showStatus('Please enter your email', 'error');
    return;
  }

  try {
    showStatus('Signing in...', 'loading');
    const result = await api.login(email);

    if (result.success) {
      currentUser = result.user;
      showStatus('Login successful!', 'success');
      showDashboard();
      await updateCoinBalance();
    } else {
      showStatus('Login failed: ' + result.message, 'error');
    }
  } catch (error) {
    console.error('Login error:', error);
    showStatus('Login failed. Please try again.', 'error');
  }
}

// UI Navigation
function showLogin() {
  document.getElementById('loginSection').classList.remove('hidden');
  document.getElementById('dashboardSection').classList.add('hidden');
  document.getElementById('jobFormSection').classList.add('hidden');
  document.getElementById('balanceSection').classList.add('hidden');
}

function showDashboard() {
  document.getElementById('loginSection').classList.add('hidden');
  document.getElementById('dashboardSection').classList.remove('hidden');
  document.getElementById('jobFormSection').classList.add('hidden');
  document.getElementById('balanceSection').classList.remove('hidden');
}

function showJobForm() {
  document.getElementById('dashboardSection').classList.add('hidden');
  document.getElementById('jobFormSection').classList.remove('hidden');
}

function backToDashboard() {
  document.getElementById('jobFormSection').classList.add('hidden');
  document.getElementById('dashboardSection').classList.remove('hidden');
}

// Coin Management
async function updateCoinBalance() {
  try {
    const balanceData = await api.getCoinBalance();
    if (balanceData.success) {
      coinBalance = balanceData.balance || 0;
      document.getElementById('coinBalance').textContent = coinBalance;
    }
  } catch (error) {
    console.error('Failed to update coin balance:', error);
  }
}

async function buyCoins(amount) {
  try {
    showStatus('Initiating payment...', 'loading');

    const paymentResult = await paymentManager.buyCoins(amount);

    if (paymentResult.success) {
      showStatus(`Success! ${paymentResult.coins_credited} coins added to your account.`, 'success');
      await updateCoinBalance();
    } else {
      showStatus('Payment verification failed.', 'error');
    }
  } catch (error) {
    console.error('Payment error:', error);
    showStatus('Payment failed: ' + error.message, 'error');
  }
}

// Job Detection
async function detectCurrentJob() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    if (tab && (tab.url.includes('linkedin.com') ||
               tab.url.includes('indeed.com') ||
               tab.url.includes('naukri.com'))) {

      // Inject content script to detect job details
      const results = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        function: extractJobDetails
      });

      if (results[0]?.result) {
        const jobData = results[0].result;
        displayAutoDetectedJob(jobData);
      }
    }
  } catch (error) {
    console.error('Job detection failed:', error);
  }
}

function extractJobDetails() {
  // This function runs in the context of the job website
  const jobData = {};

  if (window.location.hostname.includes('linkedin.com')) {
    jobData.title = document.querySelector('.top-card-layout__title')?.textContent?.trim();
    jobData.company = document.querySelector('.topcard__flavor-row .topcard__flavor--black-link')?.textContent?.trim();
    jobData.description = document.querySelector('.description__text')?.textContent?.trim();
  } else if (window.location.hostname.includes('indeed.com')) {
    jobData.title = document.querySelector('[data-testid="jobsearch-JobInfoHeader-title"] span')?.textContent?.trim();
    jobData.company = document.querySelector('[data-testid="inlineHeader-companyName"] a')?.textContent?.trim();
    jobData.description = document.querySelector('#jobDescriptionText')?.textContent?.trim();
  } else if (window.location.hostname.includes('naukri.com')) {
    jobData.title = document.querySelector('.jd-header-title')?.textContent?.trim();
    jobData.company = document.querySelector('.jd-header-comp-name')?.textContent?.trim();
    jobData.description = document.querySelector('.dang-inner-html')?.textContent?.trim();
  }

  return jobData.title ? jobData : null;
}

function displayAutoDetectedJob(jobData) {
  const autoSection = document.getElementById('autoDetectedJob');
  const jobInfo = document.getElementById('detectedJobInfo');

  jobInfo.innerHTML = `
    <div><strong>Title:</strong> ${jobData.title}</div>
    <div><strong>Company:</strong> ${jobData.company}</div>
  `;

  autoSection.classList.remove('hidden');

  // Store for later use
  window.detectedJobData = jobData;
}

function useDetectedJob() {
  const jobData = window.detectedJobData;
  document.getElementById('jobTitle').value = jobData.title || '';
  document.getElementById('companyName').value = jobData.company || '';
  document.getElementById('jobDescription').value = jobData.description || '';

  document.getElementById('autoDetectedJob').classList.add('hidden');
}

function manualJobEntry() {
  document.getElementById('autoDetectedJob').classList.add('hidden');
}

// Resume Generation
async function generateResume() {
  if (coinBalance < 10) {
    showStatus('Insufficient coins. Please buy coins first.', 'error');
    return;
  }

  const jobTitle = document.getElementById('jobTitle').value.trim();
  const company = document.getElementById('companyName').value.trim();
  const description = document.getElementById('jobDescription').value.trim();

  if (!jobTitle || !company || !description) {
    showStatus('Please fill in all job details.', 'error');
    return;
  }

  try {
    showStatus('Generating AI-optimized resume...', 'loading');

    // Get user profile
    const profile = await api.getProfile();

    const jobData = { title: jobTitle, company, description };
    const profileData = profile.profile_data || {};

    const result = await api.customizeResume(jobData, profileData);

    if (result.success) {
      showStatus('Resume generated successfully!', 'success');
      await updateCoinBalance(); // Refresh balance after coin deduction

      // Open resume in new tab or download
      showResumePreview(result.customizedContent);
    } else {
      showStatus('Failed to generate resume: ' + result.message, 'error');
    }
  } catch (error) {
    console.error('Resume generation error:', error);
    showStatus('Failed to generate resume. Please try again.', 'error');
  }
}

function showResumePreview(htmlContent) {
  // Open resume preview in new window
  const newWindow = window.open('', '_blank');
  newWindow.document.write(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Generated Resume</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        .download-btn {
          position: fixed;
          top: 10px;
          right: 10px;
          background: #667eea;
          color: white;
          border: none;
          padding: 10px 20px;
          border-radius: 5px;
          cursor: pointer;
        }
      </style>
    </head>
    <body>
      <button class="download-btn" onclick="downloadPDF()">Download PDF</button>
      ${htmlContent}

      <script>
        async function downloadPDF() {
          // This would trigger PDF download from your API
          const htmlContent = document.body.innerHTML;
          // Call your API's download endpoint
          alert('PDF download feature - integrate with your API');
        }
      </script>
    </body>
    </html>
  `);
}

// History
async function showHistory() {
  try {
    const history = await api.getCustomizationHistory();

    if (history.success) {
      const historyWindow = window.open('', '_blank', 'width=800,height=600');
      historyWindow.document.write(generateHistoryHTML(history));
    }
  } catch (error) {
    showStatus('Failed to load history.', 'error');
  }
}

function generateHistoryHTML(history) {
  const resumes = history.history || [];
  const stats = history.statistics || {};

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Resume History</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        .stats { background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .resume-item { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 8px; }
        .ats-score { color: #28a745; font-weight: bold; }
      </style>
    </head>
    <body>
      <h1>Resume History</h1>

      <div class="stats">
        <h2>Statistics</h2>
        <div>Total Resumes: ${stats.totalResumes || 0}</div>
        <div>Average ATS Score: ${stats.averageAtsScore || 0}</div>
        <div>Companies Applied: ${stats.totalCompanies || 0}</div>
      </div>

      <div class="resumes">
        ${resumes.map(resume => `
          <div class="resume-item">
            <h3>${resume.jobTitle} at ${resume.company}</h3>
            <div class="ats-score">ATS Score: ${resume.atsScore}%</div>
            <div>Created: ${new Date(resume.timestamp).toLocaleDateString()}</div>
            <div>Keywords Matched: ${resume.keywordsMatched?.join(', ') || 'None'}</div>
          </div>
        `).join('')}
      </div>
    </body>
    </html>
  `;
}

// Utility function to show status messages
function showStatus(message, type = 'info') {
  const statusDiv = document.getElementById('statusMessage');
  statusDiv.innerHTML = `<div class="${type}">${message}</div>`;

  if (type === 'success') {
    setTimeout(() => {
      statusDiv.innerHTML = '';
    }, 3000);
  }
}
```

### 7. Content Script (content.js)

```javascript
// Content script for job website integration
(function() {
  'use strict';

  // Add extension button to job pages
  function addExtensionButton() {
    if (document.getElementById('ai-job-extension-btn')) return;

    const button = document.createElement('button');
    button.id = 'ai-job-extension-btn';
    button.innerHTML = '🤖 Customize Resume with AI';
    button.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 10000;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      padding: 12px 20px;
      border-radius: 25px;
      font-size: 14px;
      font-weight: bold;
      cursor: pointer;
      box-shadow: 0 4px 15px rgba(0,0,0,0.2);
      transition: all 0.3s ease;
    `;

    button.addEventListener('mouseenter', () => {
      button.style.transform = 'translateY(-2px)';
      button.style.boxShadow = '0 6px 20px rgba(0,0,0,0.3)';
    });

    button.addEventListener('mouseleave', () => {
      button.style.transform = 'translateY(0)';
      button.style.boxShadow = '0 4px 15px rgba(0,0,0,0.2)';
    });

    button.addEventListener('click', () => {
      chrome.runtime.sendMessage({
        type: 'OPEN_EXTENSION',
        jobData: extractJobDetails()
      });
    });

    document.body.appendChild(button);
  }

  // Extract job details based on current site
  function extractJobDetails() {
    const hostname = window.location.hostname;
    let jobData = {};

    if (hostname.includes('linkedin.com')) {
      jobData = extractLinkedInJob();
    } else if (hostname.includes('indeed.com')) {
      jobData = extractIndeedJob();
    } else if (hostname.includes('naukri.com')) {
      jobData = extractNaukriJob();
    }

    jobData.url = window.location.href;
    jobData.platform = hostname;
    return jobData;
  }

  function extractLinkedInJob() {
    return {
      title: document.querySelector('.top-card-layout__title')?.textContent?.trim() ||
             document.querySelector('.t-24')?.textContent?.trim(),
      company: document.querySelector('.topcard__flavor-row .topcard__flavor--black-link')?.textContent?.trim() ||
               document.querySelector('[data-test-id="job-details-jobs-unified-top-card__company-name"] a')?.textContent?.trim(),
      location: document.querySelector('.topcard__flavor-row .topcard__flavor')?.textContent?.trim(),
      description: document.querySelector('.description__text')?.textContent?.trim() ||
                   document.querySelector('.jobs-description-content__text')?.textContent?.trim()
    };
  }

  function extractIndeedJob() {
    return {
      title: document.querySelector('[data-testid="jobsearch-JobInfoHeader-title"] span')?.textContent?.trim() ||
             document.querySelector('.jobsearch-JobInfoHeader-title')?.textContent?.trim(),
      company: document.querySelector('[data-testid="inlineHeader-companyName"] a')?.textContent?.trim() ||
               document.querySelector('.jobsearch-InlineCompanyRating + a')?.textContent?.trim(),
      location: document.querySelector('[data-testid="job-location"]')?.textContent?.trim(),
      description: document.querySelector('#jobDescriptionText')?.textContent?.trim()
    };
  }

  function extractNaukriJob() {
    return {
      title: document.querySelector('.jd-header-title')?.textContent?.trim(),
      company: document.querySelector('.jd-header-comp-name')?.textContent?.trim(),
      location: document.querySelector('.jd-header-comp-location')?.textContent?.trim(),
      description: document.querySelector('.dang-inner-html')?.textContent?.trim()
    };
  }

  // Add button when page loads
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addExtensionButton);
  } else {
    addExtensionButton();
  }

  // Re-add button on dynamic content changes (SPA navigation)
  const observer = new MutationObserver(() => {
    if (!document.getElementById('ai-job-extension-btn')) {
      setTimeout(addExtensionButton, 1000);
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
})();
```

### 8. Background Script (background.js)

```javascript
// Background service worker
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.type === 'OPEN_EXTENSION') {
    // Store job data for popup to access
    chrome.storage.local.set({
      detectedJob: request.jobData,
      lastJobDetection: Date.now()
    });

    // Open popup (this will automatically use the detected job data)
    chrome.action.openPopup();
  }
});

// Context menu for quick access
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'customizeResume',
    title: 'Customize Resume for this Job',
    contexts: ['page'],
    documentUrlPatterns: [
      '*://*.linkedin.com/*',
      '*://*.indeed.com/*',
      '*://*.naukri.com/*',
      '*://*.glassdoor.com/*'
    ]
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === 'customizeResume') {
    chrome.scripting.executeScript({
      target: { tabId: tab.id },
      function: () => {
        chrome.runtime.sendMessage({
          type: 'OPEN_EXTENSION',
          jobData: extractJobDetails()
        });
      }
    });
  }
});
```

## 🚀 Testing Your Implementation

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"content": "Examine current project structure and existing code", "status": "completed", "activeForm": "Examining current project structure and existing code"}, {"content": "Understand Chrome extension requirements", "status": "completed", "activeForm": "Understanding Chrome extension requirements"}, {"content": "Create Chrome extension frontend integration guide", "status": "completed", "activeForm": "Creating Chrome extension frontend integration guide"}, {"content": "Test the implementation", "status": "in_progress", "activeForm": "Testing the implementation"}]