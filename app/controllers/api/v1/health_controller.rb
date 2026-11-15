module Api
  module V1
    class HealthController < ApplicationController
      skip_before_action :require_sign_in

      def show
        ActiveRecord::Base.connection.execute("SELECT 1")
        render json: { status: "ok" }
      end
    end
  end
end
