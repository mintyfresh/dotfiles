# frozen_string_literal: true

require 'forwardable'
require 'logger'
require 'pathname'

require_relative 'configurable_logger'

class Installer
  include ConfigurableLogger

  HOME_PATH = Pathname.new(ENV['HOME']).freeze
  ROOT_PATH = Pathname.new(File.expand_path('..', __dir__)).freeze

  Instruction = Struct.new(:source, :destination)

  def initialize
    @instructions = []
  end

  # @param paths [Hash{String => String}]
  # @return [void]
  def add(paths)
    paths.each do |source, destination|
      source      = resolve_source_path(source)
      destination = resolve_destination_path(destination)

      @instructions << Instruction.new(source, destination).freeze
    end
  end

  # @return [void]
  def install!
    @instructions.each do |instruction|
      logger.info("Installing: #{instruction.destination} => #{instruction.source}")

      case create_symlink(instruction)
        in [:error, message]
          logger.warn("\tError: #{message}, skipping!")
        in [:ok, *]
          logger.debug("\tSuccess.")
      end
    end
  end

  # @return [void]
  def uninstall!
    @instructions.each do |instruction|
      logger.info("Uninstalling: #{instruction.destination}")

      case remove_symlink(instruction)
        in [:error, message]
          logger.warn("\tError: #{message}, skipping!")
        in [:ok, *]
          logger.debug("\tSuccess.")
      end
    end
  end

private

  # @param source [String]
  # @return [void]
  def resolve_source_path(source)
    ROOT_PATH.join(source).to_s
  end

  # @param source [String]
  # @return [void]
  def resolve_destination_path(source)
    HOME_PATH.join(File.basename(source)).to_s
  end

  # @param instruction [Instruction]
  # @return [Array]
  def create_symlink(instruction)
    return [:error, "#{instruction.destination} already exists"] if File.exist?(instruction.destination)

    [:ok, File.symlink(instruction.source, instruction.destination)]
  end

  # @param instruction [Instruction]
  # @return [Array]
  def remove_symlink(instruction)
    return [:error, "#{instruction.destination} does not exist"] unless File.exist?(instruction.destination)
    return [:error, "#{instruction.destination} is not a symlink"] unless File.symlink?(instruction.destination)

    [:ok, File.delete(instruction.destination)]
  end
end
