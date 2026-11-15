# Serves the built React app (public/index.html) for every page path, so a browser refresh on
# /employees/42 loads the app and the app's router shows the right screen.
class SpaController < ActionController::API
  def self.index_path
    Rails.public_path.join("index.html")
  end

  def index
    if self.class.index_path.exist?
      send_file self.class.index_path, type: "text/html", disposition: "inline"
    else
      render json: { error: { code: "frontend_not_built", message: "The web app has not been built. Run npm run build in frontend/.", details: [] } },
             status: :not_found
    end
  end
end
