require 'singleton'
require 'thread'
require 'set'

require 'tribe/actor'
require 'tribe/worker'
require 'tribe/dispatcher'
require 'tribe/registry'
require 'tribe/clock'
require 'tribe/timer'

module Tribe
  def self.dispatcher
    @dispatcher ||= Tribe::Dispatcher.new
  end

  def self.registry
    @registry ||= Tribe::Registry.new
  end

  def self.clock
    @clock ||= Tribe::Clock.new
  end
end

Tribe.dispatcher
Tribe.registry
Tribe.clock
