# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "redis"
require_relative "../dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("dummy/db/migrate", __dir__)]

require_relative "../test_helper"

class TestRailtie < Minitest::Test
  def test_sets_logger
    refute_nil Logster.logger

    if Rails.version >= "7.1"
      assert_includes Rails.logger.broadcasts, Logster.logger
    else
      assert_equal Rails.logger, Logster.logger
    end
  end
end
