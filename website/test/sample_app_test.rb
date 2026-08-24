# frozen_string_literal: true

ENV["NO_DATA"] = "1"

require "minitest/autorun"
require "rack/mock"
require_relative "../sample"

class SampleAppTest < Minitest::Test
  def setup
    SAMPLE_STORE.clear_all
    @request = Rack::MockRequest.new(Sample.new)
  end

  def teardown
    SAMPLE_STORE.clear_all
  end

  def test_get_is_a_safe_landing_page
    before = SAMPLE_STORE.latest.length
    response = @request.get("/report_error", "HTTP_HOST" => "localhost")

    assert_equal 200, response.status
    assert_includes response.content_type, "text/html"
    assert_includes response.body, "Test-data <span>laboratory</span>"
    assert_includes response.body, 'form id="generator"'
    assert_equal before, SAMPLE_STORE.latest.length, "GET must not report an error"
  end

  def test_post_generates_reports_and_returns_progress_metadata
    response =
      @request.post(
        "/report_error",
        "HTTP_HOST" => "localhost",
        "CONTENT_TYPE" => "application/json",
        :input => JSON.generate(scenario: "requests", count: 3, seed: 42),
      )

    assert_equal 201, response.status
    assert_includes response.content_type, "application/json"
    body = JSON.parse(response.body)
    assert_equal 3, body["generated"]
    assert_equal 42, body["seed"]
    assert_equal "/logs/", body["viewer_url"]
    assert_equal 3, SAMPLE_STORE.latest.length
  end

  def test_post_rejects_invalid_or_oversized_requests
    response =
      @request.post(
        "/report_error",
        "HTTP_HOST" => "localhost",
        "CONTENT_TYPE" => "application/json",
        :input => JSON.generate(scenario: "unknown", count: 1),
      )
    assert_equal 422, response.status

    response =
      @request.post(
        "/report_error",
        "HTTP_HOST" => "localhost",
        "CONTENT_TYPE" => "application/json",
        :input => JSON.generate(scenario: "mixed", count: SampleLoader::MAX_BATCH_SIZE + 1),
      )
    assert_equal 422, response.status
    assert_empty SAMPLE_STORE.latest
  end
end
