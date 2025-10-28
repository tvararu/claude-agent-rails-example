module Api
  class SchemaController < ApplicationController
    skip_before_action :verify_authenticity_token

    def index
      tables = ActiveRecord::Base.connection.tables

      render json: {
        tables:,
        count: tables.length
      }
    end
  end
end
