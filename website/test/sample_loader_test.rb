# frozen_string_literal: true

require "minitest/autorun"
require "rack/mock"
require_relative "../sample_loader"

class SampleLoaderTest < Minitest::Test
  class CapturingStore
    attr_reader :reports

    def initialize
      @reports = []
    end

    def report(severity, progname, message, options = {})
      @reports << { severity: severity, progname: progname, message: message, options: options }
    end
  end

  def setup
    @store = CapturingStore.new
    @loader = SampleLoader.new(store: @store)
  end

  def test_mixed_scenario_generates_varied_report_shapes
    result = @loader.report_scenario(scenario: "mixed", count: 14, seed: 1234)

    assert_equal 14, result[:generated]
    assert_equal 14, @store.reports.length
    assert_operator @store.reports.map { |report| report[:severity] }.uniq.length, :>=, 4
    assert @store.reports.any? { |report| report[:options][:env].is_a?(Array) }
    assert @store.reports.any? { |report| report[:options][:env].is_a?(Hash) }
    assert @store.reports.any? { |report|
             report[:options][:env].values.any? { |value| value.is_a?(Hash) }
           }
    assert @store.reports.any? { |report| report[:message].include?("\n") }
    assert @store.reports.any? { |report| report[:options][:backtrace] }
    assert @store.reports.any? { |report| report[:options][:backtrace].nil? }
  end

  def test_seed_makes_a_batch_reproducible
    first_store = CapturingStore.new
    second_store = CapturingStore.new

    SampleLoader.new(store: first_store).report_scenario(scenario: "jobs", count: 4, seed: 99)
    SampleLoader.new(store: second_store).report_scenario(scenario: "jobs", count: 4, seed: 99)

    first =
      first_store.reports.map do |report|
        report[:options][:env].reject { |key, _| key == :timestamp }
      end
    second =
      second_store.reports.map do |report|
        report[:options][:env].reject { |key, _| key == :timestamp }
      end
    assert_equal first, second
  end

  def test_rejects_invalid_scenarios_and_batch_sizes
    assert_raises(ArgumentError) { @loader.report_scenario(scenario: "nope", count: 1) }
    assert_raises(ArgumentError) { @loader.report_scenario(scenario: "mixed", count: 0) }
    assert_raises(ArgumentError) do
      @loader.report_scenario(scenario: "mixed", count: SampleLoader::MAX_BATCH_SIZE + 1)
    end
  end
end
