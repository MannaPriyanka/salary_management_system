module Api
  module V1
    class StatisticsController < ApplicationController
      FILTERS = %i[department_id country_id designation_id].freeze

      def summary
        render json: { data: PayStatistics.new(filters: filters).summary }
      end

      def breakdown
        by = params[:by].to_s
        unless PayStatistics::DIMENSIONS.key?(by)
          return render_error(:unprocessable_content, "invalid_breakdown",
                              "Breakdown must be one of: #{PayStatistics::DIMENSIONS.keys.join(', ')}.")
        end

        render json: { data: PayStatistics.new(filters: filters).breakdown(by: by) }
      end

      private

      def filters
        params.permit(*FILTERS).to_h.symbolize_keys
      end
    end
  end
end
