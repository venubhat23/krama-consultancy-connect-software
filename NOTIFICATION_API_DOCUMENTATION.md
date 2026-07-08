# Notification API Documentation

## Overview
This API provides notification management for users, sub-agents, and customers in the InsureBook system.

## Authentication
All endpoints require JWT token authentication via the `Authorization` header:
```
Authorization: Bearer <JWT_TOKEN>
```

## Base URL
```
/api/v1/notifications
```

## Endpoints

### 1. Get All Notifications
**GET** `/`

Returns paginated list of notifications for the authenticated user or specific recipient.

**Query Parameters:**
- `page` (integer, optional): Page number (default: 1)
- `per_page` (integer, optional): Records per page (default: 20, max: 50)
- `type` (string, optional): Filter by notification type
- `is_read` (boolean, optional): Filter by read status (true/false)
- `recipient_type` (string, optional): Filter by recipient type (User, SubAgent, Customer)
- `recipient_id` (integer, optional): Filter by recipient ID

**Example Request:**
```
GET /api/v1/notifications?page=1&per_page=10&is_read=false
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "notifications": [
      {
        "id": 123,
        "type": "policy_created",
        "title": "New Policy Created",
        "message": "Your health insurance policy has been successfully created",
        "is_read": false,
        "sent_at": "2026-04-14T10:30:00Z",
        "read_at": null,
        "recipient": {
          "type": "SubAgent",
          "id": 456
        }
      }
    ],
    "pagination": {
      "current_page": 1,
      "total_pages": 5,
      "total_count": 45,
      "per_page": 10
    }
  }
}
```

### 2. Get Specific Notification
**GET** `/:id`

Returns detailed information about a specific notification.

**Response:**
```json
{
  "status": "success",
  "data": {
    "notification": {
      "id": 123,
      "type": "policy_created",
      "title": "New Policy Created",
      "message": "Your health insurance policy has been successfully created",
      "is_read": false,
      "sent_at": "2026-04-14T10:30:00Z",
      "read_at": null,
      "recipient": {
        "type": "SubAgent",
        "id": 456
      },
      "reference": {
        "type": "HealthInsurance",
        "id": 789
      },
      "created_at": "2026-04-14T10:30:00Z",
      "updated_at": "2026-04-14T10:30:00Z"
    }
  }
}
```

### 3. Get Unread Count
**GET** `/unread_count`

Returns the count of unread notifications for the authenticated user.

**Response:**
```json
{
  "status": "success",
  "data": {
    "unread_count": 12
  }
}
```

### 4. Get Recent Notifications
**GET** `/recent`

Returns the 10 most recent notifications.

**Response:**
```json
{
  "status": "success",
  "data": {
    "notifications": [
      {
        "id": 123,
        "type": "policy_created",
        "title": "New Policy Created",
        "message": "Your health insurance policy has been successfully created",
        "is_read": false,
        "sent_at": "2026-04-14T10:30:00Z",
        "read_at": null,
        "recipient": {
          "type": "SubAgent",
          "id": 456
        }
      }
    ]
  }
}
```

### 5. Mark Notification as Read
**PATCH** `/:id/mark_as_read`

Marks a specific notification as read.

**Response:**
```json
{
  "status": "success",
  "message": "Notification marked as read",
  "data": {
    "notification": {
      "id": 123,
      "type": "policy_created",
      "title": "New Policy Created",
      "message": "Your health insurance policy has been successfully created",
      "is_read": true,
      "sent_at": "2026-04-14T10:30:00Z",
      "read_at": "2026-04-14T11:45:00Z",
      "recipient": {
        "type": "SubAgent",
        "id": 456
      }
    }
  }
}
```

### 6. Mark Notification as Unread
**PATCH** `/:id/mark_as_unread`

Marks a specific notification as unread.

**Response:**
```json
{
  "status": "success",
  "message": "Notification marked as unread",
  "data": {
    "notification": {
      "id": 123,
      "type": "policy_created",
      "title": "New Policy Created",
      "message": "Your health insurance policy has been successfully created",
      "is_read": false,
      "sent_at": "2026-04-14T10:30:00Z",
      "read_at": null,
      "recipient": {
        "type": "SubAgent",
        "id": 456
      }
    }
  }
}
```

### 7. Mark All Notifications as Read
**PATCH** `/mark_all_as_read`

Marks all notifications as read for the authenticated user.

**Response:**
```json
{
  "status": "success",
  "message": "All notifications marked as read",
  "data": {
    "updated_count": 15
  }
}
```

### 8. Get Notification Types
**GET** `/types`

Returns all available notification types.

**Response:**
```json
{
  "status": "success",
  "data": {
    "notification_types": [
      {
        "value": "helpdesk_comment_added",
        "label": "Helpdesk Comment Added"
      },
      {
        "value": "policy_created",
        "label": "Policy Created"
      },
      {
        "value": "policy_renewed",
        "label": "Policy Renewed"
      },
      {
        "value": "lead_status_updated",
        "label": "Lead Status Updated"
      },
      {
        "value": "general_announcement",
        "label": "General Announcement"
      }
    ]
  }
}
```

## Status Codes

- **200 OK**: Successful response
- **401 Unauthorized**: Invalid or missing authentication token
- **403 Forbidden**: Access denied or inactive account
- **404 Not Found**: Notification not found
- **500 Internal Server Error**: Server error

## Error Response Format

```json
{
  "status": "error",
  "message": "Error description"
}
```

## Notification Types

- **helpdesk_comment_added**: New comment added to support ticket
- **policy_created**: New insurance policy created
- **policy_renewed**: Insurance policy renewed
- **lead_status_updated**: Lead status or stage changed
- **general_announcement**: General system announcements

## Recipient Types

- **User**: System users (admins, agents)
- **SubAgent**: Sub-agents/affiliates
- **Customer**: Insurance customers

## Reference Types

- **HealthInsurance**: Health insurance policies
- **LifeInsurance**: Life insurance policies
- **MotorInsurance**: Motor insurance policies
- **OtherInsurance**: Other insurance types
- **Helpdesk**: Support tickets
- **Lead**: Sales leads

## Authentication Flow

1. User/Sub-agent/Customer logs in via authentication endpoint
2. Receives JWT token in response
3. Includes token in `Authorization: Bearer <token>` header for all notification API calls
4. Token is validated against user record and permissions

## Rate Limiting

- Maximum 100 requests per minute per user
- Pagination limits: max 50 records per page

## Date Format

All timestamps are returned in ISO 8601 format:
- **sent_at**: When the notification was sent
- **read_at**: When the notification was marked as read (null if unread)
- **created_at**: When the notification record was created
- **updated_at**: When the notification record was last updated

## Implementation Notes

- Notifications are filtered based on recipient type and ID
- Unread notifications are automatically marked when accessed via the show endpoint
- Bulk operations (mark all as read) affect only notifications for the authenticated user
- Notifications support polymorphic references to different types of records
- Historical notifications are preserved even if referenced records are deleted
- User permissions are validated on every request
- Supports real-time updates via WebSocket connections (separate documentation)

## WebSocket Integration

For real-time notification updates, consider implementing WebSocket connections:
- Subscribe to notification channels based on recipient
- Receive instant updates when new notifications are created
- Update UI counters and lists without polling

## Mobile API Integration

This notification API is designed to work seamlessly with mobile applications:
- Lightweight JSON responses
- Efficient pagination for mobile data usage
- Support for offline synchronization
- Push notification integration ready