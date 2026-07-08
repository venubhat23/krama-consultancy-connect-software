class Admin::AppointmentsController < Admin::ApplicationController
  before_action :set_appointment, only: [:show, :edit, :update, :destroy]

  def index
    @appointments = Appointment.includes(:customer, :created_by)
                               .order(
                                 Arel.sql("CASE WHEN appointment_date >= '#{Date.current}' THEN 0 ELSE 1 END"),
                                 :appointment_date,
                                 :time_slot
                               )

    @upcoming_count = Appointment.where('appointment_date >= ?', Date.current).count
    @today_count    = Appointment.where(appointment_date: Date.current).count
    @pending_count  = Appointment.where(status: 'pending').count
    @today_appointments = Appointment.where(appointment_date: Date.current)
                                     .order(:time_slot)
                                     .includes(:customer)

    @active_tab = params[:tab] == 'reminders' ? 'reminders' : 'appointments'

    @selected_date = params[:date].present? ? Date.parse(params[:date]) : nil
    if @selected_date
      @appointments = @appointments.where(appointment_date: @selected_date)
    end
  end

  def new
    @appointment = Appointment.new
    @appointment.appointment_date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @customers = Customer.active.order(:first_name, :last_name).limit(200)
  end

  def create
    @appointment = Appointment.new(appointment_params)
    @appointment.created_by = current_user

    if params[:appointment][:customer_id].present?
      customer = Customer.find_by(id: params[:appointment][:customer_id])
      if customer
        @appointment.customer = customer
        @appointment.customer_name = customer.display_name if @appointment.customer_name.blank?
        @appointment.customer_email = customer.email if @appointment.customer_email.blank?
        @appointment.customer_phone = customer.mobile if @appointment.customer_phone.blank?
      end
    end

    respond_to do |format|
      if @appointment.save
        format.html { redirect_to admin_appointments_path, notice: 'Appointment created successfully.' }
        format.json { render json: { success: true, appointment: appointment_json(@appointment) } }
      else
        format.html {
          @customers = Customer.active.order(:first_name, :last_name).limit(200)
          render :new, status: :unprocessable_entity
        }
        format.json { render json: { success: false, errors: @appointment.errors.full_messages } }
      end
    end
  end

  def show
    render layout: false if request.xhr?
  end

  def edit
    @customers = Customer.active.order(:first_name, :last_name).limit(200)
  end

  def update
    respond_to do |format|
      if @appointment.update(appointment_params)
        format.html { redirect_to admin_appointments_path, notice: 'Appointment updated.' }
        format.json { render json: { success: true } }
      else
        format.html {
          @customers = Customer.active.order(:first_name, :last_name).limit(200)
          render :edit, status: :unprocessable_entity
        }
        format.json { render json: { success: false, errors: @appointment.errors.full_messages } }
      end
    end
  end

  def destroy
    @appointment.destroy
    respond_to do |format|
      format.html { redirect_to admin_appointments_path, notice: 'Appointment deleted.' }
      format.json { render json: { success: true } }
    end
  end

  def calendar_data
    month = params[:month].present? ? params[:month].to_i : Date.current.month
    year  = params[:year].present?  ? params[:year].to_i  : Date.current.year

    start_date = Date.new(year, month, 1)
    end_date   = start_date.end_of_month

    appointments = Appointment.where(appointment_date: start_date..end_date)
                              .select(:id, :appointment_date, :customer_name, :time_slot, :status)

    data = appointments.group_by(&:appointment_date).transform_keys { |d| d.to_s }
                       .transform_values do |appts|
                         appts.map { |a| { id: a.id, customer_name: a.customer_name, time_slot: a.time_slot, status: a.status } }
                       end

    render json: data
  end

  def search_customers
    query = params[:q].to_s.strip
    customers = if query.length >= 2
                  Customer.active
                          .where("first_name ILIKE :q OR last_name ILIKE :q OR email ILIKE :q OR mobile ILIKE :q OR company_name ILIKE :q", q: "%#{query}%")
                          .limit(20)
                else
                  Customer.active.order(:first_name).limit(20)
                end

    render json: customers.map { |c| { id: c.id, name: c.display_name, email: c.email, phone: c.mobile } }
  end

  # GET /admin/appointments/download
  def download
    format_type = params[:format_type]

    scope = Appointment.all
    scope = scope.where(appointment_date: Date.parse(params[:date])) if params[:date].present?
    scope = scope.order(:appointment_date, :time_slot)

    case format_type
    when 'csv'
      send_data generate_appointments_csv(scope), filename: "appointments_#{Date.current}.csv", type: 'text/csv'
    when 'excel'
      send_data generate_appointments_excel(scope),
                filename: "appointments_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to admin_appointments_path, alert: 'Invalid download format.'
    end
  end

  private

  def generate_appointments_csv(records)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[ID CustomerName CustomerEmail CustomerPhone AppointmentDate TimeSlot
                MeetingAgenda Notes Status CreatedAt]
      records.find_each do |a|
        csv << [a.id, a.customer_name, a.customer_email, a.customer_phone,
                a.appointment_date, a.time_slot, a.meeting_agenda, a.notes,
                a.status&.capitalize, a.created_at.strftime('%Y-%m-%d %H:%M:%S')]
      end
    end
  end

  def generate_appointments_excel(records)
    require 'caxlsx'
    package = Axlsx::Package.new
    wb = package.workbook
    hdr = wb.styles.add_style(bg_color: '4A148C', fg_color: 'FFFFFF', b: true,
                               alignment: { horizontal: :center })
    row = wb.styles.add_style(alignment: { horizontal: :left })
    wb.add_worksheet(name: 'Appointments') do |sheet|
      sheet.add_row %w[ID CustomerName CustomerEmail CustomerPhone AppointmentDate TimeSlot
                       MeetingAgenda Notes Status CreatedAt], style: hdr
      records.find_each do |a|
        sheet.add_row [a.id, a.customer_name, a.customer_email, a.customer_phone,
                       a.appointment_date&.to_s, a.time_slot, a.meeting_agenda, a.notes,
                       a.status&.capitalize, a.created_at.strftime('%Y-%m-%d %H:%M:%S')], style: row
      end
    end
    package.to_stream.read
  end

  def set_appointment
    @appointment = Appointment.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(
      :customer_name, :customer_email, :customer_phone,
      :meeting_agenda, :notes, :appointment_date, :time_slot, :status, :customer_id
    )
  end

  def appointment_json(a)
    {
      id: a.id,
      customer_name: a.customer_name,
      customer_email: a.customer_email,
      appointment_date: a.appointment_date.to_s,
      time_slot: a.time_slot,
      status: a.status
    }
  end
end
