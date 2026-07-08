# Commission Breakdown API Documentation

## Overview
This API provides commission breakdown and statistics for sub-agents/affiliates in the InsureBook system.

## Authentication
All endpoints require JWT token authentication via the `Authorization` header:
```
Authorization: Bearer <JWT_TOKEN>
```

## Base URL
```
/api/v1/mobile/commission
```

## Endpoints

### 1. Commission Breakdown
**GET** `/breakdown`

Returns complete commission breakdown including summary and recent payouts.

**Response:**
```json
{
  "status": "success",
  "data": {
    "commission_summary": {
      "commission_earned": "₹5,297",
      "commission_earned_raw": 5297.0,
      "total_earned": "₹692",
      "total_earned_raw": 692.0,
      "paid": "₹692",
      "paid_raw": 692.0,
      "pending": "₹0",
      "pending_raw": 0.0,
      "processing": "₹4,606",
      "processing_raw": 4606.0,
      "total_policies": 7,
      "active_policies": 7
    },
    "recent_payouts": [
      {
        "id": 123,
        "policy_number": "7330237099",
        "policy_type": "Health Insurance",
        "customer_name": "RAGHU B S",
        "commission_amount": "₹2,718",
        "commission_amount_raw": 2718.0,
        "tds_amount": "₹271",
        "tds_amount_raw": 271.8,
        "net_amount": "₹2,446",
        "net_amount_raw": 2446.2,
        "commission_percentage": 10.0,
        "status": "Pending",
        "status_raw": "pending",
        "payout_date": "10 May, 2026",
        "payout_date_raw": "2026-05-10T00:00:00Z",
        "created_date": "08 May, 2026",
        "created_date_raw": "2026-05-08T10:30:00Z",
        "payment_mode": null,
        "transaction_id": null,
        "reference_number": null
      }
    ]
  },
  "timestamp": "2026-04-13T10:30:00Z"
}
```

### 2. Commission Summary
**GET** `/summary`

Returns only the commission summary totals.

**Response:**
```json
{
  "status": "success",
  "data": {
    "commission_earned": "₹5,297",
    "commission_earned_raw": 5297.0,
    "total_earned": "₹692",
    "total_earned_raw": 692.0,
    "paid": "₹692",
    "paid_raw": 692.0,
    "pending": "₹0",
    "pending_raw": 0.0,
    "processing": "₹4,606",
    "processing_raw": 4606.0,
    "total_policies": 7,
    "active_policies": 7
  },
  "timestamp": "2026-04-13T10:30:00Z"
}
```

### 3. Commission History
**GET** `/history`

Returns paginated commission history.

**Query Parameters:**
- `page` (integer, optional): Page number (default: 1)
- `per_page` (integer, optional): Records per page (default: 10, max: 50)

**Example Request:**
```
GET /api/v1/mobile/commission/history?page=1&per_page=10
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "payouts": [
      {
        "id": 123,
        "policy_number": "7330237099",
        "policy_type": "Health Insurance",
        "customer_name": "RAGHU B S",
        "commission_amount": "₹2,718",
        "commission_amount_raw": 2718.0,
        "tds_amount": "₹271",
        "tds_amount_raw": 271.8,
        "net_amount": "₹2,446",
        "net_amount_raw": 2446.2,
        "commission_percentage": 10.0,
        "status": "Pending",
        "status_raw": "pending",
        "payout_date": "10 May, 2026",
        "payout_date_raw": "2026-05-10T00:00:00Z",
        "created_date": "08 May, 2026",
        "created_date_raw": "2026-05-08T10:30:00Z",
        "payment_mode": null,
        "transaction_id": null,
        "reference_number": null
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 10,
      "total_pages": 1,
      "total_count": 7,
      "has_next_page": false,
      "has_prev_page": false
    }
  },
  "timestamp": "2026-04-13T10:30:00Z"
}
```

### 4. Commission Statistics
**GET** `/stats`

Returns monthly and year-to-date commission statistics.

**Response:**
```json
{
  "status": "success",
  "data": {
    "monthly_stats": [
      {
        "month": 1,
        "month_name": "January",
        "total_earned": 0,
        "paid_amount": 0,
        "pending_amount": 0,
        "processing_amount": 0,
        "payout_count": 0
      },
      {
        "month": 2,
        "month_name": "February",
        "total_earned": 433,
        "paid_amount": 0,
        "pending_amount": 433,
        "processing_amount": 0,
        "payout_count": 1
      }
    ],
    "ytd_stats": {
      "total_earned": 5297,
      "paid_amount": 692,
      "pending_amount": 4172,
      "processing_amount": 433,
      "total_policies": 7
    },
    "year": 2026
  },
  "timestamp": "2026-04-13T10:30:00Z"
}
```

## Status Codes

- **200 OK**: Successful response
- **401 Unauthorized**: Invalid or missing authentication token
- **403 Forbidden**: Account is inactive or deactivated
- **500 Internal Server Error**: Server error

## Error Response Format

```json
{
  "status": "error",
  "message": "Error description",
  "error": "Detailed error message"
}
```

## Commission Status Types

- **Pending**: Commission calculated but not yet processed
- **Processing**: Commission is being processed for payment
- **Paid**: Commission has been successfully paid
- **Cancelled**: Commission payout was cancelled

## Policy Types

- **Health Insurance**: Health/Medical insurance policies
- **Life Insurance**: Life insurance policies
- **Motor Insurance**: Vehicle insurance policies
- **Other Insurance**: All other types of insurance

## Authentication Flow

1. Sub-agent logs in via mobile app authentication endpoint
2. Receives JWT token in response
3. Includes token in `Authorization: Bearer <token>` header for all commission API calls
4. Token is validated against sub-agent record and status

## Rate Limiting

- Maximum 100 requests per minute per sub-agent
- Pagination limits: max 50 records per page

## Currency Format

All monetary values are returned in two formats:
- **Formatted**: Human-readable Indian currency format (e.g., "₹2,718")
- **Raw**: Numeric value for calculations (e.g., 2718.0)

## Date Format

All dates are returned in two formats:
- **Formatted**: Human-readable format (e.g., "10 May, 2026")
- **Raw**: ISO 8601 format (e.g., "2026-05-10T00:00:00Z")

## Implementation Notes

- All amounts are calculated in real-time from the `commission_payouts` table
- Commission percentages and TDS calculations are policy-specific
- Historical data is preserved even if policy details change
- Sub-agent status is validated on every request
- Supports pagination for large datasets
- Includes both formatted and raw data for UI flexibility