module Api
  module V1
    class SessionsController < ApplicationController
      skip_before_action :require_sign_in, only: :create

      rate_limit to: 30, within: 15.minutes, only: :create,
                 with: -> { render_error(:too_many_requests, "rate_limited", "Too many requests. Try again later.") }

      def show
        render json: { data: user_json(current_user) }
      end

      def create
        email = params[:email].to_s.strip.downcase
        password = params[:password].to_s

        if (until_time = SignInProtection.refused_until(email))
          return render_sign_in_refused(until_time)
        end

        user = User.find_by(email: email)
        authenticated = user ? user.authenticate(password) : User.authenticate_unknown(password)

        if authenticated
          SignInProtection.clear(email)
          sign_in(user)
          render json: { data: user_json(user) }, status: :created
        else
          SignInProtection.record_failure(email)
          render_error(:unauthorized, "invalid_credentials", "Invalid email or password.")
        end
      end

      def destroy
        sign_out
        head :no_content
      end

      def update_password
        unless current_user.authenticate(params[:current_password].to_s)
          return render_error(:unprocessable_content, "current_password_incorrect", "The current password is incorrect.")
        end

        if current_user.update(password: params[:new_password].to_s, password_confirmation: params[:new_password].to_s)
          head :no_content
        else
          render_validation_errors(current_user)
        end
      end

      private

      def render_sign_in_refused(until_time)
        response.headers["Retry-After"] = (until_time - Time.current).ceil.to_s
        render_error(:too_many_requests, "sign_in_refused", "Too many failed sign-in attempts. Try again later.")
      end
    end
  end
end
