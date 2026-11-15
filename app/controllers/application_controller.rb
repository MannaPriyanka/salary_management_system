class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :require_sign_in

  rescue_from ActiveRecord::RecordNotFound do
    render_error(:not_found, "not_found", "The requested record was not found.")
  end

  private

  def require_sign_in
    render_error(:unauthorized, "not_signed_in", "Sign in is required.") unless current_user
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] ? User.find_by(id: session[:user_id]) : nil
  end

  def sign_in(user)
    reset_session
    session[:user_id] = user.id
    @current_user = user
  end

  def sign_out
    reset_session
    @current_user = nil
  end

  def render_error(status, code, message, details = [])
    render json: { error: { code: code, message: message, details: details } }, status: status
  end

  def render_validation_errors(record)
    details = record.errors.map { |error| { field: error.attribute, message: error.message } }
    render_error(:unprocessable_content, "validation_failed", "One or more fields are invalid.", details)
  end

  def user_json(user)
    { id: user.id, email: user.email }
  end
end
