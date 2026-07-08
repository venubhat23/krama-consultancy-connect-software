# InsureBook Admin System - Complete Handover Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Technology Stack](#technology-stack)
4. [Deployment Information](#deployment-information)
5. [Database Schema](#database-schema)
6. [Feature Documentation](#feature-documentation)
7. [API Documentation](#api-documentation)
8. [Mobile API Documentation](#mobile-api-documentation)
9. [Authentication & Authorization](#authentication--authorization)
10. [Test Scenarios & Test Cases](#test-scenarios--test-cases)
11. [Configuration & Environment Setup](#configuration--environment-setup)
12. [File Storage & Document Management](#file-storage--document-management)
13. [Commission & Payout System](#commission--payout-system)
14. [Reporting System](#reporting-system)
15. [Import/Export Functionality](#importexport-functionality)
16. [Performance Optimizations](#performance-optimizations)
17. [Troubleshooting Guide](#troubleshooting-guide)
18. [Future Enhancements](#future-enhancements)

---

## Project Overview

**Project Name**: InsureBook Admin System
**Deployment URL**: https://dr-wise-ag.onrender.com/
**Version**: Rails 8.0.4
**Environment**: Production (deployed on Render)
**Purpose**: Comprehensive insurance management platform for administrators, agents, customers, and sub-agents

### Key Stakeholders
- **Admin Users**: Full system access, policy management, user management
- **Sub-Agents/Affiliates**: Limited access for customer and policy management
- **Customers**: Portfolio view and self-service capabilities
- **Distributors/Ambassadors**: Commission tracking and performance analytics
- **Investors**: Investment tracking and profit analytics

---

## System Architecture

### Application Structure
```
insurebook_admin/
├── app/
│   ├── controllers/
│   │   ├── admin/                 # Admin panel controllers
│   │   ├── api/v1/               # API controllers
│   │   │   └── mobile/           # Mobile-specific API controllers
│   │   └── users/                # Authentication controllers
│   ├── models/                   # ActiveRecord models
│   ├── views/                    # ERB templates
│   ├── services/                 # Business logic services
│   └── helpers/                  # View helpers
├── config/
│   ├── environments/             # Environment-specific configurations
│   ├── initializers/            # Application initializers
│   └── routes.rb                # Application routing
├── db/
│   ├── migrate/                 # Database migrations
│   └── seeds.rb                 # Seed data
└── public/                      # Static assets
```

### Core Components
1. **Admin Dashboard**: Comprehensive analytics and management interface
2. **Customer Management**: Complete customer lifecycle management
3. **Policy Management**: Multi-type insurance policy handling
4. **Commission System**: Automated commission calculation and distribution
5. **Lead Management**: Lead tracking with conversion funnel
6. **Document Management**: Cloud-based document storage (Cloudflare R2)
7. **Reporting Engine**: Dynamic report generation with export capabilities
8. **Mobile API**: REST API for mobile applications
9. **Import/Export**: Bulk data processing capabilities

---

## Technology Stack

### Backend
- **Framework**: Ruby on Rails 8.0.4
- **Database**: PostgreSQL
- **Authentication**: Devise + JWT (for API)
- **Authorization**: CanCanCan
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable

### Frontend
- **Template Engine**: ERB
- **CSS Framework**: Bootstrap 5.3
- **JavaScript**: Stimulus
- **Module System**: Importmap
- **Charts**: Chartkick with Chart.js
- **Pagination**: Kaminari

### External Services
- **File Storage**: Cloudflare R2 (S3-compatible)
- **PDF Generation**: WickedPDF with wkhtmltopdf
- **Email**: ActionMailer (configured for production)
- **Analytics**: Ahoy Matey for session tracking

### Development Tools
- **Code Quality**: Rubocop Rails Omakase
- **Security**: Brakeman
- **Documentation**: Built-in Rails documentation
- **Testing**: Rails Testing Framework

---

## Deployment Information

### Production Environment
- **Platform**: Render.com
- **URL**: https://dr-wise-ag.onrender.com/
- **Database**: PostgreSQL (Render-managed)
- **File Storage**: Cloudflare R2
- **Domain**: Custom domain configured
- **SSL**: Automatically managed by Render

### Environment Variables (Production)
```bash
# Database
DATABASE_URL=postgresql://...

# Application
RAILS_ENV=production
RACK_ENV=production
RAILS_MASTER_KEY=<master_key>

# Cloudflare R2
R2_ACCESS_KEY_ID=<access_key>
R2_SECRET_ACCESS_KEY=<secret_key>
R2_REGION=auto
R2_BUCKET=<bucket_name>
R2_ENDPOINT=<endpoint_url>

# Email Configuration
SMTP_USERNAME=<smtp_user>
SMTP_PASSWORD=<smtp_pass>
SMTP_ADDRESS=<smtp_server>
SMTP_PORT=587

# Security
SECRET_KEY_BASE=<secret_key>
```

### Deployment Process
1. Code pushed to GitHub repository
2. Render automatically detects changes
3. Build process runs:
   - Bundle install
   - Asset precompilation
   - Database migrations
4. New version deployed with zero downtime
5. Health checks validate deployment

---

## Database Schema

### Core Entities

#### Users Table
```sql
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR NOT NULL UNIQUE,
  mobile VARCHAR,
  first_name VARCHAR,
  last_name VARCHAR,
  user_type VARCHAR, -- 'admin', 'customer', 'agent', 'sub_agent'
  status BOOLEAN DEFAULT true,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

#### Customers Table
```sql
CREATE TABLE customers (
  id BIGSERIAL PRIMARY KEY,
  customer_type VARCHAR NOT NULL, -- 'individual', 'corporate'
  first_name VARCHAR,
  last_name VARCHAR,
  company_name VARCHAR,
  email VARCHAR UNIQUE,
  mobile VARCHAR UNIQUE,
  birth_date DATE,
  gender VARCHAR,
  address TEXT,
  city VARCHAR,
  state VARCHAR,
  pincode VARCHAR,
  pan_no VARCHAR,
  nominee_name VARCHAR NOT NULL,
  nominee_relation VARCHAR NOT NULL,
  nominee_date_of_birth DATE NOT NULL,
  status BOOLEAN DEFAULT true,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

#### Insurance Policy Tables

**Health Insurance**
```sql
CREATE TABLE health_insurances (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT REFERENCES customers(id),
  sub_agent_id BIGINT REFERENCES sub_agents(id),
  policy_holder VARCHAR NOT NULL,
  insurance_company_name VARCHAR NOT NULL,
  policy_type VARCHAR NOT NULL, -- 'New', 'Renewal', 'Porting'
  insurance_type VARCHAR NOT NULL, -- 'Individual', 'Family Floater', 'Group'
  policy_number VARCHAR,
  policy_booking_date DATE NOT NULL,
  policy_start_date DATE NOT NULL,
  policy_end_date DATE NOT NULL,
  payment_mode VARCHAR NOT NULL,
  sum_insured DECIMAL NOT NULL,
  net_premium DECIMAL NOT NULL,
  gst_percentage DECIMAL,
  total_premium DECIMAL NOT NULL,
  commission_amount DECIMAL,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

**Life Insurance**
```sql
CREATE TABLE life_insurances (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT REFERENCES customers(id),
  sub_agent_id BIGINT REFERENCES sub_agents(id),
  policy_holder VARCHAR NOT NULL,
  insurance_company_name VARCHAR NOT NULL,
  policy_type VARCHAR NOT NULL,
  policy_number VARCHAR,
  policy_booking_date DATE NOT NULL,
  policy_start_date DATE NOT NULL,
  policy_end_date DATE NOT NULL,
  sum_insured DECIMAL NOT NULL,
  net_premium DECIMAL NOT NULL,
  total_premium DECIMAL NOT NULL,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

**Motor Insurance**
```sql
CREATE TABLE motor_insurances (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT REFERENCES customers(id),
  sub_agent_id BIGINT REFERENCES sub_agents(id),
  policy_holder VARCHAR NOT NULL,
  insurance_company_name VARCHAR NOT NULL,
  policy_type VARCHAR NOT NULL,
  vehicle_type VARCHAR,
  make VARCHAR,
  model VARCHAR,
  variant VARCHAR,
  year_of_manufacture INTEGER,
  registration_number VARCHAR,
  policy_number VARCHAR,
  policy_start_date DATE NOT NULL,
  policy_end_date DATE NOT NULL,
  idv_amount DECIMAL,
  net_premium DECIMAL NOT NULL,
  total_premium DECIMAL NOT NULL,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

#### Lead Management
```sql
CREATE TABLE leads (
  id BIGSERIAL PRIMARY KEY,
  lead_id VARCHAR UNIQUE NOT NULL,
  name VARCHAR NOT NULL,
  contact_number VARCHAR NOT NULL,
  email VARCHAR,
  first_name VARCHAR,
  last_name VARCHAR,
  company_name VARCHAR,
  product_category VARCHAR NOT NULL, -- 'insurance', 'investments', 'loans'
  product_subcategory VARCHAR NOT NULL,
  current_stage VARCHAR NOT NULL, -- 'lead_generated', 'consultation_scheduled', etc.
  customer_type VARCHAR NOT NULL, -- 'individual', 'corporate'
  is_direct BOOLEAN DEFAULT false,
  affiliate_id BIGINT REFERENCES sub_agents(id),
  converted_customer_id BIGINT REFERENCES customers(id),
  stage_updated_at TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

#### Commission & Payout System
```sql
CREATE TABLE commission_payouts (
  id BIGSERIAL PRIMARY KEY,
  policy_type VARCHAR NOT NULL,
  policy_id BIGINT NOT NULL,
  payout_to VARCHAR NOT NULL, -- 'sub_agent', 'ambassador', 'investor'
  recipient_id BIGINT,
  payout_amount DECIMAL NOT NULL,
  payout_percentage DECIMAL,
  status VARCHAR DEFAULT 'pending', -- 'pending', 'paid', 'cancelled'
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Key Relationships
- **Customers** → **Policies** (One-to-Many)
- **Sub-Agents** → **Customers** (One-to-Many)
- **Sub-Agents** → **Policies** (One-to-Many)
- **Policies** → **Commission Payouts** (One-to-Many)
- **Leads** → **Customers** (One-to-One after conversion)

---

## Feature Documentation

### 1. Admin Dashboard
**Location**: `/admin/customers` (root path)
**Purpose**: Central hub for system overview and quick access

#### Features:
- **Real-time Analytics**: Live KPI cards with growth indicators
- **Quick Stats**:
  - Total customers, policies, premium collected
  - Active affiliates, conversion rates
  - Commission due and paid amounts
- **Interactive Charts**:
  - Policy distribution by type
  - Monthly trends (customers, policies, premium)
  - Lead conversion funnel
  - Geographic distribution
- **Recent Activities**: Latest policies and leads
- **Expiring Policies**: Policies requiring attention
- **Performance Metrics**: Top-performing agents

#### Technical Implementation:
- Cached analytics using `AnalyticsCache` model
- Real-time updates via AJAX
- Chart.js integration via Chartkick
- PostgreSQL optimized queries with indexes

### 2. Customer Management System
**Location**: `/admin/customers`
**Purpose**: Complete customer lifecycle management

#### Features:
- **Customer Creation**:
  - Individual and corporate customer types
  - Comprehensive data validation
  - Automatic lead conversion
  - Document attachment support
- **Customer Portfolio View**:
  - All policies across insurance types
  - Commission tracking
  - Document management
  - Family member management
- **Search & Filtering**:
  - Full-text search using pg_search
  - Filter by status, type, location
  - Export functionality
- **Customer Deactivation**: Soft delete with restoration

#### Data Validation:
- Email format validation
- Indian mobile number validation (10 digits, starts with 6-9)
- PAN card format validation
- GST number validation for corporate customers
- Mandatory nominee information

### 3. Policy Management System

#### Health Insurance (`/admin/insurance/health`)
- **Policy Types**: New, Renewal, Porting
- **Insurance Types**: Individual, Family Floater, Group
- **Member Management**: Family member addition
- **Renewal System**: Automated renewal workflow
- **Commission Calculation**: Automatic calculation with TDS

#### Life Insurance (`/admin/insurance/life`)
- **Policy Types**: Term, ULIP, Endowment, Whole Life
- **Nominee Management**: Multiple nominees with share percentages
- **Bank Details**: Account information for payouts
- **Maturity Tracking**: Policy maturity date management

#### Motor Insurance (`/admin/insurance/motor`)
- **Vehicle Information**: Make, model, variant details
- **IDV Calculation**: Insured Declared Value
- **Add-on Covers**: Zero depreciation, engine protection, etc.
- **Renewal Management**: Automated renewal notifications

#### Other Insurance (`/admin/insurance/other`)
- **Flexible Insurance Types**: Travel, Property, etc.
- **Custom Fields**: Adaptable to various insurance products
- **Document Management**: Policy-specific document storage

### 4. Lead Management System
**Location**: `/admin/leads`
**Purpose**: Lead tracking and conversion management

#### Lead Stages:
1. **Lead Generated**: Initial lead creation
2. **Consultation Scheduled**: First contact scheduled
3. **One-on-One**: Detailed discussion
4. **Follow-up**: Active follow-up process
5. **Follow-up Successful**: Positive response
6. **Follow-up Unsuccessful**: Negative response
7. **Not Interested**: Customer declined
8. **Re-follow Up**: Additional attempt
9. **Converted**: Lead converted to customer
10. **Lead Closed**: End of lead lifecycle

#### Features:
- **Kanban View**: Visual pipeline management
- **Stage Progression**: Flexible stage advancement
- **Conversion Tracking**: Lead to customer conversion
- **Branch Out**: Create multiple leads from single customer
- **Performance Analytics**: Conversion rates and funnel analysis

### 5. Commission & Payout System
**Location**: `/admin/payouts`, `/admin/commission_tracking`
**Purpose**: Automated commission calculation and distribution

#### Commission Structure:
- **Main Agent Commission**: Primary commission (typically 10%)
- **Sub-Agent Commission**: Affiliate commission (typically 2-3%)
- **Ambassador Commission**: Distributor commission (typically 2-3%)
- **Investor Commission**: Investor share (typically 1-2%)
- **Company Expenses**: Operational costs (typically 2-5%)
- **Profit Calculation**: Remaining amount after distributions

#### Payout Process:
1. **Automatic Calculation**: On policy creation
2. **Commission Distribution**: Based on predefined percentages
3. **TDS Calculation**: Tax deduction at source
4. **Payout Approval**: Admin review and approval
5. **Payment Processing**: Mark as paid/processed
6. **Audit Trail**: Complete transaction history

#### Features:
- **Real-time Commission Tracking**: Live commission calculations
- **Bulk Payout Processing**: Mass payout operations
- **Commission Reports**: Detailed reporting with exports
- **Audit Logs**: Complete transaction history
- **Payment Status Management**: Track payment lifecycle

### 6. Document Management System
**Location**: Integrated across all modules
**Purpose**: Cloud-based document storage and management

#### Storage Backend: Cloudflare R2
- **S3-compatible API**: Standard AWS SDK integration
- **Global CDN**: Fast document delivery worldwide
- **Security**: Secure access with signed URLs
- **Scalability**: Unlimited storage capacity

#### Document Types:
- **Policy Documents**: Insurance policy PDFs
- **Customer Documents**: KYC documents, ID proofs
- **Agent Documents**: License, certifications
- **Investor Documents**: Legal documents, agreements
- **System Documents**: Templates, forms

#### Features:
- **Drag & Drop Upload**: User-friendly interface
- **File Type Validation**: Security and compatibility checks
- **Version Control**: Document version management
- **Bulk Upload**: Mass document processing
- **Download Management**: Secure download links
- **Document Preview**: In-browser document viewing

### 7. Reporting System
**Location**: `/admin/reports`
**Purpose**: Comprehensive business intelligence and reporting

#### Report Types:
- **Commission Reports**: Detailed commission analysis
- **Policy Reports**: Policy performance metrics
- **Lead Reports**: Lead conversion analytics
- **Expired Insurance Reports**: Renewal opportunities
- **Payment Due Reports**: Outstanding payment tracking
- **Session Reports**: User activity monitoring

#### Export Formats:
- **PDF**: Professional formatted reports
- **Excel**: Data manipulation and analysis
- **CSV**: Raw data export

#### Features:
- **Dynamic Filtering**: Custom date ranges and criteria
- **Scheduled Reports**: Automated report generation
- **Real-time Data**: Live data integration
- **Visual Analytics**: Charts and graphs
- **Saved Reports**: Bookmark frequently used reports

### 8. Import/Export System
**Location**: `/admin/imports`
**Purpose**: Bulk data processing and migration

#### Supported Entities:
- Customers (Individual and Corporate)
- Sub-Agents/Affiliates
- Distributors/Ambassadors
- Health Insurance Policies
- Life Insurance Policies
- Motor Insurance Policies

#### Import Process:
1. **Template Download**: Standardized Excel templates
2. **Data Validation**: Client-side and server-side validation
3. **Preview Mode**: Review data before import
4. **Batch Processing**: Process large datasets efficiently
5. **Error Reporting**: Detailed error logs and corrections
6. **Success Confirmation**: Import summary and statistics

#### Features:
- **Template Generation**: Dynamic template creation
- **Data Mapping**: Flexible column mapping
- **Validation Rules**: Comprehensive data validation
- **Error Handling**: Graceful error management
- **Progress Tracking**: Real-time import progress

---

## API Documentation

### Authentication
All API endpoints require authentication via Bearer token.

**Login Endpoint**: `POST /api/v1/auth/login`
```json
{
  "email": "user@example.com",
  "password": "password",
  "role": "admin|customer|agent|sub_agent"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "username": "John Doe",
    "role": "admin",
    "user_id": 123
  }
}
```

### Core API Endpoints

#### Customer Management
- `GET /api/v1/customers` - List customers
- `POST /api/v1/customers` - Create customer
- `GET /api/v1/customers/:id` - Get customer details
- `PUT /api/v1/customers/:id` - Update customer
- `DELETE /api/v1/customers/:id` - Delete customer

#### Health Insurance
- `GET /api/v1/health_insurances` - List policies
- `POST /api/v1/health_insurances` - Create policy
- `GET /api/v1/health_insurances/:id` - Get policy details
- `PUT /api/v1/health_insurances/:id` - Update policy

#### Sub-Agent Management
- `GET /api/v1/sub_agents` - List sub-agents
- `POST /api/v1/sub_agents` - Create sub-agent
- `PATCH /api/v1/sub_agents/:id/toggle_status` - Toggle status

#### Notifications
- `GET /api/v1/notifications` - List notifications
- `PATCH /api/v1/notifications/:id/mark_as_read` - Mark as read
- `GET /api/v1/notifications/unread_count` - Get unread count

---

## Mobile API Documentation

### Base URL
`https://dr-wise-ag.onrender.com/api/v1/mobile`

### Authentication Flow

#### 1. Login
**Endpoint**: `POST /api/v1/mobile/auth/login`

**Request Body**:
```json
{
  "login": "email@example.com", // or mobile number or PAN
  "password": "password123",
  "role": "client|sub_agent" // optional for role-specific login
}
```

**Response (Customer)**:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "username": "John Doe",
    "role": "customer",
    "user_id": 123,
    "customer_id": 456,
    "email": "john@example.com",
    "mobile": "9876543210",
    "password_reset_days": 180,
    "password_reset_required": false,
    "portfolio_summary": {
      "total_policies": 3,
      "upcoming_installments": 1,
      "renewal_policies": 2
    }
  }
}
```

**Response (Sub-Agent)**:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "username": "Agent Name",
    "role": "sub_agent",
    "user_id": 789,
    "commission_earned": "₹45,000",
    "customers_count": 25,
    "policies_count": 30,
    "monthly_target": 50000,
    "achievement_percentage": 90.0,
    "dashboard_stats": {
      "total_commission": "₹45,000",
      "monthly_target": 50000,
      "achievement_percentage": 90.0,
      "policies_this_month": 8,
      "customers_this_month": 6,
      "conversion_rate": "75%",
      "ranking": 3,
      "team_size": 25,
      "performance_grade": "B+"
    },
    "agency_info": {
      "agency_name": "Agent Name Agency",
      "license_number": "AGY000789",
      "territory": "North Zone",
      "join_date": "2023-01-15"
    }
  }
}
```

#### 2. Registration
**Endpoint**: `POST /api/v1/mobile/auth/register`

**Customer Registration**:
```json
{
  "role": "customer",
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "mobile": "9876543210",
  "password": "password123",
  "password_confirmation": "password123",
  "birth_date": "1990-01-01",
  "gender": "male",
  "address": "123 Main St",
  "city": "Mumbai",
  "state": "Maharashtra",
  "pincode": "400001",
  "nominee_name": "Jane Doe",
  "nominee_relation": "spouse",
  "nominee_date_of_birth": "1992-01-01"
}
```

**Agent Registration**:
```json
{
  "role": "agent",
  "first_name": "Agent",
  "last_name": "Name",
  "email": "agent@example.com",
  "mobile": "9876543210",
  "password": "password123",
  "pan_no": "ABCDE1234F",
  "address": "Agency Address",
  "city": "Delhi",
  "state": "Delhi"
}
```

#### 3. Forgot Password
**Endpoint**: `POST /api/v1/mobile/auth/forgot_password`

```json
{
  "email": "user@example.com"
}
```

### Customer Module APIs

#### Portfolio Management
**Endpoint**: `GET /api/v1/mobile/customer/portfolio`

**Response**:
```json
{
  "success": true,
  "data": {
    "total_policies": 3,
    "total_coverage": "₹15,00,000",
    "total_premium_paid": "₹45,000",
    "policies": [
      {
        "id": 123,
        "type": "Health Insurance",
        "policy_number": "HI-2024-001",
        "insurance_company": "HDFC ERGO",
        "sum_insured": "₹5,00,000",
        "premium_amount": "₹15,000",
        "policy_start_date": "2024-01-01",
        "policy_end_date": "2024-12-31",
        "status": "active",
        "next_premium_due": "2024-06-01"
      }
    ]
  }
}
```

#### Upcoming Installments
**Endpoint**: `GET /api/v1/mobile/customer/upcoming_installments`

**Response**:
```json
{
  "success": true,
  "data": {
    "installments": [
      {
        "policy_id": 123,
        "policy_number": "HI-2024-001",
        "installment_amount": "₹7,500",
        "due_date": "2024-06-01",
        "installment_type": "Half-yearly",
        "status": "pending"
      }
    ]
  }
}
```

#### Renewal Policies
**Endpoint**: `GET /api/v1/mobile/customer/upcoming_renewals`

**Response**:
```json
{
  "success": true,
  "data": {
    "renewals": [
      {
        "policy_id": 456,
        "policy_number": "LI-2023-005",
        "insurance_company": "LIC",
        "renewal_date": "2024-07-15",
        "current_premium": "₹20,000",
        "coverage_amount": "₹10,00,000",
        "days_to_renewal": 45
      }
    ]
  }
}
```

#### Add New Policy
**Endpoint**: `POST /api/v1/mobile/customer/add_policy`

```json
{
  "policy_type": "health|life|motor|other",
  "insurance_company": "HDFC ERGO",
  "policy_number": "POL-123456",
  "sum_insured": 500000,
  "premium_amount": 15000,
  "policy_start_date": "2024-01-01",
  "policy_end_date": "2024-12-31",
  "payment_mode": "yearly"
}
```

### Agent Module APIs

#### Dashboard
**Endpoint**: `GET /api/v1/mobile/agent/dashboard`

**Response**:
```json
{
  "success": true,
  "data": {
    "summary": {
      "total_customers": 25,
      "total_policies": 30,
      "total_commission": "₹45,000",
      "monthly_target": "₹50,000",
      "achievement_percentage": 90.0
    },
    "recent_activities": [
      {
        "type": "policy_created",
        "description": "Health policy created for John Doe",
        "date": "2024-01-15",
        "amount": "₹15,000"
      }
    ],
    "upcoming_renewals": 5,
    "pending_documents": 3
  }
}
```

#### Customer Management
**Endpoint**: `GET /api/v1/mobile/agent/customers`

**Response**:
```json
{
  "success": true,
  "data": {
    "customers": [
      {
        "id": 123,
        "name": "John Doe",
        "email": "john@example.com",
        "mobile": "9876543210",
        "total_policies": 2,
        "total_premium": "₹25,000",
        "last_policy_date": "2024-01-15",
        "status": "active"
      }
    ],
    "pagination": {
      "current_page": 1,
      "total_pages": 5,
      "total_count": 25
    }
  }
}
```

#### Add Customer
**Endpoint**: `POST /api/v1/mobile/agent/customers`

```json
{
  "customer_type": "individual",
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "mobile": "9876543210",
  "birth_date": "1990-01-01",
  "address": "123 Main St",
  "city": "Mumbai",
  "state": "Maharashtra",
  "nominee_name": "Jane Doe",
  "nominee_relation": "spouse",
  "nominee_date_of_birth": "1992-01-01"
}
```

#### Policy Management
**Endpoint**: `GET /api/v1/mobile/agent/policies`

**Add Health Policy**: `POST /api/v1/mobile/agent/policies/health`
**Add Life Policy**: `POST /api/v1/mobile/agent/policies/life`
**Add Motor Policy**: `POST /api/v1/mobile/agent/policies/motor`

### Lead Management APIs

#### Get Leads
**Endpoint**: `GET /api/v1/mobile/agent/leads`

**Response**:
```json
{
  "success": true,
  "data": {
    "leads": [
      {
        "id": 123,
        "lead_id": "LEAD-2024-001",
        "name": "Potential Customer",
        "contact_number": "9876543210",
        "email": "potential@example.com",
        "product_category": "insurance",
        "product_subcategory": "health",
        "current_stage": "consultation_scheduled",
        "created_date": "2024-01-10",
        "last_contact_date": "2024-01-12"
      }
    ]
  }
}
```

#### Add Lead
**Endpoint**: `POST /api/v1/mobile/agent/leads`

```json
{
  "name": "Potential Customer",
  "contact_number": "9876543210",
  "email": "potential@example.com",
  "product_category": "insurance",
  "product_subcategory": "health",
  "customer_type": "individual",
  "lead_source": "agent_referral",
  "notes": "Interested in family health insurance"
}
```

### Commission APIs

#### Commission Breakdown
**Endpoint**: `GET /api/v1/mobile/commission/breakdown`

**Response**:
```json
{
  "success": true,
  "data": {
    "total_commission": "₹45,000",
    "breakdown": {
      "health_insurance": "₹20,000",
      "life_insurance": "₹18,000",
      "motor_insurance": "₹7,000"
    },
    "monthly_breakdown": [
      {
        "month": "January 2024",
        "amount": "₹15,000",
        "policies": 8
      }
    ]
  }
}
```

#### Commission History
**Endpoint**: `GET /api/v1/mobile/commission/history`

**Response**:
```json
{
  "success": true,
  "data": {
    "commissions": [
      {
        "id": 123,
        "policy_type": "health",
        "policy_number": "HI-2024-001",
        "customer_name": "John Doe",
        "commission_amount": "₹1,500",
        "commission_percentage": 3.0,
        "earned_date": "2024-01-15",
        "status": "paid"
      }
    ]
  }
}
```

### Settings APIs

#### Get Profile
**Endpoint**: `GET /api/v1/mobile/settings/profile`

**Response**:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 123,
      "name": "John Doe",
      "email": "john@example.com",
      "mobile": "9876543210",
      "role": "customer",
      "profile_image_url": "https://...",
      "address": "123 Main St",
      "city": "Mumbai",
      "state": "Maharashtra"
    }
  }
}
```

#### Update Profile
**Endpoint**: `PUT /api/v1/mobile/settings/profile`

```json
{
  "first_name": "John",
  "last_name": "Doe",
  "email": "john.doe@example.com",
  "mobile": "9876543210",
  "address": "New Address",
  "city": "Delhi",
  "state": "Delhi"
}
```

#### Change Password
**Endpoint**: `POST /api/v1/mobile/settings/change_password`

```json
{
  "current_password": "oldpassword123",
  "new_password": "newpassword123",
  "new_password_confirmation": "newpassword123"
}
```

### Helpdesk APIs

#### Create Ticket
**Endpoint**: `POST /api/v1/mobile/customer/helpdesk`

```json
{
  "subject": "Policy Renewal Question",
  "description": "I need help with renewing my health insurance policy",
  "category": "policy_inquiry",
  "priority": "medium"
}
```

#### Get Tickets
**Endpoint**: `GET /api/v1/mobile/customer/helpdesk_tickets`

**Response**:
```json
{
  "success": true,
  "data": {
    "tickets": [
      {
        "id": 123,
        "ticket_number": "TKT-2024-001",
        "subject": "Policy Renewal Question",
        "status": "open",
        "priority": "medium",
        "created_at": "2024-01-15T10:00:00Z",
        "last_response": "2024-01-15T14:30:00Z"
      }
    ]
  }
}
```

### Banner APIs

#### Get Active Banners
**Endpoint**: `GET /api/v1/mobile/banners/active`

**Response**:
```json
{
  "success": true,
  "data": {
    "banners": [
      {
        "id": 123,
        "title": "Special Health Insurance Offer",
        "description": "Get 20% discount on family health insurance",
        "image_url": "https://...",
        "action_url": "/health-insurance",
        "display_order": 1,
        "valid_until": "2024-12-31"
      }
    ]
  }
}
```

### Notification APIs

#### Get Notifications
**Endpoint**: `GET /api/v1/mobile/sub_agent/notifications`

**Response**:
```json
{
  "success": true,
  "data": {
    "notifications": [
      {
        "id": 123,
        "title": "New Comment on Support Ticket",
        "message": "An admin has added a comment to your support ticket",
        "notification_type": "helpdesk_comment_added",
        "is_read": false,
        "sent_at": "2024-01-15T10:00:00Z"
      }
    ],
    "unread_count": 3
  }
}
```

#### Mark as Read
**Endpoint**: `PUT /api/v1/mobile/sub_agent/notifications/:id/mark_read`

#### Get Unread Count
**Endpoint**: `GET /api/v1/mobile/sub_agent/notifications/unread_count`

### Error Handling

All API endpoints return consistent error responses:

**Validation Error (422)**:
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": [
    "Email is required",
    "Mobile number must be 10 digits"
  ]
}
```

**Authentication Error (401)**:
```json
{
  "success": false,
  "message": "Invalid username or password"
}
```

**Authorization Error (403)**:
```json
{
  "success": false,
  "message": "Access denied"
}
```

**Not Found Error (404)**:
```json
{
  "success": false,
  "message": "Resource not found"
}
```

**Server Error (500)**:
```json
{
  "success": false,
  "message": "Internal server error"
}
```

---

## Authentication & Authorization

### User Types & Roles
1. **Admin**: Full system access
2. **Customer**: Portfolio view and self-service
3. **Agent/Sub-Agent**: Customer and policy management
4. **Ambassador/Distributor**: Commission tracking
5. **Investor**: Investment and profit analytics

### Authentication Methods
- **Web Interface**: Devise-based session authentication
- **Mobile API**: JWT token-based authentication
- **Password Reset**: Email-based password recovery
- **Multi-factor Support**: Email verification

### Authorization System
- **Role-based Access Control**: Using CanCanCan
- **Resource-level Permissions**: Granular access control
- **API Authorization**: JWT token validation
- **Session Management**: Secure session handling

### Security Features
- **Password Encryption**: BCrypt hashing
- **SQL Injection Protection**: Parameterized queries
- **XSS Protection**: Built-in Rails security
- **CSRF Protection**: Token-based CSRF protection
- **Secure Headers**: Security header configuration

---

## Test Scenarios & Test Cases

### 1. User Authentication Tests

#### Test Case 1.1: Admin Login
**Scenario**: Admin user logs into the system
**Steps**:
1. Navigate to login page
2. Enter valid admin credentials
3. Click login button
**Expected Result**: Redirected to admin dashboard with full access

#### Test Case 1.2: Customer Mobile Login
**Scenario**: Customer logs in via mobile API
**Steps**:
1. Send POST request to `/api/v1/mobile/auth/login`
2. Include valid customer credentials with role="client"
3. Verify response contains JWT token
**Expected Result**: Successful login with portfolio data

#### Test Case 1.3: Invalid Login
**Scenario**: User attempts login with invalid credentials
**Steps**:
1. Enter incorrect email/password combination
2. Submit login form
**Expected Result**: Error message displayed, access denied

### 2. Customer Management Tests

#### Test Case 2.1: Create Individual Customer
**Scenario**: Admin creates a new individual customer
**Steps**:
1. Navigate to customers page
2. Click "Add New Customer"
3. Fill all required fields for individual customer
4. Include nominee information
5. Submit form
**Expected Result**: Customer created successfully with auto-generated lead ID

#### Test Case 2.2: Create Corporate Customer
**Scenario**: Admin creates a new corporate customer
**Steps**:
1. Select "Corporate" customer type
2. Fill company name, GST number, email, mobile
3. Add nominee details
4. Submit form
**Expected Result**: Corporate customer created with GST validation

#### Test Case 2.3: Customer Search
**Scenario**: Search for customers using various criteria
**Steps**:
1. Use search box with customer name
2. Search by mobile number
3. Search by email
4. Search by PAN number
**Expected Result**: Relevant customers displayed in results

### 3. Policy Management Tests

#### Test Case 3.1: Create Health Insurance Policy
**Scenario**: Create a new health insurance policy
**Steps**:
1. Navigate to Health Insurance section
2. Click "Add New Policy"
3. Select existing customer
4. Fill policy details (company, type, coverage, premium)
5. Add family members if Family Floater
6. Submit form
**Expected Result**: Policy created with automatic commission calculation

#### Test Case 3.2: Renew Existing Policy
**Scenario**: Renew a health insurance policy
**Steps**:
1. Find policy expiring within 60 days
2. Click "Renew" button
3. Review pre-filled renewal form
4. Adjust premium/coverage if needed
5. Submit renewal
**Expected Result**: New renewal policy created linked to original

#### Test Case 3.3: Policy Commission Calculation
**Scenario**: Verify commission calculation accuracy
**Steps**:
1. Create health insurance policy with ₹10,000 premium
2. Verify commission percentages applied correctly
3. Check TDS calculations
4. Verify commission payout records created
**Expected Result**: Commission calculated as per configured percentages

### 4. Lead Management Tests

#### Test Case 4.1: Lead Creation and Progression
**Scenario**: Create lead and move through stages
**Steps**:
1. Create new lead with customer details
2. Progress through stages: Generated → Consultation → One-on-One
3. Move to Follow-up stage
4. Convert to customer
**Expected Result**: Lead progresses through stages and converts to customer

#### Test Case 4.2: Lead Branch Out
**Scenario**: Create multiple leads from single customer
**Steps**:
1. Select existing customer
2. Click "Branch Out Lead"
3. Create lead for different product category
4. Verify lead created with customer association
**Expected Result**: New lead created without affecting original customer

#### Test Case 4.3: Kanban View Functionality
**Scenario**: Test drag-and-drop lead management
**Steps**:
1. Navigate to Kanban view
2. Drag lead from one stage to another
3. Verify stage update in database
4. Check stage transition timestamp
**Expected Result**: Lead stage updated with proper timestamp

### 5. Commission & Payout Tests

#### Test Case 5.1: Commission Distribution
**Scenario**: Test commission distribution to multiple parties
**Steps**:
1. Create policy with sub-agent, distributor, and investor assigned
2. Verify commission payouts created for each party
3. Check percentage calculations
4. Verify TDS deductions
**Expected Result**: Commission distributed correctly to all parties

#### Test Case 5.2: Bulk Payout Processing
**Scenario**: Process multiple payouts simultaneously
**Steps**:
1. Navigate to payouts section
2. Select multiple pending payouts
3. Click "Mark as Paid" bulk action
4. Verify status updates
**Expected Result**: All selected payouts marked as paid with audit trail

### 6. Document Management Tests

#### Test Case 6.1: Document Upload to R2
**Scenario**: Upload policy document to cloud storage
**Steps**:
1. Navigate to policy details page
2. Click "Upload Document"
3. Select PDF file and upload
4. Verify file uploaded to Cloudflare R2
5. Test document download
**Expected Result**: Document successfully uploaded and retrievable

#### Test Case 6.2: Bulk Document Upload
**Scenario**: Upload multiple documents simultaneously
**Steps**:
1. Navigate to document management section
2. Select multiple files for upload
3. Verify progress indicators
4. Check successful upload confirmation
**Expected Result**: All documents uploaded successfully with proper categorization

### 7. Import/Export Tests

#### Test Case 7.1: Customer Import
**Scenario**: Import customers from Excel file
**Steps**:
1. Download customer import template
2. Fill template with customer data
3. Upload filled template
4. Review preview data
5. Confirm import
**Expected Result**: Customers imported successfully with data validation

#### Test Case 7.2: Policy Import with Validation
**Scenario**: Import health insurance policies with data errors
**Steps**:
1. Upload policy data with missing required fields
2. Review error report
3. Correct errors in template
4. Re-import corrected data
**Expected Result**: Errors identified and corrected, successful import on retry

### 8. Reporting Tests

#### Test Case 8.1: Commission Report Generation
**Scenario**: Generate detailed commission report
**Steps**:
1. Navigate to Reports section
2. Select Commission Report
3. Set date range filters
4. Apply sub-agent filters
5. Generate report
6. Export to PDF and Excel
**Expected Result**: Accurate commission report generated with multiple export formats

#### Test Case 8.2: Policy Performance Report
**Scenario**: Generate policy performance analytics
**Steps**:
1. Select Policy Reports
2. Apply policy type filters
3. Set custom date range
4. Generate visual charts
5. Export data
**Expected Result**: Comprehensive policy performance report with charts

### 9. Mobile API Tests

#### Test Case 9.1: Customer Portfolio API
**Scenario**: Retrieve customer portfolio via mobile API
**Steps**:
1. Authenticate customer via mobile login
2. Call portfolio API with JWT token
3. Verify policy data returned
4. Check upcoming renewals included
**Expected Result**: Complete portfolio data returned in JSON format

#### Test Case 9.2: Agent Dashboard API
**Scenario**: Get agent dashboard data
**Steps**:
1. Authenticate sub-agent via mobile API
2. Call dashboard API
3. Verify commission data
4. Check customer statistics
5. Verify performance metrics
**Expected Result**: Comprehensive dashboard data with KPIs and statistics

### 10. Performance Tests

#### Test Case 10.1: Dashboard Load Performance
**Scenario**: Test dashboard loading with large dataset
**Steps**:
1. Ensure database has 10,000+ customers and policies
2. Navigate to admin dashboard
3. Measure page load time
4. Check analytics cache functionality
**Expected Result**: Dashboard loads within 3 seconds using cached data

#### Test Case 10.2: Search Performance
**Scenario**: Test customer search with large dataset
**Steps**:
1. Search for customers using partial name
2. Search using mobile number
3. Search using email
4. Measure response times
**Expected Result**: Search results returned within 1 second

### 11. Security Tests

#### Test Case 11.1: Authentication Security
**Scenario**: Test authentication bypass attempts
**Steps**:
1. Attempt to access admin pages without login
2. Try SQL injection in login form
3. Test XSS in input fields
4. Verify CSRF protection
**Expected Result**: All unauthorized access blocked, injections prevented

#### Test Case 11.2: Data Access Security
**Scenario**: Test role-based access control
**Steps**:
1. Login as customer role
2. Attempt to access admin functions
3. Try to view other customers' data
4. Test API endpoint authorization
**Expected Result**: Access restricted based on user role

### 12. Integration Tests

#### Test Case 12.1: End-to-End Customer Journey
**Scenario**: Complete customer lifecycle test
**Steps**:
1. Create lead via API
2. Convert lead to customer
3. Create health insurance policy
4. Upload policy documents
5. Generate commission payouts
6. Process renewal
**Expected Result**: Complete customer journey executes successfully

#### Test Case 12.2: Multi-User Workflow
**Scenario**: Test concurrent user operations
**Steps**:
1. Admin creates customer while agent creates lead
2. Multiple agents access system simultaneously
3. Concurrent policy creation
4. Verify data consistency
**Expected Result**: No data conflicts, consistent state maintained

---

## Configuration & Environment Setup

### Local Development Setup

#### Prerequisites
- Ruby 3.2.0 or higher
- Rails 8.0.4
- PostgreSQL 14+
- Node.js 18+ (for asset compilation)
- Yarn or npm

#### Installation Steps
1. **Clone Repository**
   ```bash
   git clone <repository_url>
   cd insurebook_admin
   ```

2. **Install Dependencies**
   ```bash
   bundle install
   npm install # or yarn install
   ```

3. **Database Setup**
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Environment Configuration**
   Create `.env` file:
   ```env
   DATABASE_URL=postgresql://localhost/insurebook_admin_development
   R2_ACCESS_KEY_ID=your_r2_access_key
   R2_SECRET_ACCESS_KEY=your_r2_secret_key
   R2_REGION=auto
   R2_BUCKET=your_bucket_name
   R2_ENDPOINT=your_r2_endpoint
   ```

5. **Start Development Server**
   ```bash
   rails server
   ```

### Production Environment Variables

#### Required Environment Variables
```bash
# Database
DATABASE_URL=postgresql://user:pass@host:port/database

# Application
RAILS_ENV=production
RACK_ENV=production
RAILS_MASTER_KEY=your_master_key
SECRET_KEY_BASE=your_secret_key

# Cloudflare R2 Storage
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_REGION=auto
R2_BUCKET=your_bucket_name
R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com

# Email Configuration (if needed)
SMTP_USERNAME=your_smtp_user
SMTP_PASSWORD=your_smtp_password
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=your-domain.com

# Optional
RAILS_LOG_LEVEL=info
RAILS_SERVE_STATIC_FILES=true
RAILS_FORCE_SSL=true
```

#### Performance Configuration
```bash
# Worker Configuration
WEB_CONCURRENCY=2
MAX_THREADS=5

# Memory Management
MALLOC_ARENA_MAX=2

# Cache Configuration
REDIS_URL=redis://localhost:6379/0 # if using Redis
```

### Configuration Files

#### Application Configuration (`config/application.rb`)
```ruby
config.time_zone = 'Asia/Kolkata'
config.active_storage.variant_processor = :mini_magick
config.force_ssl = Rails.env.production?
```

#### Database Configuration (`config/database.yml`)
```yaml
production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
  pool: <%= ENV["RAILS_MAX_THREADS"] || 5 %>
```

#### Storage Configuration (`config/storage.yml`)
```yaml
cloudflare_r2:
  service: S3
  access_key_id: <%= ENV["R2_ACCESS_KEY_ID"] %>
  secret_access_key: <%= ENV["R2_SECRET_ACCESS_KEY"] %>
  region: <%= ENV["R2_REGION"] %>
  bucket: <%= ENV["R2_BUCKET"] %>
  endpoint: <%= ENV["R2_ENDPOINT"] %>
  public: false
```

---

## File Storage & Document Management

### Cloudflare R2 Integration

#### Configuration
The system uses Cloudflare R2 (S3-compatible) for document storage:

```ruby
# config/initializers/r2.rb
R2_CLIENT = Aws::S3::Client.new(
  access_key_id: ENV['R2_ACCESS_KEY_ID'],
  secret_access_key: ENV['R2_SECRET_ACCESS_KEY'],
  region: ENV['R2_REGION'],
  endpoint: ENV['R2_ENDPOINT']
)
```

#### File Upload Process
1. **Client Upload**: Files uploaded via web interface or API
2. **Validation**: File type and size validation
3. **Processing**: File optimization and metadata extraction
4. **Storage**: Upload to R2 with organized folder structure
5. **Database Record**: File metadata stored in database
6. **Access Control**: Secure URL generation for downloads

#### Folder Structure
```
bucket/
├── customers/
│   ├── {customer_id}/
│   │   ├── profile_images/
│   │   ├── documents/
│   │   └── policies/
├── policies/
│   ├── health_insurance/
│   ├── life_insurance/
│   ├── motor_insurance/
│   └── other_insurance/
├── agents/
│   ├── sub_agents/
│   ├── distributors/
│   └── investors/
└── system/
    ├── templates/
    └── reports/
```

#### Security Features
- **Signed URLs**: Temporary access URLs with expiration
- **Access Control**: Role-based file access
- **Encryption**: Files encrypted in transit and at rest
- **Audit Trail**: File access logging

#### Document Types Supported
- **Policy Documents**: PDF, DOC, DOCX
- **Images**: JPEG, PNG, GIF, WebP
- **Spreadsheets**: XLS, XLSX, CSV
- **Certificates**: PDF scanned certificates

---

## Commission & Payout System

### Commission Structure

#### Standard Commission Rates
1. **Health Insurance**:
   - Main Agent: 10% of net premium
   - Sub-Agent: 2-3% of net premium
   - Ambassador: 2-3% of net premium
   - Investor: 1-2% of net premium
   - Company Expenses: 2-5% of net premium

2. **Life Insurance**:
   - First Year: 15-25% of net premium
   - Renewal Years: 5-7.5% of net premium
   - Sub-Agent: 3-5% of net premium
   - Ambassador: 2-4% of net premium

3. **Motor Insurance**:
   - Main Agent: 15-20% of net premium
   - Sub-Agent: 3-5% of net premium
   - Ambassador: 2-4% of net premium

#### Commission Calculation Flow
1. **Policy Creation**: Commission structure defined at policy creation
2. **Automatic Calculation**: System calculates commissions based on percentages
3. **TDS Deduction**: Tax deduction at source applied where applicable
4. **Payout Creation**: Commission payout records created for each recipient
5. **Approval Process**: Admin review and approval before payment
6. **Payment Processing**: Mark payouts as paid with payment details
7. **Audit Trail**: Complete transaction history maintained

#### Commission Formula
```
Net Premium = Total Premium - GST
Main Agent Commission = Net Premium × Main Agent %
Sub-Agent Commission = Net Premium × Sub-Agent %
Ambassador Commission = Net Premium × Ambassador %
Investor Commission = Net Premium × Investor %
Company Expenses = Net Premium × Company Expenses %
Profit = Net Premium - (All Commissions + Company Expenses)
```

#### TDS (Tax Deduction at Source)
- **Individual Agents**: 10% TDS on commission > ₹30,000 annually
- **Corporate Agents**: 2% TDS on all commissions
- **Automatic Calculation**: System applies TDS rules automatically
- **TDS Certificates**: Generated for annual filings

### Payout Management

#### Payout Lifecycle
1. **Pending**: Initial state after commission calculation
2. **Processing**: Under review or preparation for payment
3. **Paid**: Payment completed
4. **Cancelled**: Payout cancelled due to policy cancellation

#### Bulk Payout Operations
- **Selection**: Select multiple payouts by criteria
- **Validation**: Verify payout amounts and recipients
- **Processing**: Bulk status updates
- **Notification**: Automatic notifications to recipients
- **Reporting**: Bulk payout summary reports

#### Audit and Compliance
- **Transaction Log**: Every payout change logged with user and timestamp
- **Financial Reconciliation**: Monthly commission reconciliation reports
- **Tax Reporting**: Annual TDS and commission reports
- **Compliance Tracking**: Regulatory compliance monitoring

---

## Reporting System

### Report Categories

#### 1. Commission Reports
- **Commission Summary**: Total commission by agent/period
- **Commission Breakdown**: Detailed commission analysis
- **TDS Reports**: Tax deduction summaries
- **Payout History**: Payment tracking and status
- **Agent Performance**: Commission-based performance metrics

#### 2. Policy Reports
- **Policy Portfolio**: Complete policy overview
- **Policy Performance**: Premium and coverage analysis
- **Renewal Reports**: Renewal rates and opportunities
- **Expired Policies**: Policies requiring attention
- **New Business**: Fresh policy acquisition metrics

#### 3. Customer Reports
- **Customer Analytics**: Customer demographic analysis
- **Customer Portfolio**: Individual customer policy summary
- **Customer Retention**: Retention rates and factors
- **Customer Acquisition**: New customer metrics

#### 4. Financial Reports
- **Revenue Analysis**: Premium collection and trends
- **Profit Reports**: Profit margins and distribution
- **Outstanding Payments**: Pending payment tracking
- **Financial Dashboard**: Key financial indicators

#### 5. Operational Reports
- **Lead Conversion**: Lead to customer conversion metrics
- **Agent Activity**: Agent productivity and performance
- **System Usage**: User activity and engagement
- **Document Compliance**: Document upload and verification status

### Report Generation Process

#### 1. Dynamic Report Builder
- **Filter Selection**: Date ranges, agents, policy types, customers
- **Data Source Selection**: Choose relevant data tables
- **Calculation Engine**: Apply business rules and calculations
- **Format Selection**: PDF, Excel, CSV output formats

#### 2. Scheduled Reports
- **Daily Reports**: Daily business summaries
- **Weekly Reports**: Weekly performance reports
- **Monthly Reports**: Monthly commission and performance reports
- **Quarterly Reports**: Quarterly business reviews

#### 3. Real-time Reports
- **Live Dashboards**: Real-time KPI monitoring
- **Instant Queries**: On-demand report generation
- **Alert System**: Threshold-based notifications

### Export Capabilities

#### Excel Export Features
- **Formatted Sheets**: Professional Excel formatting
- **Multiple Worksheets**: Separate sheets for different data sets
- **Charts and Graphs**: Embedded Excel charts
- **Formulas**: Excel formulas for further analysis

#### PDF Report Features
- **Professional Layout**: Company branding and formatting
- **Charts and Graphs**: Integrated visual analytics
- **Summary Sections**: Executive summary pages
- **Detailed Data**: Complete data appendices

#### CSV Export
- **Raw Data**: Unformatted data for analysis
- **Custom Delimiters**: Flexible field separation
- **Large Datasets**: Efficient handling of large data exports

---

## Import/Export Functionality

### Import System

#### Supported Import Types
1. **Customer Import**: Individual and corporate customers
2. **Sub-Agent Import**: Agent/affiliate information
3. **Distributor Import**: Ambassador/distributor data
4. **Health Insurance Import**: Health policy data
5. **Life Insurance Import**: Life policy data
6. **Motor Insurance Import**: Motor policy data

#### Import Process Flow
1. **Template Download**: Standardized Excel templates
2. **Data Preparation**: Customer prepares data in template format
3. **File Upload**: Upload Excel file through web interface
4. **Data Validation**: Server-side validation of all data
5. **Preview Mode**: Review and verify data before import
6. **Error Reporting**: Detailed error logs for corrections
7. **Batch Processing**: Process valid records in batches
8. **Success Report**: Import summary and statistics

#### Validation Rules

**Customer Validation**:
- Email format and uniqueness
- Mobile number format (10 digits, starts with 6-9)
- PAN number format (if provided)
- Required nominee information
- Address validation

**Policy Validation**:
- Customer existence verification
- Date range validation
- Premium amount validation
- Commission percentage limits
- Insurance company validation

#### Error Handling
- **Field-level Errors**: Specific field validation errors
- **Row-level Errors**: Complete record validation
- **Business Rule Errors**: Complex business logic validation
- **Duplicate Detection**: Prevent duplicate record creation

### Export System

#### Export Capabilities
- **Filtered Exports**: Export based on search criteria
- **Date Range Exports**: Time-period specific exports
- **Custom Field Selection**: Choose specific fields to export
- **Multiple Formats**: CSV, Excel, PDF exports

#### Bulk Operations
- **Mass Updates**: Bulk status changes
- **Mass Deletions**: Bulk record removal (with confirmation)
- **Mass Assignments**: Bulk agent assignments
- **Mass Notifications**: Bulk communication

---

## Performance Optimizations

### Database Optimizations

#### Indexing Strategy
```sql
-- Customer search optimization
CREATE INDEX idx_customers_search ON customers (email, mobile, first_name, last_name);

-- Policy lookup optimization
CREATE INDEX idx_health_insurance_customer ON health_insurances (customer_id);
CREATE INDEX idx_health_insurance_agent ON health_insurances (sub_agent_id);
CREATE INDEX idx_health_insurance_dates ON health_insurances (policy_start_date, policy_end_date);

-- Commission optimization
CREATE INDEX idx_commission_payouts_policy ON commission_payouts (policy_type, policy_id);
CREATE INDEX idx_commission_payouts_recipient ON commission_payouts (payout_to, recipient_id);

-- Lead management optimization
CREATE INDEX idx_leads_stage ON leads (current_stage);
CREATE INDEX idx_leads_affiliate ON leads (affiliate_id);
```

#### Query Optimization
- **Eager Loading**: Prevent N+1 queries with `includes`
- **Selective Fields**: Use `select` to limit returned columns
- **Batch Processing**: Process large datasets in batches
- **Connection Pooling**: Optimize database connections

### Caching Strategy

#### Analytics Caching
```ruby
# AnalyticsCache model for expensive calculations
class AnalyticsCache < ApplicationRecord
  def self.cache_fresh?(identifier, max_age = 1.hour)
    cache_record = find_by(cache_identifier: identifier)
    cache_record&.last_updated &&
    cache_record.last_updated > max_age.ago
  end
end
```

#### Application-level Caching
- **Fragment Caching**: Cache expensive view components
- **Action Caching**: Cache entire controller actions
- **Model Caching**: Cache expensive model calculations
- **Query Caching**: Cache frequent database queries

### Frontend Optimizations

#### Asset Optimization
- **CSS Bundling**: Combine and minify CSS files
- **JavaScript Modules**: Use ES6 modules with Importmap
- **Image Optimization**: Compress and optimize images
- **Lazy Loading**: Load images on demand

#### Performance Monitoring
- **Response Times**: Monitor page load times
- **Database Queries**: Track query performance
- **Memory Usage**: Monitor application memory
- **Error Tracking**: Track and resolve performance issues

---

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Login Issues
**Problem**: Users cannot log in
**Solutions**:
- Check user status (active/inactive)
- Verify password reset requirements
- Check email/mobile format validation
- Verify database connectivity

**Debug Steps**:
```bash
# Check user status
rails console
user = User.find_by(email: 'user@example.com')
user.status # Should be true
user.password_reset_required? # Check if reset needed
```

#### 2. File Upload Issues
**Problem**: Documents not uploading to R2
**Solutions**:
- Verify R2 credentials in environment variables
- Check bucket permissions
- Validate file size and type restrictions
- Check network connectivity to R2 endpoint

**Debug Steps**:
```bash
# Test R2 connection
rails console
R2_CLIENT.list_objects(bucket: ENV['R2_BUCKET'])
```

#### 3. Commission Calculation Issues
**Problem**: Incorrect commission calculations
**Solutions**:
- Verify commission percentage configurations
- Check TDS calculation settings
- Review policy premium amounts
- Validate business logic in commission service

**Debug Steps**:
```ruby
# Check commission calculation
policy = HealthInsurance.find(id)
policy.calculate_commission_structure
puts policy.commission_breakdown
```

#### 4. Import Errors
**Problem**: Data import failures
**Solutions**:
- Check Excel template format
- Validate required fields
- Verify data type conversions
- Check for duplicate records

**Debug Steps**:
```ruby
# Test import validation
ImportService.new.validate_customer_data(file_path)
```

#### 5. Performance Issues
**Problem**: Slow page loading
**Solutions**:
- Check analytics cache status
- Review database query performance
- Optimize large dataset handling
- Consider pagination improvements

**Debug Steps**:
```bash
# Check cache status
rails console
AnalyticsCache.where(cache_identifier: 'main_analytics').last&.last_updated

# Check slow queries
tail -f log/production.log | grep "Duration:"
```

#### 6. API Authentication Issues
**Problem**: Mobile API authentication failures
**Solutions**:
- Verify JWT token generation
- Check token expiration
- Validate API endpoint permissions
- Review CORS configuration

**Debug Steps**:
```ruby
# Test token generation
user = User.find(id)
token = JWT.encode({user_id: user.id, exp: 30.days.from_now.to_i}, Rails.application.secret_key_base)
decoded = JWT.decode(token, Rails.application.secret_key_base)
```

### Database Issues

#### Migration Problems
```bash
# Check migration status
rails db:migrate:status

# Rollback problematic migration
rails db:rollback STEP=1

# Reset database (development only)
rails db:drop db:create db:migrate db:seed
```

#### Connection Issues
```bash
# Test database connection
rails db:version

# Check database configuration
rails console
ActiveRecord::Base.connection.execute("SELECT version()")
```

### Deployment Issues

#### Render Deployment Problems
- Check build logs in Render dashboard
- Verify environment variables
- Check database migration status
- Review application startup logs

#### Asset Compilation Issues
```bash
# Manually precompile assets
RAILS_ENV=production rails assets:precompile

# Clear assets cache
rails tmp:clear
```

### Monitoring and Logging

#### Application Logs
```bash
# Production logs
tail -f log/production.log

# Error-specific logs
grep "ERROR" log/production.log

# API request logs
grep "API" log/production.log
```

#### Performance Monitoring
- Use built-in Rails performance monitoring
- Monitor database query times
- Track memory usage
- Monitor response times

---

## Future Enhancements

### Planned Features

#### 1. AI-Powered Features
- **Smart Lead Scoring**: Machine learning-based lead prioritization
- **Predictive Analytics**: Customer churn prediction and renewal likelihood
- **Automated Document Processing**: OCR and AI-powered document parsing
- **Chatbot Integration**: AI customer support assistance

#### 2. Advanced Analytics
- **Real-time Dashboards**: Live business intelligence
- **Predictive Reporting**: Forecasting and trend analysis
- **Custom KPI Builder**: User-defined key performance indicators
- **Benchmarking**: Industry comparison analytics

#### 3. Mobile Application
- **Native Mobile Apps**: iOS and Android applications
- **Offline Capability**: Work without internet connectivity
- **Push Notifications**: Real-time alerts and reminders
- **Biometric Authentication**: Fingerprint and face recognition

#### 4. Integration Enhancements
- **Payment Gateway Integration**: Online payment processing
- **Insurance Company APIs**: Direct policy issuance
- **CRM Integration**: Customer relationship management
- **Accounting Software**: Financial system integration

#### 5. Workflow Automation
- **Automated Renewals**: Smart renewal processing
- **Document Workflow**: Automated document approval
- **Lead Nurturing**: Automated follow-up sequences
- **Commission Automation**: Auto-approval workflows

#### 6. Advanced Security
- **Two-Factor Authentication**: Enhanced login security
- **Audit Trail Enhancement**: Comprehensive activity logging
- **Role-based Permissions**: Granular access control
- **Data Encryption**: Enhanced data protection

### Technical Improvements

#### 1. Performance Enhancements
- **Database Sharding**: Scale database performance
- **CDN Integration**: Faster content delivery
- **Caching Optimization**: Multi-level caching strategy
- **Query Optimization**: Advanced database tuning

#### 2. Scalability Improvements
- **Microservices Architecture**: Service decomposition
- **Container Deployment**: Docker containerization
- **Load Balancing**: Distribute traffic efficiently
- **Auto-scaling**: Dynamic resource allocation

#### 3. Developer Experience
- **API Documentation**: Interactive API documentation
- **Testing Framework**: Comprehensive test coverage
- **CI/CD Pipeline**: Automated deployment pipeline
- **Code Quality Tools**: Enhanced static analysis

### Business Feature Enhancements

#### 1. Customer Experience
- **Self-Service Portal**: Enhanced customer dashboard
- **Mobile-First Design**: Optimized mobile experience
- **Multi-language Support**: Localization features
- **Accessibility Compliance**: WCAG compliance

#### 2. Agent Productivity
- **Task Management**: Built-in task tracking
- **Calendar Integration**: Appointment scheduling
- **Communication Hub**: Unified communication center
- **Performance Analytics**: Agent productivity metrics

#### 3. Business Intelligence
- **Executive Dashboards**: C-level analytics
- **Competitive Analysis**: Market comparison tools
- **ROI Analytics**: Return on investment tracking
- **Customer Lifetime Value**: CLV analysis and optimization

---

## Conclusion

This comprehensive handover document provides complete documentation for the InsureBook Admin System. The system is production-ready and deployed at https://dr-wise-ag.onrender.com/ with full functionality for insurance management, customer relationship management, commission tracking, and business analytics.

### Key System Highlights:
- **Comprehensive Insurance Management**: Support for Health, Life, Motor, and Other insurance types
- **Multi-Role Support**: Admin, Customer, Agent, Distributor, and Investor roles
- **Mobile API**: Complete REST API for mobile applications
- **Document Management**: Cloud-based storage with Cloudflare R2
- **Commission System**: Automated calculation and distribution
- **Reporting Engine**: Dynamic reports with multiple export formats
- **Lead Management**: Complete lead tracking and conversion system
- **Import/Export**: Bulk data processing capabilities

### Technical Excellence:
- **Modern Technology Stack**: Rails 8.0.4 with PostgreSQL
- **Production Deployment**: Hosted on Render with auto-scaling
- **Performance Optimized**: Cached analytics and optimized queries
- **Security Focused**: Authentication, authorization, and data protection
- **API-First Design**: RESTful APIs for integration and mobile apps

### Business Value:
- **Complete Insurance Ecosystem**: End-to-end insurance management
- **Automated Processes**: Reduced manual work through automation
- **Real-time Analytics**: Data-driven decision making
- **Scalable Architecture**: Ready for business growth
- **Multi-channel Support**: Web and mobile interfaces

The system is ready for immediate use and can be extended with the future enhancements outlined in this document. All code, documentation, and deployment configurations are included for seamless handover to the client team.

For any questions or additional support, please refer to the specific sections in this document or contact the development team.

**Project Status**: ✅ Complete and Production Ready
**Deployment URL**: https://dr-wise-ag.onrender.com/
**Documentation Last Updated**: April 2024