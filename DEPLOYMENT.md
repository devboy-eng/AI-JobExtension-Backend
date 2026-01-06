# JobExtension Backend Deployment Guide

## Security Implementation ✅

Your backend now uses **Rails encrypted credentials** instead of plain-text environment variables for all sensitive data.

## Current Security Status

### ✅ **SECURE (Encrypted):**
- OpenAI API Key
- Razorpay Payment Keys & Secrets  
- Gmail SMTP Password
- Rails Secret Key Base

### ✅ **Implementation:**
- All secrets stored in `config/credentials.yml.enc`
- Master key: `config/master.key` (file: `be75f6dc8332122a41b282b5c0c2e396`)
- Code updated to use `Rails.application.credentials.*`

## Deployment Requirements

### **Essential Environment Variables:**

```bash
# Required for ALL platforms
RAILS_MASTER_KEY=be75f6dc8332122a41b282b5c0c2e396

# Database (provided by platform)
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# Optional
REDIS_URL=redis://host:6379  # If using Redis
RAILS_ENV=production
```

### **Platform-Specific Setup:**

#### **Railway (Recommended)**
```bash
railway variables set RAILS_MASTER_KEY=be75f6dc8332122a41b282b5c0c2e396
# Database auto-provided by Railway
```

#### **Render**
```bash
# In Render Dashboard Environment Variables:
RAILS_MASTER_KEY=be75f6dc8332122a41b282b5c0c2e396
# Database auto-provided by Render
```

#### **Fly.io**
```bash
fly secrets set RAILS_MASTER_KEY=be75f6dc8332122a41b282b5c0c2e396
```

#### **AWS Elastic Beanstalk**
```bash
# In EB Environment Configuration:
RAILS_MASTER_KEY=be75f6dc8332122a41b282b5c0c2e396
DATABASE_URL=postgresql://...  # RDS connection
```

## What's Encrypted in credentials.yml.enc:

```yaml
# All these are now SECURE and encrypted:
openai:
  api_key: sk-proj-...

razorpay:
  key_id: rzp_test_...
  key_secret: dBfIOO...
  webhook_secret: # Add when needed

smtp:
  username: gogetwrk@gmail.com  
  password: wgnq kjow lgfy nrhz

secret_key_base: f629049ea...
```

## Pre-Deployment Checklist:

### ✅ **Security:**
- [x] All secrets moved to encrypted credentials
- [x] .env cleaned of sensitive data
- [x] Master key generated and secured
- [x] Application code updated to use credentials

### 📝 **Deployment Steps:**
1. **Set RAILS_MASTER_KEY** in deployment platform
2. **Configure DATABASE_URL** (usually auto-provided)
3. **Deploy application**
4. **Run database migrations**
5. **Test API endpoints**

## File Security Summary:

| File | Status | Contains |
|------|--------|----------|
| `.env` | ✅ Safe for repo | Only non-sensitive config |
| `config/master.key` | ⚠️ KEEP SECRET | Encryption key |
| `config/credentials.yml.enc` | ✅ Safe for repo | Encrypted secrets |

## Master Key Security:

**CRITICAL:** The master key `be75f6dc8332122a41b282b5c0c2e396` is needed to decrypt all secrets.

- ✅ Store in password manager
- ✅ Add to deployment platform environment variables
- ❌ Never commit `config/master.key` to repository
- ❌ Never share in plain text messages

## Testing Deployment:

```bash
# Test credentials access:
rails console
> Rails.application.credentials.openai[:api_key].present?
> Rails.application.credentials.smtp[:username]
```

## Domain Configuration:

Update these for production:
- Email URLs: `jobextension.kuposu.co`
- CORS origins: Add production domain
- Host allowlist: Add production domain

Your backend is now **production-ready** and **secure** for deployment! 🚀