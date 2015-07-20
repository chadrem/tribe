require 'set'
require 'logger'
require 'thread'

require 'workers'

require 'tribe/version'
require 'tribe/safe_set'
require 'tribe/exceptions'
require 'tribe/event'
require 'tribe/mailbox'
require 'tribe/actor_state'
require 'tribe/actable'
require 'tribe/actor'
require 'tribe/dedicated_actor'
require 'tribe/registry'
require 'tribe/future'
require 'tribe/root'

module Tribe
  @lock = Monitor.new

  class << self
    attr_reader :lock
  end

  def self.registry
    @lock.synchronize do
      @registry ||= Tribe::Registry.new
    end
  end

  def self.root
    @lock.synchronize do
      @root ||= Tribe::Root.new(:name => 'root', :permit_root => true)
    end
  end

  def self.logger
    @lock.synchronize do
      @logger
    end
  end

  def self.logger=(val)
    @lock.synchronize do
      @logger = val
    end
  end
end

Tribe.logger = Logger.new(STDOUT)
Tribe.logger.level = Logger::DEBUG
