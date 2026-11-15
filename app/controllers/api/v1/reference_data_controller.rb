module Api
  module V1
    # Read-only lists used by forms. Reference data is created by the seed, not by the API.
    class ReferenceDataController < ApplicationController
      def departments
        render json: { data: Department.where(active: true).order(:name).map { |d| { id: d.id, name: d.name } } }
      end

      def designations
        render json: { data: Designation.where(active: true).order(:name).map { |d| { id: d.id, name: d.name } } }
      end

      def countries
        render json: { data: Country.where(active: true).order(:name).map { |c| { id: c.id, name: c.name, code: c.code } } }
      end

      def currencies
        render json: { data: Currency.where(enabled: true).order(:code).map { |c| { code: c.code, name: c.name, minor_units: c.minor_units } } }
      end
    end
  end
end
