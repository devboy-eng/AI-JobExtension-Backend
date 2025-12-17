# Link in Bio API Documentation

## Overview
Complete backend implementation for Link in Bio feature with full CRUD operations and public bio page.

## Database Schema
```sql
CREATE TABLE links (
  id SERIAL PRIMARY KEY,
  title VARCHAR NOT NULL,
  url VARCHAR NOT NULL,
  description TEXT,
  position INTEGER DEFAULT 0,
  active BOOLEAN DEFAULT true,
  user_id INTEGER NOT NULL REFERENCES users(id),
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Indexes
CREATE INDEX idx_links_user_position ON links(user_id, position);
CREATE INDEX idx_links_user_active ON links(user_id, active);
```

## API Endpoints

### Protected Endpoints (Require Authentication)

#### 1. Get User's Links
```http
GET /api/links
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "title": "My Website",
      "url": "https://example.com",
      "description": "Check out my website",
      "position": 0,
      "active": true,
      "created_at": "2025-09-09T04:27:32.000Z",
      "updated_at": "2025-09-09T04:27:32.000Z"
    }
  ]
}
```

#### 2. Get Single Link
```http
GET /api/links/:id
Authorization: Bearer {token}
```

#### 3. Create New Link
```http
POST /api/links
Authorization: Bearer {token}
Content-Type: application/json

{
  "link": {
    "title": "My YouTube Channel",
    "url": "https://youtube.com/@username",
    "description": "Subscribe to my channel",
    "active": true
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Link created successfully",
  "data": {
    "id": 2,
    "title": "My YouTube Channel",
    "url": "https://youtube.com/@username",
    "description": "Subscribe to my channel",
    "position": 1,
    "active": true,
    "created_at": "2025-09-09T04:30:00.000Z",
    "updated_at": "2025-09-09T04:30:00.000Z"
  }
}
```

#### 4. Update Link
```http
PUT /api/links/:id
Authorization: Bearer {token}
Content-Type: application/json

{
  "link": {
    "title": "Updated Title",
    "url": "https://newurl.com",
    "description": "Updated description",
    "active": false
  }
}
```

#### 5. Delete Link
```http
DELETE /api/links/:id
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "message": "Link deleted successfully"
}
```

#### 6. Reorder Links
```http
POST /api/links/reorder
Authorization: Bearer {token}
Content-Type: application/json

{
  "link_orders": [
    {"id": 3},
    {"id": 1},
    {"id": 2}
  ]
}
```

### Public Endpoints (No Authentication Required)

#### 7. Get User's Public Bio
```http
GET /bio/:user_id
# or
GET /bio/:referral_code
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "username",
      "referral_code": "ABC123",
      "created_at": "2025-08-01T00:00:00.000Z"
    },
    "links": [
      {
        "id": 1,
        "title": "My Website",
        "url": "https://example.com",
        "description": "Check out my website",
        "position": 0
      }
    ],
    "meta": {
      "total_links": 1,
      "last_updated": "2025-09-09T04:27:32.000Z"
    }
  }
}
```

#### 8. Get Bio Analytics (Future Feature)
```http
GET /bio/:user_id/analytics
```

## Error Responses

### 400 Bad Request
```json
{
  "success": false,
  "message": "Failed to create link",
  "errors": ["Title can't be blank", "Url is invalid"]
}
```

### 401 Unauthorized
```json
{
  "success": false,
  "message": "Unauthorized"
}
```

### 404 Not Found
```json
{
  "success": false,
  "message": "Link not found"
}
```

## Usage Examples

### Frontend Integration Examples

#### React/JavaScript - Create Link
```javascript
const createLink = async (linkData) => {
  const response = await fetch('/api/links', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${userToken}`
    },
    body: JSON.stringify({ link: linkData })
  });
  
  const result = await response.json();
  return result;
};

// Usage
const newLink = await createLink({
  title: "Instagram Profile",
  url: "https://instagram.com/username",
  description: "Follow me on Instagram!"
});
```

#### React/JavaScript - Get Public Bio
```javascript
const getUserBio = async (userId) => {
  const response = await fetch(`/bio/${userId}`);
  const result = await response.json();
  return result;
};

// Usage
const bioData = await getUserBio('ABC123'); // using referral code
```

#### React/JavaScript - Reorder Links
```javascript
const reorderLinks = async (linkIds) => {
  const link_orders = linkIds.map(id => ({ id }));
  
  const response = await fetch('/api/links/reorder', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${userToken}`
    },
    body: JSON.stringify({ link_orders })
  });
  
  return await response.json();
};
```

## Model Validations

- **Title**: Required, max 100 characters
- **URL**: Required, must be valid HTTP/HTTPS URL
- **Description**: Optional, max 500 characters  
- **Position**: Auto-assigned if not provided
- **Active**: Defaults to true

## Database Relations

- `User` has_many `Links`
- `Link` belongs_to `User`
- Links are automatically ordered by position
- Soft delete functionality through active flag

## Next Steps

1. Run the migration: `rails db:migrate`
2. Test the API endpoints using Postman or similar tool
3. Integrate with your frontend Link in Bio feature
4. Add click tracking analytics (future enhancement)
5. Add link categories/tags (future enhancement)
6. Add custom themes for bio pages (future enhancement)