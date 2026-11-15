# JSON 404 for unknown API paths, so API clients never receive HTML.
class ErrorsController < ApplicationController
  skip_before_action :require_sign_in

  def api_not_found
    render_error(:not_found, "not_found", "The requested endpoint does not exist.")
  end
end
