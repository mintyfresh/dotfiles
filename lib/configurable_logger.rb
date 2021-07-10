# frozen_string_literal: true

require 'logger'

module ConfigurableLogger
  # @return [Logger]
  def self.default_logger
    Logger.new(
      STDOUT,
      level:     ENV['VERBOSE'] ? Logger::DEBUG : Logger::INFO,
      formatter: -> (*, message) { "#{message}\n" }
    )
  end

  def self.included(klass)
    super(klass)

    class << klass
      attr_accessor :logger
    end

    klass.logger = default_logger
  end

  # @return [Logger]
  def logger
    self.class.logger
  end
end
