class Api::CitiesController < ApplicationController
  include LocationData

  # Skip authentication for this API endpoint
  skip_before_action :authenticate_user!

  # Skip CanCan load_and_authorize_resource for this API endpoint
  skip_load_and_authorize_resource

  def index
    state = params[:state]
    query = params[:query]

    if query.present?
      cities = LocationData.search_cities_in_state(state, query, 50)
    else
      cities = LocationData.cities_for_state(state)
    end

    render json: { cities: cities }
  end

  private

  def should_authorize?
    false
  end
end