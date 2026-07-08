class HelpdeskTicket < ApplicationRecord
  belongs_to :sub_agent
  belongs_to :customer
end
