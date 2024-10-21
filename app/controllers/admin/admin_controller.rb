# frozen_string_literal: true

module Admin
  # class for handling admin responsibilities
  class AdminController < ApplicationController
    before_action :authenticate_user!
    # Ensures only authenticated users can access actions in this controller
    before_action :redirect_unless_admin
    # If the user is not an admin, redirects to a different page
  end
end
