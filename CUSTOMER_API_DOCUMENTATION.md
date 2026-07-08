# Customer API Documentation

This document covers all available API endpoints for the **Customer** module, split across two API namespaces:

1. **REST API** (`/api/v1/customers`) — admin/backend CRUD operations
2. **Mobile API** (`/api/v1/mobile/customer`) — customer-facing mobile app endpoints

---

## Authentication

| Namespace | Mechanism |
|-----------|-----------|
| REST API (`/api/v1/customers`) | Admin/session auth (`Api::V1::ApplicationController`) |
| Mobile API (`/api/v1/mobile/customer`) | Customer token auth via `authenticate_customer!` before action |

---

## 1. REST API — `/api/v1/customers`

Base path: `/api/v1/customers`

### 1.1 List Customers

```
GET /api/v1/customers
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `search` | string | Full-text search across `first_name`, `last_name`, `company_name`, `email`, `mobile`, `pan_no`, `lead_id` |
| `customer_type` | string | Filter by type: `individual` or `corporate` |
| `status` | string | Filter by status: `active` or `inactive` |
| `limit` | integer | Number of records to return (default: `50`) |
| `offset` | integer | Pagination offset (default: `0`) |

**Response:**
```json
{
  "customers": [
    {
      "id": 1,
      "customer_type": "individual",
      "display_name": "John Doe",
      "email": "john@example.com",
      "mobile": "9876543210",
      "address": "...",
      "state": "Karnataka",
      "city": "Bangalore",
      "status": true,
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-01-01T00:00:00Z"
    }
  ],
  "total_count": 100,
  "message": "Customers retrieved successfully"
}
```

---

### 1.2 Get Customer

```
GET /api/v1/customers/:id
```

**Response (Individual Customer):**
```json
{
  "customer": {
    "id": 1,
    "customer_type": "individual",
    "status": true,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z",
    "basic_info": {
      "profile_image": "https://...",
      "sub_agent": "agent-code",
      "first_name": "John",
      "middle_name": null,
      "last_name": "Doe",
      "mobile": "9876543210",
      "email": "john@example.com"
    },
    "advance_details": {
      "state": "Karnataka",
      "city": "Bangalore",
      "address": "123 Main St",
      "birth_place": "Mumbai",
      "birth_date": "1990-01-01",
      "age": 36,
      "gender": "male",
      "height_feet": 5.9,
      "weight_kg": 70,
      "education": "Graduate",
      "marital_status": "married",
      "business_job": "Software Engineer",
      "business_name": "ACME Corp",
      "type_of_duty": null,
      "annual_income": 1000000,
      "pan_no": "ABCDE1234F",
      "gst_no": null,
      "additional_information": null
    },
    "documents": [...],
    "uploaded_documents": [...],
    "family_members": [...],
    "corporate_members": []
  },
  "message": "Customer retrieved successfully"
}
```

**Response (Corporate Customer):**
```json
{
  "customer": {
    "id": 2,
    "customer_type": "corporate",
    "status": true,
    "company_name": "ACME Corp",
    "email": "corp@acme.com",
    "mobile": "9876543210",
    "address": "...",
    "state": "Maharashtra",
    "city": "Mumbai",
    "annual_income": 5000000,
    "pan_no": "ABCDE1234F",
    "gst_no": "27ABCDE1234F1Z5",
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  },
  "message": "Customer retrieved successfully"
}
```

---

### 1.3 Create Customer

```
POST /api/v1/customers
```

**Request Body (nested structure):**
```json
{
  "customer": {
    "customer_type": "individual",
    "first_name": "John",
    "middle_name": "",
    "last_name": "Doe",
    "email": "john@example.com",
    "mobile": "9876543210",
    "birth_date": "1990-01-01",
    "gender": "male",
    "address": "123 Main St",
    "state": "Karnataka",
    "city": "Bangalore",
    "pincode": "560001",
    "pan_no": "ABCDE1234F",
    "gst_no": null,
    "annual_income": 1000000,
    "nominee_name": "Jane Doe",
    "nominee_relation": "spouse",
    "nominee_date_of_birth": "1992-01-01",
    "occupation": "Engineer",
    "marital_status": "married",
    "education": "Graduate",
    "height_feet": 5.9,
    "weight_kg": 70,
    "additional_information": "",
    "family_members_attributes": [],
    "corporate_members_attributes": [],
    "documents_attributes": []
  }
}
```

**Response:** `201 Created` with the full customer object.

---

### 1.4 Register Customer (Flat JSON)

```
POST /api/v1/customers/register
```

Accepts a flat JSON structure (no nested `customer` key).

**Request Body:**
```json
{
  "customer_type": "individual",
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "mobile": "9876543210",
  "birth_date": "1990-01-01",
  "nominee_name": "Jane Doe",
  "nominee_relation": "spouse",
  "nominee_date_of_birth": "1992-01-01"
}
```

**Response:**
```json
{
  "status": true,
  "message": "Customer created successfully",
  "data": {
    "id": 1,
    "customer_type": "individual",
    "display_name": "John Doe",
    "email": "john@example.com",
    "mobile": "9876543210"
  }
}
```

---

### 1.5 Update Customer

```
PATCH /api/v1/customers/:id
PUT   /api/v1/customers/:id
```

Same nested request body as **Create Customer**. Returns updated customer object.

---

### 1.6 Delete Customer

```
DELETE /api/v1/customers/:id
```

**Constraint:** Cannot delete a customer who has existing policies. Returns `403 Forbidden` in that case.

**Response (success):**
```json
{
  "message": "Customer deleted successfully"
}
```

---

### 1.7 Toggle Customer Status

```
PATCH /api/v1/customers/:id/toggle_status
```

Toggles the customer's `status` field between `true` (active) and `false` (inactive).

**Response:**
```json
{
  "customer": { ... },
  "message": "Customer activated successfully"
}
```

---

### Validation Rules (Customer Model)

**Individual Customers — Required Fields:**

| Field | Validation |
|-------|-----------|
| `first_name` | Required |
| `last_name` | Required |
| `mobile` | Required, unique, valid 10-digit Indian number (starts with 6/7/8/9) |
| `birth_date` | Required |
| `nominee_name` | Required |
| `nominee_relation` | Required; one of: `father`, `mother`, `spouse`, `son`, `daughter`, `brother`, `sister`, `other` |
| `nominee_date_of_birth` | Required |
| `email` | Optional, valid email format if provided |

**Corporate Customers — Required Fields:**

| Field | Validation |
|-------|-----------|
| `company_name` | Required |
| `mobile` | Required, unique, valid 10-digit Indian number |
| `email` | Required, valid email format |
| `gst_no` | Required, valid GST format |

**Common Optional Fields:**

| Field | Validation |
|-------|-----------|
| `gender` | `male`, `female`, or `other` |
| `marital_status` | `single`, `married`, `divorced`, or `widowed` |
| `pan_no` | Valid PAN format (e.g. `ABCDE1234F`) |
| `gst_no` | Valid GST format |

---

## 2. Mobile API — `/api/v1/mobile/customer`

All endpoints require a valid **customer auth token** (Bearer token via `authenticate_customer!`).

Base path: `/api/v1/mobile/customer`

---

### 2.1 Get Policy Portfolio

```
GET /api/v1/mobile/customer/portfolio
```

Returns the authenticated customer's full insurance portfolio across Health, Life, and Motor insurance types, sorted by start date (newest first).

**Response:**
```json
{
  "success": true,
  "data": {
    "portfolio": [
      {
        "id": 1,
        "insurance_name": "Star Health Optima",
        "insurance_type": "Health",
        "policy_number": "POL-001",
        "policy_holder": "John Doe",
        "start_date": "2025-01-01",
        "end_date": "2026-01-01",
        "total_premium": "₹12,500",
        "sum_insured": "₹5,00,000",
        "insurance_company": "Star Health Insurance",
        "payment_mode": "Yearly",
        "status": "Active",
        "days_until_expiry": 200,
        "drwise": false,
        "dr_wise": false,
        "document": "https://...",
        "documents": [
          {
            "title": "Main Policy Document",
            "document_type": "policy_document",
            "url": "https://...",
            "filename": "policy.pdf",
            "size": 102400,
            "is_main": true
          }
        ]
      }
    ],
    "total_policies": 3,
    "total_premium": "₹45,000",
    "total_sum_insured": "₹20,00,000",
    "active_policies": 2,
    "expiring_policies": 1,
    "portfolio_summary": {
      "total_policies": 3,
      "upcoming_installments": 1,
      "renewal_policies": 1
    }
  }
}
```

**Policy Status Values:** `Active`, `Expired`, `Expiring Soon`

**Insurance Types:** `Health`, `Life`, `Motor`

**Life Insurance Extra Fields:** `nominee_name`, `nominee_relationship`, `policy_term`, `premium_payment_term`

**Motor Insurance Extra Fields:** `sum_insured` is mapped from `vehicle_idv`

---

### 2.2 Get Upcoming Installments

```
GET /api/v1/mobile/customer/upcoming_installments
```

Returns upcoming payment installments across Health, Life, and Motor policies within the **next 60 days**. Also includes recently expired policies (within 18 months) to show renewal installments.

**Excludes:** Policies with `payment_mode` of `single`, `one time`, or `lump sum`.

**Response:**
```json
{
  "success": true,
  "data": {
    "upcoming_installments": [
      {
        "id": 1,
        "insurance_name": "Star Health Optima",
        "insurance_type": "Health",
        "policy_number": "POL-001",
        "policy_holder": "John Doe",
        "insurance_company": "Star Health",
        "start_date": "2025-01-01",
        "end_date": "2026-01-01",
        "total_premium": "₹12,500",
        "payment_mode": "Quarterly",
        "next_installment_date": "2026-07-01",
        "installment_amount": "₹3,125",
        "installment_amount_raw": 3125.0,
        "days_until_installment": 18,
        "days_left_from_today": 18,
        "label": "Coming soon",
        "installment_type": "regular",
        "is_expired": false,
        "is_overdue": false,
        "drwise": false,
        "dr_wise": false,
        "document": "https://...",
        "documents": [...]
      }
    ],
    "total_installments": 2,
    "total_amount": "₹6,250",
    "next_7_days": 0,
    "next_30_days": 1,
    "next_60_days": 2,
    "next_90_days": 2,
    "regular_installments": 2,
    "renewal_installments": 0,
    "overdue_installments": 0,
    "expired_policies": 0,
    "active_policies": 2,
    "next_installment": { ... }
  }
}
```

**Label Values:** `Expired`, `Expiring in 1 day`, `Expiring in N days`, `Coming soon`, `Upcoming`

**Installment Type Values:** `regular`, `renewal`

**Installment Amount Calculation:**

| Payment Mode | Formula |
|---|---|
| `monthly` | `total_premium / 12` |
| `quarterly` | `total_premium / 4` |
| `half-yearly` / `half yearly` | `total_premium / 2` |
| `yearly` | `total_premium` |

---

### 2.3 Get Upcoming Renewals

```
GET /api/v1/mobile/customer/upcoming_renewals
```

Returns policies with renewals due within the **next 2 months**, across Health, Life, Motor, Travel, General, and Other insurance types. Sorted by urgency (overdue first).

**Response:**
```json
{
  "success": true,
  "data": {
    "upcoming_renewals": [
      {
        "id": 1,
        "insurance_name": "Star Health Optima",
        "insurance_type": "Health",
        "policy_number": "POL-001",
        "policy_holder": "John Doe",
        "start_date": "2025-01-01",
        "end_date": "2026-06-30",
        "renewal_date": "2026-07-01",
        "total_premium": "₹12,500",
        "total_premium_raw": 12500.0,
        "sum_insured": "₹5,00,000",
        "payment_mode": "Yearly",
        "days_until_renewal": 17,
        "renewal_status": "due_soon",
        "is_expired": false,
        "days_since_expiry": null,
        "insurance_company": "Star Health",
        "document": "https://...",
        "documents": [...],
        "drwise": false
      }
    ],
    "total_renewals": 2,
    "urgent_renewals": 0,
    "due_soon": 1,
    "approaching": 1,
    "upcoming": 0,
    "overdue": 0,
    "renewal_required": 0,
    "renewal_recommended": 0,
    "active_policies": 2,
    "expired_policies": 0,
    "customer_id": 1,
    "customer_name": "John Doe",
    "has_policies": true,
    "by_insurance_type": {
      "health": 1,
      "life": 0,
      "motor": 0,
      "travel": 1,
      "general": 0,
      "other": 0
    },
    "summary": {
      "next_7_days": 0,
      "next_30_days": 1,
      "next_60_days": 2,
      "overdue_count": 0,
      "total_premium_due": "₹25,000",
      "most_urgent": { ... },
      "insurance_types_covered": ["Health", "Travel"]
    }
  }
}
```

**Renewal Status Values:**

| Status | Condition |
|--------|-----------|
| `overdue` | Policy expired (within 30 days for other types) |
| `renewal_required` | Expired 30–90 days ago |
| `renewal_recommended` | Expired more than 90 days ago |
| `urgent` | Expires within 7 days |
| `due_soon` | Expires within 30 days |
| `approaching` | Expires within 60 days |
| `upcoming` | Expires beyond 60 days |

**Note:** Life insurance uses `next_premium_due_date` (calculated from start date + payment intervals) rather than `policy_end_date` (which can be 10–20 years away).

---

### 2.4 Add Policy (Customer Self-Submit)

```
POST /api/v1/mobile/customer/add_policy
```

Allows a customer to submit a new policy request. Defaults are applied for missing/invalid fields. Admin review is required after submission.

**Request Body:**
```json
{
  "insurance_type": "health",
  "plan_name": "Star Health Optima",
  "sum_insured": 500000,
  "premium_amount": 12500,
  "policy_number": "POL-OPTIONAL-001",
  "insurance_company": "Star Health",
  "renewal_date": "2027-01-01",
  "policy_holder": "John Doe",
  "product_through_dr": false,
  "remarks": "Family floater plan",
  "additional_notes": "Please include spouse",
  "family_members": ["Spouse", "Child"]
}
```

**Supported Insurance Types:**

| `insurance_type` value | Model Created |
|---|---|
| `health` | `HealthInsurance` |
| `life` or `lic` | `LifeInsurance` |
| `motor` | `MotorInsurance` |
| `other` | `OtherInsurance` |

**Default Values Applied When Fields Are Blank:**

| Field | Default |
|-------|---------|
| `insurance_type` | `health` |
| `plan_name` | `Standard Plan` |
| `sum_insured` | `500000` |
| `premium_amount` | `25000` |
| `policy_number` | `REQ-{timestamp}` |
| `insurance_company` | `To be assigned` |

**Response (success):**
```json
{
  "success": true,
  "message": "Policy request submitted successfully! Our team will review your request and contact you within 24 hours.",
  "data": {
    "policy_id": 42,
    "policy_number": "REQ-1718000000",
    "insurance_type": "health",
    "plan_name": "Star Health Optima",
    "sum_insured": 500000.0,
    "premium_amount": "₹12,500",
    "renewal_date": "2027-01-01",
    "product_through_dr": false,
    "status": "pending_approval",
    "family_members": ["Spouse", "Child"],
    "remarks": "Family floater plan",
    "submitted_at": "2026-06-13T00:00:00Z"
  }
}
```

**Error Responses:**

| Scenario | HTTP Status | `error_code` |
|----------|-------------|--------------|
| Invalid insurance type | `422 Unprocessable Entity` | — |
| Duplicate policy number | `409 Conflict` | `DUPLICATE_POLICY_NUMBER` |
| Validation failure | `422 Unprocessable Entity` | — |
| Internal error | `500 Internal Server Error` | `INTERNAL_ERROR` |

---

### 2.5 Create Helpdesk Ticket

```
POST /api/v1/mobile/customer/helpdesk
```

Creates a support ticket on behalf of the authenticated customer.

**Request Body:**
```json
{
  "subject": "Policy document not received",
  "description": "I submitted my policy 3 days ago but have not received the document.",
  "category": "general",
  "priority": "medium"
}
```

**Required Fields:** `subject`, `description`

**Defaults:** `category` = `general`, `priority` = `medium`, `status` = `pending`

**Response:**
```json
{
  "success": true,
  "message": "Helpdesk ticket created successfully",
  "data": {
    "ticket": {
      "id": 10,
      "ticket_number": "TKT000010",
      "subject": "Policy document not received",
      "description": "...",
      "category": "general",
      "priority": "medium",
      "status": "pending",
      "created_at": "2026-06-13T00:00:00Z"
    }
  }
}
```

---

### 2.6 List Helpdesk Tickets

```
GET /api/v1/mobile/customer/helpdesk_tickets
```

Returns a paginated list of helpdesk tickets submitted by the authenticated customer.

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | `1` | Page number |
| `per_page` | integer | `20` | Records per page |
| `status` | string | — | Filter by status (e.g. `pending`, `resolved`) |

**Response:**
```json
{
  "success": true,
  "data": {
    "tickets": [
      {
        "id": 10,
        "ticket_number": "TKT000010",
        "subject": "Policy document not received",
        "description": "...",
        "category": "general",
        "priority": "medium",
        "status": "pending",
        "resolution_notes": null,
        "resolved_at": null,
        "created_at": "2026-06-13T00:00:00Z",
        "updated_at": "2026-06-13T00:00:00Z"
      }
    ],
    "pagination": {
      "current_page": 1,
      "total_pages": 1,
      "total_count": 1,
      "per_page": 20
    }
  }
}
```

---

### 2.7 Get Helpdesk Ticket Details

```
GET /api/v1/mobile/customer/helpdesk_tickets/:id
```

Returns full details of a specific helpdesk ticket. Only tickets belonging to the authenticated customer are accessible.

**Response:**
```json
{
  "success": true,
  "data": {
    "ticket": {
      "id": 10,
      "ticket_number": "TKT000010",
      "subject": "Policy document not received",
      "description": "...",
      "category": "general",
      "priority": "medium",
      "status": "pending",
      "resolution_notes": null,
      "resolved_at": null,
      "assigned_to": null,
      "created_at": "2026-06-13T00:00:00Z",
      "updated_at": "2026-06-13T00:00:00Z"
    }
  }
}
```

**Error (not found or unauthorized):** `404 Not Found`

---

## API Summary Table

### REST API (`/api/v1/customers`)

| Method | Endpoint | Action |
|--------|----------|--------|
| `GET` | `/api/v1/customers` | List customers (with search & filters) |
| `GET` | `/api/v1/customers/:id` | Get customer details |
| `POST` | `/api/v1/customers` | Create customer (nested JSON) |
| `POST` | `/api/v1/customers/register` | Create customer (flat JSON) |
| `PATCH/PUT` | `/api/v1/customers/:id` | Update customer |
| `DELETE` | `/api/v1/customers/:id` | Delete customer |
| `PATCH` | `/api/v1/customers/:id/toggle_status` | Toggle active/inactive |

### Mobile API (`/api/v1/mobile/customer`) — Requires Customer Auth

| Method | Endpoint | Action |
|--------|----------|--------|
| `GET` | `/api/v1/mobile/customer/portfolio` | Full insurance portfolio |
| `GET` | `/api/v1/mobile/customer/upcoming_installments` | Upcoming premium installments (60 days) |
| `GET` | `/api/v1/mobile/customer/upcoming_renewals` | Upcoming policy renewals (2 months) |
| `POST` | `/api/v1/mobile/customer/add_policy` | Submit a new policy request |
| `POST` | `/api/v1/mobile/customer/helpdesk` | Create a helpdesk ticket |
| `GET` | `/api/v1/mobile/customer/helpdesk_tickets` | List customer's helpdesk tickets |
| `GET` | `/api/v1/mobile/customer/helpdesk_tickets/:id` | Get a specific helpdesk ticket |
