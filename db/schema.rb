# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_07_08_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agency_brokers", force: :cascade do |t|
    t.string "broker_name"
    t.string "broker_code"
    t.string "agency_code"
    t.boolean "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "agency_codes", force: :cascade do |t|
    t.string "insurance_type"
    t.string "company_name"
    t.string "agent_name"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "broker_id"
    t.index ["broker_id"], name: "index_agency_codes_on_broker_id"
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "ai_report_histories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "report_type", null: false
    t.json "filters"
    t.json "ai_insights"
    t.integer "confidence_score"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confidence_score"], name: "index_ai_report_histories_on_confidence_score"
    t.index ["generated_at"], name: "index_ai_report_histories_on_generated_at"
    t.index ["report_type"], name: "index_ai_report_histories_on_report_type"
    t.index ["user_id", "report_type"], name: "index_ai_report_histories_on_user_id_and_report_type"
    t.index ["user_id"], name: "index_ai_report_histories_on_user_id"
  end

  create_table "all_policy_reports", force: :cascade do |t|
    t.string "name"
    t.string "policy_type"
    t.json "report_data"
    t.integer "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "analytics_caches", force: :cascade do |t|
    t.string "cache_identifier"
    t.text "cache_data"
    t.datetime "last_updated"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cache_identifier"], name: "index_analytics_caches_on_cache_identifier", unique: true
  end

  create_table "announcements", force: :cascade do |t|
    t.string "title", null: false
    t.text "body", null: false
    t.integer "audience", default: 0, null: false
    t.bigint "forum_id"
    t.bigint "chapter_id"
    t.bigint "target_user_id"
    t.bigint "created_by_id", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audience"], name: "index_announcements_on_audience"
    t.index ["chapter_id"], name: "index_announcements_on_chapter_id"
    t.index ["created_by_id"], name: "index_announcements_on_created_by_id"
    t.index ["forum_id"], name: "index_announcements_on_forum_id"
    t.index ["target_user_id"], name: "index_announcements_on_target_user_id"
  end

  create_table "appointments", force: :cascade do |t|
    t.bigint "customer_id"
    t.string "customer_name", null: false
    t.string "customer_email"
    t.string "customer_phone"
    t.text "meeting_agenda"
    t.text "notes"
    t.date "appointment_date", null: false
    t.string "time_slot", null: false
    t.string "status", default: "pending", null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_date"], name: "index_appointments_on_appointment_date"
    t.index ["created_by_id"], name: "index_appointments_on_created_by_id"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["status"], name: "index_appointments_on_status"
  end

  create_table "banners", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.string "redirect_link"
    t.date "display_start_date"
    t.date "display_end_date"
    t.string "display_location"
    t.boolean "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "display_order", default: 0
    t.string "r2_file_key"
    t.string "r2_filename"
    t.string "r2_content_type"
    t.bigint "r2_file_size"
    t.text "r2_public_url"
    t.index ["display_order"], name: "index_banners_on_display_order"
  end

  create_table "broker_codes", force: :cascade do |t|
    t.bigint "broker_id", null: false
    t.string "broker_code"
    t.string "company_name"
    t.boolean "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "agent_name"
    t.index ["broker_id"], name: "index_broker_codes_on_broker_id"
  end

  create_table "brokers", force: :cascade do |t|
    t.string "name", null: false
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "insurance_company_id"
    t.index ["insurance_company_id"], name: "index_brokers_on_insurance_company_id"
    t.index ["name"], name: "index_brokers_on_name"
    t.index ["status"], name: "index_brokers_on_status"
  end

  create_table "business_plans", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "chapter_limit"
    t.integer "member_limit"
    t.text "description"
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_business_plans_on_key", unique: true
  end

  create_table "chapters", force: :cascade do |t|
    t.bigint "forum_id", null: false
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["forum_id", "name"], name: "index_chapters_on_forum_id_and_name", unique: true
    t.index ["forum_id"], name: "index_chapters_on_forum_id"
  end

  create_table "client_requests", force: :cascade do |t|
    t.string "ticket_number", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone_number", null: false
    t.text "description", null: false
    t.string "status", default: "pending"
    t.string "priority", default: "medium"
    t.string "subject"
    t.string "request_type"
    t.datetime "submitted_at", null: false
    t.text "admin_response"
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.string "submitter_type"
    t.integer "submitter_id"
    t.index ["email"], name: "index_client_requests_on_email"
    t.index ["resolved_by_id"], name: "index_client_requests_on_resolved_by_id"
    t.index ["status"], name: "index_client_requests_on_status"
    t.index ["submitted_at"], name: "index_client_requests_on_submitted_at"
    t.index ["submitter_type", "submitter_id"], name: "index_client_requests_on_submitter_type_and_submitter_id"
    t.index ["ticket_number"], name: "index_client_requests_on_ticket_number", unique: true
  end

  create_table "client_services", force: :cascade do |t|
    t.string "service_type", null: false
    t.string "service_category", null: false
    t.bigint "customer_id", null: false
    t.bigint "sub_agent_id"
    t.bigint "distributor_id"
    t.decimal "amount", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "pending"
    t.string "reference_number"
    t.date "start_date"
    t.text "notes"
    t.decimal "main_agent_commission_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "commission_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "tds_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "tds_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "after_tds_value", precision: 15, scale: 2, default: "0.0"
    t.decimal "sub_agent_commission_percentage", precision: 8, scale: 2, default: "2.0"
    t.decimal "sub_agent_commission_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "sub_agent_tds_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "sub_agent_tds_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "sub_agent_after_tds_value", precision: 15, scale: 2, default: "0.0"
    t.decimal "distributor_commission_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "distributor_commission_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "distributor_tds_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "distributor_tds_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "distributor_after_tds_value", precision: 15, scale: 2, default: "0.0"
    t.decimal "investor_commission_percentage", precision: 8, scale: 2, default: "2.0"
    t.decimal "investor_commission_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "company_expenses_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "company_expenses_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "total_distribution_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "profit_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "profit_amount", precision: 15, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_admin_added", default: false, null: false
    t.boolean "is_customer_added", default: true, null: false
    t.boolean "is_agent_added", default: false, null: false
    t.index ["customer_id"], name: "index_client_services_on_customer_id"
    t.index ["service_category"], name: "index_client_services_on_service_category"
    t.index ["service_type"], name: "index_client_services_on_service_type"
    t.index ["sub_agent_id"], name: "index_client_services_on_sub_agent_id"
  end

  create_table "commission_payouts", force: :cascade do |t|
    t.string "policy_type"
    t.integer "policy_id"
    t.string "payout_to"
    t.decimal "payout_amount"
    t.date "payout_date"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "transaction_id"
    t.string "payment_mode"
    t.string "reference_number"
    t.decimal "commission_amount_received", precision: 10, scale: 2
    t.decimal "distribution_percentage", precision: 5, scale: 2
    t.text "notes"
    t.string "processed_by"
    t.datetime "processed_at"
    t.bigint "payout_id"
    t.string "lead_id"
    t.boolean "invoiced", default: false
    t.decimal "total_commission_amount", precision: 10, scale: 2
    t.decimal "tds_amount", precision: 10, scale: 2
    t.index ["created_at"], name: "index_commission_payouts_on_created_at"
    t.index ["lead_id"], name: "index_commission_payouts_on_lead_id"
    t.index ["payout_date"], name: "index_commission_payouts_on_payout_date"
    t.index ["payout_id"], name: "index_commission_payouts_on_payout_id"
    t.index ["payout_to", "status"], name: "idx_commission_payouts_payout_to_status"
    t.index ["policy_type", "policy_id", "status"], name: "idx_commission_payouts_policy_status"
    t.index ["policy_type", "policy_id"], name: "idx_commission_payouts_policy"
    t.index ["status", "created_at"], name: "index_commission_payouts_on_status_and_created_at"
    t.index ["status"], name: "idx_commission_payouts_status"
  end

  create_table "commission_receipts", force: :cascade do |t|
    t.string "policy_type", null: false
    t.integer "policy_id", null: false
    t.decimal "total_commission_received", precision: 12, scale: 2, null: false
    t.date "received_date", null: false
    t.string "insurance_company_name"
    t.string "insurance_company_reference"
    t.decimal "company_commission_percentage", precision: 5, scale: 2
    t.string "payment_mode"
    t.string "transaction_id"
    t.text "notes"
    t.string "received_by"
    t.boolean "auto_distributed", default: false
    t.datetime "distributed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auto_distributed"], name: "index_commission_receipts_on_auto_distributed"
    t.index ["policy_type", "policy_id"], name: "index_commission_receipts_on_policy_type_and_policy_id", unique: true
    t.index ["received_date"], name: "index_commission_receipts_on_received_date"
  end

  create_table "corporate_members", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "company_name"
    t.string "mobile"
    t.string "email"
    t.string "state"
    t.string "city"
    t.text "address"
    t.decimal "annual_income"
    t.string "pan_no"
    t.string "gst_no"
    t.text "additional_information"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_corporate_members_on_customer_id"
  end

  create_table "customer_documents", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "document_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_documents_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "customer_type"
    t.string "first_name"
    t.string "last_name"
    t.string "company_name"
    t.string "email"
    t.string "mobile"
    t.string "address"
    t.string "state"
    t.string "city"
    t.date "birth_date"
    t.integer "age"
    t.string "gender"
    t.string "height"
    t.string "weight"
    t.string "education"
    t.string "marital_status"
    t.string "occupation"
    t.string "job_name"
    t.string "type_of_duty"
    t.decimal "annual_income"
    t.string "pan_number"
    t.string "gst_number"
    t.string "birth_place"
    t.text "additional_info"
    t.boolean "status"
    t.string "added_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "nominee_name"
    t.string "nominee_relation"
    t.date "nominee_date_of_birth"
    t.string "pincode"
    t.string "sub_agent", default: "Self"
    t.string "middle_name"
    t.string "height_feet"
    t.decimal "weight_kg", precision: 5, scale: 2
    t.string "business_job"
    t.string "business_name"
    t.text "additional_information"
    t.string "pan_no"
    t.string "gst_no"
    t.integer "policies_count", default: 0, null: false
    t.integer "sub_agent_id"
    t.string "lead_id"
    t.boolean "deactivated", default: false
    t.string "bank_name"
    t.string "account_no"
    t.string "ifsc_code"
    t.date "anniversary_date"
    t.index ["created_at"], name: "index_customers_on_created_at"
    t.index ["customer_type", "created_at"], name: "index_customers_on_customer_type_and_created_at"
    t.index ["customer_type", "status"], name: "index_customers_on_customer_type_and_status"
    t.index ["customer_type"], name: "index_customers_on_customer_type"
    t.index ["email"], name: "index_customers_on_email"
    t.index ["lead_id"], name: "index_customers_on_lead_id", unique: true
    t.index ["mobile"], name: "index_customers_on_mobile"
    t.index ["pan_number"], name: "index_customers_on_pan_number"
    t.index ["status", "created_at"], name: "index_customers_on_status_and_created_at"
    t.index ["status"], name: "index_customers_on_status"
    t.index ["sub_agent_id"], name: "index_customers_on_sub_agent_id"
  end

  create_table "distributor_assignments", force: :cascade do |t|
    t.bigint "distributor_id", null: false
    t.bigint "sub_agent_id", null: false
    t.datetime "assigned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["distributor_id"], name: "index_distributor_assignments_on_distributor_id"
    t.index ["sub_agent_id"], name: "index_distributor_assignments_on_sub_agent_id"
  end

  create_table "distributor_documents", force: :cascade do |t|
    t.bigint "distributor_id", null: false
    t.string "document_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["distributor_id"], name: "index_distributor_documents_on_distributor_id"
  end

  create_table "distributor_payouts", force: :cascade do |t|
    t.bigint "distributor_id", null: false
    t.string "policy_type"
    t.integer "policy_id"
    t.decimal "payout_amount", precision: 10, scale: 2
    t.date "payout_date"
    t.string "status", default: "pending"
    t.string "transaction_id"
    t.string "payment_mode"
    t.string "reference_number"
    t.text "notes"
    t.string "processed_by"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "invoiced", default: false
    t.index ["created_at"], name: "index_distributor_payouts_on_created_at"
    t.index ["distributor_id", "status"], name: "index_distributor_payouts_on_distributor_id_and_status"
    t.index ["distributor_id"], name: "index_distributor_payouts_on_distributor_id"
    t.index ["policy_type", "policy_id"], name: "index_distributor_payouts_on_policy_type_and_policy_id"
    t.index ["status", "created_at"], name: "index_distributor_payouts_on_status_and_created_at"
    t.index ["status"], name: "index_distributor_payouts_on_status"
  end

  create_table "distributors", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "middle_name"
    t.string "last_name", null: false
    t.string "mobile", null: false
    t.string "email", null: false
    t.integer "role_id", null: false
    t.integer "state_id"
    t.integer "city_id"
    t.date "birth_date"
    t.string "gender"
    t.string "pan_no"
    t.string "gst_no"
    t.string "company_name"
    t.text "address"
    t.string "bank_name"
    t.string "account_no"
    t.string "ifsc_code"
    t.string "account_holder_name"
    t.string "account_type"
    t.string "upi_id"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "affiliate_count", default: 0, null: false
    t.boolean "deactivated", default: false
    t.string "city"
    t.string "state"
    t.string "username"
    t.string "password_digest"
    t.string "original_password"
    t.integer "investor_id"
    t.index ["created_at"], name: "index_distributors_on_created_at"
    t.index ["email"], name: "index_distributors_on_email", unique: true
    t.index ["investor_id"], name: "index_distributors_on_investor_id"
    t.index ["mobile"], name: "index_distributors_on_mobile", unique: true
    t.index ["role_id"], name: "index_distributors_on_role_id"
    t.index ["status"], name: "index_distributors_on_status"
  end

  create_table "documents", force: :cascade do |t|
    t.string "document_type"
    t.string "documentable_type", null: false
    t.bigint "documentable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.string "uploaded_by"
    t.index ["documentable_type", "documentable_id"], name: "index_documents_on_documentable"
  end

  create_table "event_registrations", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.boolean "attended", default: false, null: false
    t.datetime "attended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "rsvp_status", default: 0, null: false
    t.index ["event_id", "user_id"], name: "index_event_registrations_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_registrations_on_event_id"
    t.index ["rsvp_status"], name: "index_event_registrations_on_rsvp_status"
    t.index ["user_id"], name: "index_event_registrations_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "forum_id", null: false
    t.bigint "chapter_id"
    t.string "title", null: false
    t.text "description"
    t.integer "event_type", default: 0, null: false
    t.datetime "starts_at", null: false
    t.string "venue"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chapter_id"], name: "index_events_on_chapter_id"
    t.index ["forum_id"], name: "index_events_on_forum_id"
  end

  create_table "family_members", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "first_name"
    t.date "birth_date"
    t.integer "age"
    t.string "height"
    t.string "weight"
    t.string "gender"
    t.string "relationship"
    t.string "pan_no"
    t.string "mobile"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "middle_name"
    t.string "last_name"
    t.string "height_feet"
    t.decimal "weight_kg", precision: 5, scale: 2
    t.text "additional_information"
    t.index ["customer_id"], name: "index_family_members_on_customer_id"
  end

  create_table "forum_requests", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "company_name", null: false
    t.text "message"
    t.integer "status", default: 0, null: false
    t.text "review_note"
    t.bigint "business_plan_id"
    t.bigint "forum_id"
    t.bigint "reviewed_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_plan_id"], name: "index_forum_requests_on_business_plan_id"
    t.index ["forum_id"], name: "index_forum_requests_on_forum_id"
    t.index ["reviewed_by_id"], name: "index_forum_requests_on_reviewed_by_id"
  end

  create_table "forums", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.bigint "business_plan_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "suspended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_plan_id"], name: "index_forums_on_business_plan_id"
    t.index ["slug"], name: "index_forums_on_slug", unique: true
  end

  create_table "health_insurance_documents", force: :cascade do |t|
    t.bigint "health_insurance_id", null: false
    t.string "document_type"
    t.string "title"
    t.text "description"
    t.string "r2_file_key"
    t.string "r2_filename"
    t.string "r2_content_type"
    t.bigint "r2_file_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_insurance_id"], name: "index_health_insurance_documents_on_health_insurance_id"
  end

  create_table "health_insurance_members", force: :cascade do |t|
    t.bigint "health_insurance_id", null: false
    t.string "member_name"
    t.integer "age"
    t.string "relationship"
    t.decimal "sum_insured"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_insurance_id"], name: "index_health_insurance_members_on_health_insurance_id"
  end

  create_table "health_insurance_nominees", force: :cascade do |t|
    t.bigint "health_insurance_id", null: false
    t.string "nominee_name"
    t.string "relationship"
    t.integer "age"
    t.decimal "share_percentage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_insurance_id"], name: "index_health_insurance_nominees_on_health_insurance_id"
  end

  create_table "health_insurances", force: :cascade do |t|
    t.bigint "policy_id"
    t.string "insurance_type"
    t.string "claim_process"
    t.decimal "main_agent_commission_percent"
    t.decimal "main_agent_commission_amount"
    t.decimal "main_agent_tds_percent"
    t.decimal "main_agent_tds_amount"
    t.string "reference_by_name"
    t.string "broker_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "customer_id"
    t.bigint "sub_agent_id"
    t.bigint "agency_code_id"
    t.bigint "broker_id"
    t.string "policy_holder"
    t.string "insurance_company_name"
    t.string "plan_name"
    t.string "policy_number"
    t.date "policy_booking_date"
    t.date "policy_start_date"
    t.date "policy_end_date"
    t.integer "policy_term"
    t.string "payment_mode"
    t.decimal "sum_insured"
    t.decimal "net_premium"
    t.decimal "gst_percentage"
    t.decimal "total_premium"
    t.decimal "main_agent_commission_percentage"
    t.decimal "commission_amount"
    t.decimal "tds_percentage"
    t.decimal "tds_amount"
    t.decimal "after_tds_value"
    t.string "policy_type"
    t.date "installment_autopay_start_date"
    t.date "installment_autopay_end_date"
    t.text "notification_dates"
    t.boolean "is_customer_added", default: false
    t.boolean "is_agent_added", default: false
    t.boolean "is_admin_added", default: false
    t.boolean "product_through_dr", default: true
    t.boolean "main_agent_commission_received", default: false
    t.string "main_agent_commission_transaction_id"
    t.date "main_agent_commission_paid_date"
    t.text "main_agent_commission_notes"
    t.string "lead_id"
    t.bigint "distributor_id"
    t.bigint "investor_id"
    t.decimal "ambassador_commission_percentage"
    t.decimal "ambassador_commission_amount"
    t.decimal "ambassador_tds_percentage"
    t.decimal "ambassador_tds_amount"
    t.decimal "ambassador_after_tds_value"
    t.decimal "sub_agent_commission_percentage"
    t.decimal "sub_agent_commission_amount"
    t.decimal "sub_agent_tds_percentage"
    t.decimal "sub_agent_tds_amount"
    t.decimal "sub_agent_after_tds_value"
    t.decimal "investor_commission_percentage"
    t.decimal "investor_commission_amount"
    t.decimal "investor_tds_percentage"
    t.decimal "investor_tds_amount"
    t.decimal "investor_after_tds_value"
    t.decimal "company_expenses_percentage"
    t.decimal "total_distribution_percentage"
    t.decimal "profit_percentage"
    t.decimal "profit_amount"
    t.boolean "policy_added_by_admin", default: false
    t.date "nominee_dob"
    t.string "broker_code_type"
    t.string "premium_frequency", limit: 50
    t.string "status", limit: 50
    t.date "start_date"
    t.date "end_date"
    t.text "additional_details"
    t.string "nominee_name", limit: 255
    t.string "nominee_relation", limit: 100
    t.string "sum_insured_text", limit: 255
    t.bigint "original_policy_id"
    t.boolean "is_renewed", default: false
    t.string "insurance_company_code"
    t.index ["agency_code_id"], name: "index_health_insurances_on_agency_code_id"
    t.index ["broker_id"], name: "index_health_insurances_on_broker_id"
    t.index ["created_at"], name: "idx_health_insurances_created_at"
    t.index ["customer_id", "created_at"], name: "index_health_insurances_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_health_insurances_on_customer_id"
    t.index ["distributor_id"], name: "index_health_insurances_on_distributor_id"
    t.index ["insurance_company_code"], name: "index_health_insurances_on_insurance_company_code"
    t.index ["investor_id"], name: "index_health_insurances_on_investor_id"
    t.index ["is_admin_added", "is_customer_added", "is_agent_added"], name: "idx_health_insurances_drwise"
    t.index ["lead_id"], name: "index_health_insurances_on_lead_id", unique: true
    t.index ["policy_end_date", "created_at"], name: "index_health_insurances_on_policy_end_date_and_created_at"
    t.index ["policy_end_date"], name: "index_health_insurances_on_policy_end_date"
    t.index ["policy_id"], name: "index_health_insurances_on_policy_id"
    t.index ["policy_type"], name: "index_health_insurances_on_policy_type"
    t.index ["status"], name: "index_health_insurances_on_status"
    t.index ["sub_agent_id"], name: "index_health_insurances_on_sub_agent_id"
  end

  create_table "helpdesk_tickets", force: :cascade do |t|
    t.string "ticket_number"
    t.string "subject"
    t.text "description"
    t.string "status"
    t.string "priority"
    t.string "category"
    t.string "submitter_type"
    t.integer "submitter_id"
    t.integer "assigned_to"
    t.text "resolution_notes"
    t.datetime "resolved_at"
    t.bigint "sub_agent_id", null: false
    t.bigint "customer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_helpdesk_tickets_on_customer_id"
    t.index ["sub_agent_id"], name: "index_helpdesk_tickets_on_sub_agent_id"
    t.index ["ticket_number"], name: "index_helpdesk_tickets_on_ticket_number", unique: true
  end

  create_table "indian_locations", force: :cascade do |t|
    t.string "state", null: false
    t.string "city", null: false
    t.string "district"
    t.string "pincode"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_indian_locations_on_is_active"
    t.index ["state", "city"], name: "index_indian_locations_on_state_and_city", unique: true
    t.index ["state"], name: "index_indian_locations_on_state"
  end

  create_table "insurance_companies", force: :cascade do |t|
    t.string "name"
    t.boolean "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
    t.string "contact_person"
    t.string "email"
    t.string "mobile"
    t.text "address"
    t.string "insurance_type"
  end

  create_table "investments", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "investment_type"
    t.string "product_name"
    t.decimal "investment_amount"
    t.boolean "status"
    t.date "investment_date"
    t.date "maturity_date"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_investments_on_customer_id"
  end

  create_table "investor_documents", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "investor_id"
    t.string "document_type"
    t.index ["investor_id"], name: "index_investor_documents_on_investor_id"
  end

  create_table "investors", id: :serial, force: :cascade do |t|
    t.string "first_name", limit: 255
    t.string "middle_name", limit: 255
    t.string "last_name", limit: 255
    t.string "mobile", limit: 255
    t.string "email", limit: 255
    t.integer "role_id"
    t.string "state"
    t.string "city"
    t.date "birth_date"
    t.string "gender", limit: 255
    t.string "pan_no", limit: 255
    t.string "gst_no", limit: 255
    t.string "company_name", limit: 255
    t.text "address"
    t.string "bank_name", limit: 255
    t.string "account_no", limit: 255
    t.string "ifsc_code", limit: 255
    t.string "account_holder_name", limit: 255
    t.string "account_type", limit: 255
    t.string "upi_id", limit: 255
    t.integer "status"
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "password_digest"
    t.string "username"
    t.string "original_password"
    t.decimal "invested_amount"
    t.decimal "investment_percentage"
    t.integer "number_of_shares"
    t.string "main_document_key"
    t.string "main_document_filename"
    t.string "main_document_content_type"
    t.bigint "main_document_size"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.string "payout_type"
    t.integer "payout_id"
    t.string "description"
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
  end

  create_table "invoices", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "invoice_number"
    t.string "payout_type"
    t.integer "payout_id"
    t.decimal "total_amount", precision: 10, scale: 2
    t.string "status", default: "pending"
    t.date "invoice_date"
    t.date "due_date"
    t.datetime "paid_at"
    t.string "recipient_name"
    t.string "recipient_email"
    t.text "recipient_address"
    t.text "notes"
    t.index ["invoice_date"], name: "index_invoices_on_invoice_date"
    t.index ["invoice_number"], name: "index_invoices_on_invoice_number", unique: true
    t.index ["payout_type", "payout_id"], name: "index_invoices_on_payout_type_and_payout_id"
    t.index ["status"], name: "index_invoices_on_status"
  end

  create_table "leads", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "contact_number"
    t.string "email"
    t.string "referred_by"
    t.string "product_interest"
    t.string "current_stage", default: "lead_generated"
    t.date "created_date"
    t.text "note"
    t.string "lead_id"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "lead_source"
    t.string "call_disposition"
    t.decimal "referral_amount"
    t.boolean "transferred_amount", default: false
    t.text "notes"
    t.text "attachments"
    t.datetime "stage_updated_at", precision: nil
    t.integer "converted_customer_id"
    t.integer "policy_created_id"
    t.string "product_category"
    t.string "product_subcategory"
    t.boolean "is_direct", default: true
    t.integer "affiliate_id"
    t.string "customer_type", default: "individual"
    t.string "first_name"
    t.string "middle_name"
    t.string "last_name"
    t.date "birth_date"
    t.string "gender"
    t.string "pan_no"
    t.string "gst_no"
    t.string "company_name"
    t.string "marital_status"
    t.decimal "height"
    t.decimal "weight"
    t.string "birth_place"
    t.string "education"
    t.string "business_job"
    t.string "business_name"
    t.string "job_name"
    t.string "occupation"
    t.string "type_of_duty"
    t.decimal "annual_income"
    t.text "additional_information"
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.integer "parent_lead_id"
    t.boolean "is_branch_out", default: false
    t.integer "ambassador_id"
    t.index ["affiliate_id"], name: "index_leads_on_affiliate_id"
    t.index ["ambassador_id"], name: "index_leads_on_ambassador_id"
    t.index ["company_name"], name: "index_leads_on_company_name"
    t.index ["contact_number"], name: "index_leads_on_contact_number"
    t.index ["converted_customer_id"], name: "index_leads_on_converted_customer_id"
    t.index ["created_at"], name: "index_leads_on_created_at"
    t.index ["current_stage", "created_at"], name: "index_leads_on_current_stage_and_created_at"
    t.index ["current_stage"], name: "index_leads_on_current_stage"
    t.index ["email"], name: "index_leads_on_email"
    t.index ["first_name", "last_name"], name: "index_leads_on_first_name_and_last_name"
    t.index ["is_direct"], name: "index_leads_on_is_direct"
    t.index ["lead_id"], name: "index_leads_on_lead_id"
    t.index ["lead_source"], name: "index_leads_on_lead_source"
    t.index ["parent_lead_id"], name: "index_leads_on_parent_lead_id"
    t.index ["policy_created_id"], name: "index_leads_on_policy_created_id"
    t.index ["product_category", "product_subcategory"], name: "index_leads_on_product_category_and_product_subcategory"
    t.index ["product_category"], name: "index_leads_on_product_category"
    t.index ["product_subcategory"], name: "index_leads_on_product_subcategory"
  end

  create_table "life_insurance_bank_details", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "life_insurance_id"
    t.string "bank_name"
    t.string "account_type"
    t.string "account_number"
    t.string "ifsc_code"
    t.string "account_holder_name"
    t.index ["life_insurance_id"], name: "index_life_insurance_bank_details_on_life_insurance_id"
  end

  create_table "life_insurance_documents", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "life_insurance_id"
    t.string "document_type"
    t.string "document_name"
    t.index ["life_insurance_id"], name: "index_life_insurance_documents_on_life_insurance_id"
  end

  create_table "life_insurance_nominees", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "life_insurance_id", null: false
    t.string "nominee_name", null: false
    t.string "relationship", null: false
    t.integer "age"
    t.decimal "share_percentage", precision: 5, scale: 2
    t.index ["life_insurance_id"], name: "index_life_insurance_nominees_on_life_insurance_id"
  end

  create_table "life_insurances", id: :serial, force: :cascade do |t|
    t.integer "customer_id", null: false
    t.integer "sub_agent_id"
    t.string "policy_holder", limit: 255, null: false
    t.string "insured_name", limit: 255
    t.string "insurance_company_name", limit: 255, null: false
    t.integer "agency_code_id"
    t.integer "broker_id"
    t.string "policy_type", limit: 255, null: false
    t.string "payment_mode", limit: 255, null: false
    t.string "policy_number", limit: 255, null: false
    t.date "policy_booking_date"
    t.date "policy_start_date", null: false
    t.date "policy_end_date", null: false
    t.integer "policy_term", null: false
    t.integer "premium_payment_term", null: false
    t.string "plan_name", limit: 255
    t.decimal "sum_insured", precision: 15, scale: 2, null: false
    t.decimal "net_premium", precision: 15, scale: 2, null: false
    t.decimal "total_premium", precision: 15, scale: 2, null: false
    t.string "nominee_name", limit: 255
    t.string "nominee_relationship", limit: 255
    t.integer "nominee_age"
    t.boolean "active", default: true
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "broker_code_type"
    t.decimal "ambassador_commission_percentage"
    t.decimal "ambassador_commission_amount"
    t.decimal "ambassador_tds_percentage"
    t.decimal "ambassador_tds_amount"
    t.decimal "ambassador_after_tds_value"
    t.decimal "company_expenses_percentage"
    t.decimal "company_expenses_amount"
    t.decimal "total_distribution_percentage"
    t.decimal "profit_percentage"
    t.decimal "profit_amount"
    t.date "risk_start_date"
    t.string "sum_insured_text"
    t.string "reference_by_name"
    t.string "broker_name"
    t.text "extra_note"
    t.boolean "is_customer_added", default: false
    t.boolean "is_agent_added", default: false
    t.boolean "is_admin_added", default: false
    t.boolean "policy_added_by_admin", default: false
    t.decimal "first_year_gst_percentage"
    t.decimal "second_year_gst_percentage"
    t.decimal "third_year_gst_percentage"
    t.string "bank_name"
    t.string "account_type"
    t.string "account_number"
    t.string "ifsc_code"
    t.string "account_holder_name"
    t.decimal "bonus"
    t.decimal "fund"
    t.decimal "main_agent_commission_percentage"
    t.decimal "commission_amount"
    t.decimal "tds_percentage"
    t.decimal "tds_amount"
    t.decimal "after_tds_value"
    t.decimal "sub_agent_commission_percentage"
    t.decimal "sub_agent_commission_amount"
    t.decimal "sub_agent_tds_percentage"
    t.decimal "sub_agent_tds_amount"
    t.decimal "sub_agent_after_tds_value"
    t.decimal "investor_commission_percentage"
    t.decimal "investor_commission_amount"
    t.decimal "investor_tds_percentage"
    t.decimal "investor_tds_amount"
    t.decimal "investor_after_tds_value"
    t.date "installment_autopay_start_date"
    t.date "installment_autopay_end_date"
    t.bigint "distributor_id"
    t.decimal "main_income_percentage"
    t.decimal "main_income_amount"
    t.decimal "distributor_commission_percentage"
    t.decimal "distributor_commission_amount"
    t.decimal "distributor_tds_percentage"
    t.decimal "distributor_tds_amount"
    t.decimal "distributor_after_tds_value"
    t.string "lead_id"
    t.text "notification_dates"
    t.boolean "is_renewed", default: false, null: false
    t.integer "original_policy_id"
    t.integer "renewal_policy_id"
    t.boolean "main_agent_commission_received", default: false
    t.string "main_agent_commission_transaction_id"
    t.date "main_agent_commission_paid_date"
    t.text "main_agent_commission_notes"
    t.boolean "product_through_dr", default: true
    t.string "insurance_company_code"
    t.string "main_policy_document_key"
    t.string "main_policy_document_filename"
    t.string "main_policy_document_content_type"
    t.bigint "main_policy_document_size"
    t.index ["created_at"], name: "index_life_insurances_on_created_at"
    t.index ["customer_id", "created_at"], name: "index_life_insurances_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_life_insurances_on_customer_id"
    t.index ["distributor_id"], name: "index_life_insurances_on_distributor_id"
    t.index ["insurance_company_code"], name: "index_life_insurances_on_insurance_company_code"
    t.index ["is_admin_added", "is_customer_added", "is_agent_added"], name: "idx_life_insurances_drwise"
    t.index ["policy_end_date", "created_at"], name: "index_life_insurances_on_policy_end_date_and_created_at"
    t.index ["policy_end_date"], name: "index_life_insurances_on_policy_end_date"
    t.index ["policy_type"], name: "index_life_insurances_on_policy_type"
    t.index ["sub_agent_id"], name: "index_life_insurances_on_sub_agent_id"
    t.unique_constraint ["policy_number"], name: "life_insurances_policy_number_key"
  end

  create_table "loans", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "customer_id", null: false
    t.string "loan_type"
    t.decimal "loan_amount", precision: 10, scale: 2
    t.decimal "interest_rate", precision: 10, scale: 2
    t.integer "loan_term"
    t.decimal "emi_amount", precision: 10, scale: 2
    t.date "loan_date"
    t.boolean "status"
    t.text "notes"
    t.index ["customer_id"], name: "index_loans_on_customer_id"
  end

  create_table "motor_insurance_documents", force: :cascade do |t|
    t.bigint "motor_insurance_id", null: false
    t.string "document_type"
    t.string "title"
    t.text "description"
    t.string "r2_file_key"
    t.string "r2_filename"
    t.string "r2_content_type"
    t.bigint "r2_file_size"
    t.string "r2_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["motor_insurance_id"], name: "index_motor_insurance_documents_on_motor_insurance_id"
  end

  create_table "motor_insurance_nominees", force: :cascade do |t|
    t.bigint "motor_insurance_id", null: false
    t.string "nominee_name"
    t.string "relationship"
    t.integer "age"
    t.decimal "share_percentage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["motor_insurance_id"], name: "index_motor_insurance_nominees_on_motor_insurance_id"
  end

  create_table "motor_insurances", id: :serial, force: :cascade do |t|
    t.integer "customer_id", null: false
    t.integer "sub_agent_id"
    t.string "policy_holder", limit: 255
    t.string "insurance_company_name", limit: 255
    t.string "policy_number", limit: 255
    t.date "policy_booking_date"
    t.date "policy_start_date"
    t.date "policy_end_date"
    t.string "payment_mode", limit: 255
    t.string "plan_name", limit: 255
    t.string "vehicle_type", limit: 255
    t.string "vehicle_make", limit: 255
    t.string "vehicle_model", limit: 255
    t.string "vehicle_number", limit: 255
    t.decimal "sum_insured", precision: 15, scale: 2
    t.decimal "net_premium", precision: 15, scale: 2
    t.decimal "total_premium", precision: 15, scale: 2
    t.string "status", limit: 255
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "policy_type", limit: 255
    t.bigint "broker_id"
    t.boolean "main_agent_commission_received"
    t.string "main_agent_commission_transaction_id"
    t.date "main_agent_commission_paid_date"
    t.text "main_agent_commission_notes"
    t.string "broker_code_type"
    t.decimal "gst_percentage", precision: 8, scale: 2, default: "18.0"
    t.boolean "is_admin_added", default: false
    t.boolean "policy_added_by_admin", default: false
    t.boolean "is_customer_added", default: false
    t.boolean "is_agent_added", default: false
    t.decimal "gst_amount", precision: 10, scale: 2
    t.decimal "after_tds_value", precision: 10, scale: 2
    t.string "reference_by_name"
    t.text "extra_note"
    t.string "insurance_type"
    t.string "class_of_vehicle"
    t.string "lead_id"
    t.string "registration_number", limit: 255
    t.decimal "vehicle_idv", precision: 10, scale: 2
    t.decimal "cng_idv", precision: 10, scale: 2
    t.decimal "total_idv", precision: 10, scale: 2
    t.string "make", limit: 255
    t.string "model", limit: 255
    t.decimal "tp_premium", precision: 10, scale: 2
    t.decimal "main_agent_commission_percentage", precision: 5, scale: 2
    t.decimal "main_agent_commission_amount", precision: 10, scale: 2
    t.decimal "main_agent_tds_percentage", precision: 5, scale: 2
    t.decimal "main_agent_tds_amount", precision: 10, scale: 2
    t.decimal "commission_amount", precision: 10, scale: 2
    t.decimal "tds_percentage", precision: 5, scale: 2
    t.decimal "tds_amount", precision: 10, scale: 2
    t.integer "agency_code_id"
    t.string "engine_number"
    t.string "chassis_number"
    t.string "variant"
    t.string "mfy"
    t.integer "seating_capacity"
    t.decimal "ncb"
    t.decimal "discount_loading_percent"
    t.decimal "payout_od"
    t.decimal "payout_tp"
    t.decimal "payout_net"
    t.decimal "sub_agent_commission_percentage"
    t.decimal "sub_agent_commission_amount"
    t.decimal "sub_agent_tds_percentage"
    t.decimal "sub_agent_tds_amount"
    t.decimal "sub_agent_after_tds_value"
    t.integer "distributor_id"
    t.decimal "distributor_commission_percentage"
    t.decimal "distributor_commission_amount"
    t.decimal "distributor_tds_percentage"
    t.decimal "distributor_tds_amount"
    t.decimal "distributor_after_tds_value"
    t.integer "investor_id"
    t.decimal "investor_commission_percentage"
    t.decimal "investor_commission_amount"
    t.decimal "investor_tds_percentage"
    t.decimal "investor_tds_amount"
    t.decimal "investor_after_tds_value"
    t.decimal "ambassador_commission_percentage"
    t.decimal "ambassador_commission_amount"
    t.decimal "ambassador_tds_percentage"
    t.decimal "ambassador_tds_amount"
    t.decimal "ambassador_after_tds_value"
    t.decimal "total_distribution_percentage"
    t.decimal "company_expenses_percentage"
    t.decimal "profit_percentage"
    t.decimal "profit_amount"
    t.boolean "legal_liability"
    t.boolean "electrical_accessories"
    t.boolean "non_electrical_accessories"
    t.boolean "zero_depreciation"
    t.boolean "roadside_assistance"
    t.boolean "engine_protector"
    t.boolean "key_replacement"
    t.boolean "return_to_invoice"
    t.boolean "consumable_cover"
    t.boolean "personal_accident_cover"
    t.string "financier"
    t.text "notification_dates"
    t.date "installment_autopay_start_date"
    t.date "installment_autopay_end_date"
    t.string "nominee_name"
    t.string "nominee_relation"
    t.date "nominee_dob"
    t.string "insurance_company_code"
    t.string "main_policy_document_url"
    t.string "main_policy_document_key"
    t.string "main_policy_document_filename"
    t.string "main_policy_document_content_type"
    t.bigint "main_policy_document_size"
    t.boolean "product_through_dr", default: true
    t.index ["agency_code_id"], name: "index_motor_insurances_on_agency_code_id"
    t.index ["broker_id"], name: "index_motor_insurances_on_broker_id"
    t.index ["created_at"], name: "index_motor_insurances_on_created_at"
    t.index ["customer_id", "created_at"], name: "index_motor_insurances_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_motor_insurances_on_customer_id"
    t.index ["distributor_id"], name: "index_motor_insurances_on_distributor_id"
    t.index ["insurance_company_code"], name: "index_motor_insurances_on_insurance_company_code"
    t.index ["investor_id"], name: "index_motor_insurances_on_investor_id"
    t.index ["is_admin_added", "is_customer_added", "is_agent_added"], name: "idx_motor_insurances_drwise"
    t.index ["lead_id"], name: "index_motor_insurances_on_lead_id", unique: true
    t.index ["policy_end_date", "created_at"], name: "index_motor_insurances_on_policy_end_date_and_created_at"
    t.index ["policy_end_date"], name: "index_motor_insurances_on_policy_end_date"
    t.index ["policy_type"], name: "index_motor_insurances_on_policy_type"
    t.index ["sub_agent_id"], name: "index_motor_insurances_on_sub_agent_id"
    t.unique_constraint ["policy_number"], name: "motor_insurances_policy_number_key"
  end

  create_table "mutual_fund_nominees", force: :cascade do |t|
    t.bigint "mutual_fund_id", null: false
    t.string "nominee_name", null: false
    t.string "relationship"
    t.integer "age"
    t.decimal "share_percentage", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mutual_fund_id"], name: "index_mutual_fund_nominees_on_mutual_fund_id"
  end

  create_table "mutual_funds", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "sub_agent_id"
    t.bigint "distributor_id"
    t.string "investment_type", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "fund_name"
    t.string "folio_number"
    t.string "plan_name"
    t.date "start_date"
    t.date "maturity_date"
    t.string "bank_name"
    t.string "account_type"
    t.string "account_number"
    t.string "ifsc_code"
    t.string "account_holder_name"
    t.string "reference_by_name"
    t.string "broker_name"
    t.decimal "bonus", precision: 15, scale: 2, default: "0.0"
    t.decimal "fund", precision: 15, scale: 2, default: "0.0"
    t.text "extra_note"
    t.decimal "main_agent_commission_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "commission_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "tds_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "tds_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "after_tds_value", precision: 15, scale: 2, default: "0.0"
    t.decimal "sub_agent_commission_percentage", precision: 8, scale: 2, default: "2.0"
    t.decimal "sub_agent_commission_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "sub_agent_tds_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "sub_agent_tds_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "sub_agent_after_tds_value", precision: 15, scale: 2, default: "0.0"
    t.decimal "distributor_commission_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "distributor_commission_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "distributor_tds_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "distributor_tds_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "distributor_after_tds_value", precision: 15, scale: 2, default: "0.0"
    t.decimal "investor_commission_percentage", precision: 8, scale: 2, default: "2.0"
    t.decimal "investor_commission_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "company_expenses_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "company_expenses_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "total_distribution_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "profit_percentage", precision: 8, scale: 2, default: "0.0"
    t.decimal "profit_amount", precision: 15, scale: 2, default: "0.0"
    t.string "main_policy_document_key"
    t.string "main_policy_document_filename"
    t.string "main_policy_document_content_type"
    t.bigint "main_policy_document_size"
    t.date "installment_autopay_start_date"
    t.date "installment_autopay_end_date"
    t.boolean "is_admin_added", default: false
    t.boolean "is_customer_added", default: false
    t.boolean "is_agent_added", default: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_mutual_funds_on_customer_id"
    t.index ["distributor_id"], name: "index_mutual_funds_on_distributor_id"
    t.index ["sub_agent_id"], name: "index_mutual_funds_on_sub_agent_id"
  end

  create_table "other_insurance_documents", force: :cascade do |t|
    t.bigint "other_insurance_id", null: false
    t.string "document_type"
    t.string "title"
    t.text "description"
    t.string "r2_file_key"
    t.string "r2_filename"
    t.string "r2_content_type"
    t.bigint "r2_file_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["other_insurance_id"], name: "index_other_insurance_documents_on_other_insurance_id"
  end

  create_table "other_insurance_nominees", force: :cascade do |t|
    t.bigint "other_insurance_id", null: false
    t.string "nominee_name"
    t.string "relationship"
    t.integer "age"
    t.decimal "share_percentage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["other_insurance_id"], name: "index_other_insurance_nominees_on_other_insurance_id"
  end

  create_table "other_insurances", id: :serial, force: :cascade do |t|
    t.integer "customer_id", null: false
    t.integer "sub_agent_id"
    t.string "insurance_type", limit: 255
    t.string "insurance_company_name", limit: 255
    t.string "policy_number", limit: 255
    t.date "policy_booking_date"
    t.date "policy_start_date"
    t.date "policy_end_date"
    t.decimal "sum_insured", precision: 15, scale: 2
    t.decimal "net_premium", precision: 15, scale: 2
    t.decimal "total_premium", precision: 15, scale: 2
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.boolean "main_agent_commission_received", default: false
    t.string "main_agent_commission_transaction_id"
    t.date "main_agent_commission_paid_date"
    t.text "main_agent_commission_notes"
    t.string "policy_holder"
    t.string "broker_code_type"
    t.integer "agency_code_id"
    t.integer "broker_id"
    t.decimal "gst_percentage"
    t.string "payment_mode"
    t.string "plan_name"
    t.string "policy_term"
    t.string "claim_process"
    t.decimal "commission_amount"
    t.decimal "tds_percentage"
    t.decimal "tds_amount"
    t.decimal "after_tds_value"
    t.decimal "sub_agent_commission_percentage"
    t.decimal "sub_agent_commission_amount"
    t.decimal "sub_agent_tds_percentage"
    t.decimal "sub_agent_tds_amount"
    t.decimal "sub_agent_after_tds_value"
    t.decimal "investor_commission_percentage"
    t.decimal "investor_commission_amount"
    t.decimal "investor_tds_percentage"
    t.decimal "investor_tds_amount"
    t.decimal "investor_after_tds_value"
    t.decimal "ambassador_commission_percentage"
    t.decimal "ambassador_commission_amount"
    t.decimal "ambassador_tds_percentage"
    t.decimal "ambassador_tds_amount"
    t.decimal "ambassador_after_tds_value"
    t.decimal "company_expenses_percentage"
    t.decimal "total_distribution_percentage"
    t.decimal "profit_percentage"
    t.decimal "profit_amount"
    t.date "installment_autopay_start_date"
    t.date "installment_autopay_end_date"
    t.decimal "main_agent_commission_percentage"
    t.string "policy_type"
    t.string "lead_id"
    t.integer "policy_id"
    t.boolean "is_customer_added", default: false
    t.boolean "is_agent_added", default: false
    t.boolean "is_admin_added", default: false
    t.boolean "policy_added_by_admin", default: false
    t.string "status"
    t.boolean "is_renewed"
    t.integer "original_policy_id"
    t.string "insurance_company_code"
    t.integer "distributor_id"
    t.boolean "product_through_dr", default: true
    t.index ["created_at"], name: "index_other_insurances_on_created_at"
    t.index ["customer_id", "created_at"], name: "index_other_insurances_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_other_insurances_on_customer_id"
    t.index ["distributor_id"], name: "index_other_insurances_on_distributor_id"
    t.index ["insurance_company_code"], name: "index_other_insurances_on_insurance_company_code"
    t.index ["is_admin_added", "is_customer_added", "is_agent_added"], name: "idx_other_insurances_drwise"
    t.index ["lead_id"], name: "index_other_insurances_on_lead_id"
    t.index ["policy_end_date", "created_at"], name: "index_other_insurances_on_policy_end_date_and_created_at"
    t.index ["policy_end_date"], name: "index_other_insurances_on_policy_end_date"
    t.index ["policy_id"], name: "index_other_insurances_on_policy_id"
    t.index ["sub_agent_id"], name: "index_other_insurances_on_sub_agent_id"
  end

  create_table "payout_audit_logs", force: :cascade do |t|
    t.string "auditable_type"
    t.integer "auditable_id"
    t.string "action"
    t.json "changes"
    t.string "performed_by"
    t.string "ip_address"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_payout_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_payout_audit_logs_on_created_at"
    t.index ["performed_by"], name: "index_payout_audit_logs_on_performed_by"
  end

  create_table "payouts", id: :serial, force: :cascade do |t|
    t.string "policy_type", limit: 255
    t.integer "policy_id"
    t.integer "customer_id"
    t.decimal "total_commission_amount", precision: 15, scale: 2
    t.string "status", limit: 255
    t.date "payout_date"
    t.string "processed_by", limit: 255
    t.datetime "processed_at", precision: nil
    t.text "notes"
    t.string "reference_number", limit: 255
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.decimal "main_agent_commission_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "affiliate_commission_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "ambassador_commission_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "investor_commission_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "company_expense_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "net_premium", precision: 15, scale: 2
    t.decimal "main_agent_percentage"
    t.decimal "affiliate_percentage"
    t.decimal "ambassador_percentage"
    t.decimal "investor_percentage"
    t.decimal "company_expense_percentage"
    t.boolean "main_agent_commission_received", default: false
    t.string "main_agent_commission_transaction_id"
    t.date "main_agent_commission_paid_date"
    t.text "main_agent_commission_notes"
    t.index ["created_at"], name: "index_payouts_on_created_at"
    t.index ["customer_id"], name: "index_payouts_on_customer_id"
    t.index ["policy_type", "policy_id"], name: "index_payouts_on_policy_type_and_id"
    t.index ["status"], name: "index_payouts_on_status"
  end

  create_table "permissions", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "module_name", limit: 255
    t.string "action_type", limit: 255
    t.text "description"
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "policies", id: :serial, force: :cascade do |t|
    t.integer "customer_id", null: false
    t.string "policy_type", limit: 255
    t.string "policy_number", limit: 255
    t.string "insurance_company", limit: 255
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "insurance_type", default: "life"
    t.string "payment_mode", default: "yearly"
    t.date "policy_start_date"
    t.date "policy_end_date"
    t.decimal "sum_insured", precision: 12, scale: 2, default: "0.0"
    t.decimal "net_premium", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_premium", precision: 10, scale: 2, default: "0.0"
    t.boolean "status", default: true
    t.string "plan_name"
    t.decimal "gst_percentage", precision: 5, scale: 2, default: "18.0"
    t.integer "user_id"
    t.integer "insurance_company_id"
    t.integer "agency_broker_id"
    t.string "policy_holder"
    t.index ["insurance_type"], name: "index_policies_on_insurance_type"
    t.index ["policy_end_date"], name: "index_policies_on_policy_end_date"
    t.index ["policy_start_date"], name: "index_policies_on_policy_start_date"
    t.index ["status"], name: "index_policies_on_status"
  end

  create_table "policy_documents", force: :cascade do |t|
    t.string "policy_type", null: false
    t.integer "policy_id", null: false
    t.string "document_type", null: false
    t.string "title", null: false
    t.text "description"
    t.string "uploaded_by"
    t.string "r2_file_key"
    t.string "r2_filename"
    t.string "r2_content_type"
    t.bigint "r2_file_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_policy_documents_on_created_at"
    t.index ["document_type"], name: "index_policy_documents_on_document_type"
    t.index ["policy_type", "policy_id"], name: "index_policy_documents_on_policy_type_and_policy_id"
  end

  create_table "reports", force: :cascade do |t|
    t.string "name"
    t.string "report_type"
    t.text "filters"
    t.text "report_data"
    t.boolean "status"
    t.datetime "generated_at"
    t.integer "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "role_permissions", id: :serial, force: :cascade do |t|
    t.integer "role_id", null: false
    t.integer "permission_id", null: false
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.text "description"
    t.boolean "status"
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "session_activities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "activity_type"
    t.datetime "occurred_at"
    t.string "ip_address"
    t.text "user_agent"
    t.string "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_session_activities_on_user_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sub_agent_documents", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "document_type"
    t.bigint "sub_agent_id", null: false
    t.string "r2_file_key"
    t.string "r2_filename"
    t.string "r2_content_type"
    t.bigint "r2_file_size"
    t.index ["document_type"], name: "index_sub_agent_documents_on_document_type"
    t.index ["sub_agent_id"], name: "index_sub_agent_documents_on_sub_agent_id"
  end

  create_table "sub_agents", id: :serial, force: :cascade do |t|
    t.string "first_name", limit: 255, null: false
    t.string "middle_name", limit: 255
    t.string "last_name", limit: 255, null: false
    t.string "mobile", limit: 255, null: false
    t.string "email", limit: 255, null: false
    t.integer "role_id", null: false
    t.integer "state_id"
    t.integer "city_id"
    t.date "birth_date"
    t.string "gender", limit: 255
    t.string "pan_no", limit: 255
    t.string "gst_no", limit: 255
    t.string "company_name", limit: 255
    t.text "address"
    t.string "bank_name", limit: 255
    t.string "account_no", limit: 255
    t.string "ifsc_code", limit: 255
    t.string "account_holder_name", limit: 255
    t.string "account_type", limit: 255
    t.string "upi_id", limit: 255
    t.integer "status", default: 0
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "password_digest"
    t.boolean "deactivated", default: false
    t.string "state"
    t.string "city"
    t.bigint "distributor_id"
    t.string "original_password"
    t.index ["created_at"], name: "index_sub_agents_on_created_at"
    t.index ["distributor_id"], name: "index_sub_agents_on_distributor_id"
    t.index ["email"], name: "index_sub_agents_on_email", unique: true
    t.index ["mobile"], name: "index_sub_agents_on_mobile", unique: true
    t.index ["role_id"], name: "index_sub_agents_on_role_id"
    t.index ["status"], name: "index_sub_agents_on_status"
  end

  create_table "support_ticket_replies", force: :cascade do |t|
    t.bigint "support_ticket_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["support_ticket_id"], name: "index_support_ticket_replies_on_support_ticket_id"
    t.index ["user_id"], name: "index_support_ticket_replies_on_user_id"
  end

  create_table "support_tickets", force: :cascade do |t|
    t.bigint "forum_id"
    t.bigint "chapter_id"
    t.bigint "raised_by_id", null: false
    t.string "subject", null: false
    t.text "body", null: false
    t.integer "status", default: 0, null: false
    t.integer "priority", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chapter_id"], name: "index_support_tickets_on_chapter_id"
    t.index ["forum_id"], name: "index_support_tickets_on_forum_id"
    t.index ["raised_by_id"], name: "index_support_tickets_on_raised_by_id"
    t.index ["status"], name: "index_support_tickets_on_status"
  end

  create_table "system_settings", id: :serial, force: :cascade do |t|
    t.string "company_name", limit: 255
    t.text "company_address"
    t.string "company_phone", limit: 255
    t.string "company_email", limit: 255
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key"
    t.text "value"
    t.text "description"
    t.string "setting_type"
    t.decimal "default_main_agent_commission", precision: 5, scale: 2
    t.decimal "default_affiliate_commission", precision: 5, scale: 2
    t.decimal "default_ambassador_commission", precision: 5, scale: 2
    t.decimal "default_company_expenses", precision: 5, scale: 2
    t.text "terms_and_conditions"
    t.index ["key"], name: "index_system_settings_on_key", unique: true
  end

  create_table "tax_services", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "travel_packages", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "user_roles", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.text "description"
    t.boolean "status"
    t.integer "display_order"
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "session_id", null: false
    t.string "ip_address"
    t.text "user_agent"
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.integer "duration"
    t.string "status", default: "active"
    t.string "location"
    t.string "device_type"
    t.string "browser"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ip_address"], name: "index_user_sessions_on_ip_address"
    t.index ["session_id"], name: "index_user_sessions_on_session_id", unique: true
    t.index ["started_at"], name: "index_user_sessions_on_started_at"
    t.index ["status"], name: "index_user_sessions_on_status"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "first_name", limit: 255
    t.string "last_name", limit: 255
    t.string "email", limit: 255
    t.string "mobile", limit: 255
    t.string "pan_number", limit: 255
    t.string "gst_number", limit: 255
    t.date "date_of_birth"
    t.string "gender", limit: 255
    t.string "height", limit: 255
    t.string "weight", limit: 255
    t.string "education", limit: 255
    t.string "marital_status", limit: 255
    t.string "occupation", limit: 255
    t.string "job_name", limit: 255
    t.string "type_of_duty", limit: 255
    t.decimal "annual_income"
    t.string "birth_place", limit: 255
    t.string "address", limit: 255
    t.string "state", limit: 255
    t.string "city", limit: 255
    t.string "user_type", limit: 255
    t.string "role", limit: 255
    t.boolean "status"
    t.text "additional_info"
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "encrypted_password", limit: 255, default: "", null: false
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.text "sidebar_permissions"
    t.string "role_name", limit: 255
    t.integer "role_id"
    t.string "original_password"
    t.text "crud_permissions"
    t.string "middle_name"
    t.string "password_digest"
    t.boolean "is_active", default: true
    t.boolean "is_verified", default: false
    t.date "birth_date"
    t.string "pan_no"
    t.string "aadhar_no"
    t.string "gst_no"
    t.string "company_name"
    t.string "pincode"
    t.string "country", default: "India"
    t.string "profile_picture"
    t.string "bank_name"
    t.string "account_no"
    t.string "ifsc_code"
    t.string "account_holder_name"
    t.string "account_type"
    t.string "upi_id"
    t.string "emergency_contact_name"
    t.string "emergency_contact_mobile"
    t.string "department"
    t.string "designation"
    t.date "joining_date"
    t.decimal "salary", precision: 10, scale: 2
    t.string "employee_id"
    t.integer "reporting_manager_id"
    t.text "permissions"
    t.datetime "last_login_at"
    t.integer "login_count", default: 0
    t.datetime "email_verified_at"
    t.datetime "mobile_verified_at"
    t.boolean "two_factor_enabled", default: false
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unlock_token"
    t.datetime "locked_at"
    t.integer "failed_attempts", default: 0
    t.text "notes"
    t.integer "created_by"
    t.integer "updated_by"
    t.datetime "deleted_at"
    t.bigint "forum_id"
    t.bigint "chapter_id"
    t.string "session_token", null: false
    t.index ["aadhar_no"], name: "index_users_on_aadhar_no", unique: true
    t.index ["chapter_id"], name: "index_users_on_chapter_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["employee_id"], name: "index_users_on_employee_id", unique: true
    t.index ["forum_id"], name: "index_users_on_forum_id"
    t.index ["is_active"], name: "index_users_on_is_active"
    t.index ["mobile"], name: "index_users_on_mobile", unique: true
    t.index ["pan_no"], name: "index_users_on_pan_no", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["session_token"], name: "index_users_on_session_token", unique: true
    t.index ["status"], name: "index_users_on_status"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["user_type"], name: "index_users_on_user_type"
  end

  add_foreign_key "announcements", "chapters"
  add_foreign_key "announcements", "forums"
  add_foreign_key "announcements", "users", column: "created_by_id"
  add_foreign_key "announcements", "users", column: "target_user_id"
  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "users", column: "created_by_id"
  add_foreign_key "chapters", "forums"
  add_foreign_key "event_registrations", "events"
  add_foreign_key "event_registrations", "users"
  add_foreign_key "events", "chapters"
  add_foreign_key "events", "forums"
  add_foreign_key "forum_requests", "business_plans"
  add_foreign_key "forum_requests", "forums"
  add_foreign_key "forum_requests", "users", column: "reviewed_by_id"
  add_foreign_key "forums", "business_plans"
  add_foreign_key "health_insurance_documents", "health_insurances"
  add_foreign_key "health_insurance_nominees", "health_insurances"
  add_foreign_key "health_insurances", "health_insurances", column: "original_policy_id", name: "health_insurances_original_policy_id_fkey"
  add_foreign_key "helpdesk_tickets", "customers"
  add_foreign_key "helpdesk_tickets", "sub_agents"
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "leads", "distributors", column: "ambassador_id"
  add_foreign_key "life_insurance_nominees", "life_insurances"
  add_foreign_key "life_insurances", "distributors"
  add_foreign_key "loans", "customers"
  add_foreign_key "motor_insurance_documents", "motor_insurances"
  add_foreign_key "motor_insurance_nominees", "motor_insurances"
  add_foreign_key "motor_insurances", "brokers"
  add_foreign_key "mutual_fund_nominees", "mutual_funds"
  add_foreign_key "mutual_funds", "customers"
  add_foreign_key "mutual_funds", "distributors"
  add_foreign_key "mutual_funds", "sub_agents"
  add_foreign_key "other_insurance_documents", "other_insurances", name: "other_insurance_documents_other_insurance_id_fkey"
  add_foreign_key "other_insurance_nominees", "other_insurances"
  add_foreign_key "other_insurances", "policies"
  add_foreign_key "session_activities", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "sub_agent_documents", "sub_agents"
  add_foreign_key "sub_agents", "distributors"
  add_foreign_key "support_ticket_replies", "support_tickets"
  add_foreign_key "support_ticket_replies", "users"
  add_foreign_key "support_tickets", "chapters"
  add_foreign_key "support_tickets", "forums"
  add_foreign_key "support_tickets", "users", column: "raised_by_id"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "users", "chapters"
  add_foreign_key "users", "forums"
end
