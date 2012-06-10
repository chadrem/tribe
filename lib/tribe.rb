require 'singleton'
require 'thread'
require 'set'

require 'tribe/actor'
require 'tribe/worker'
require 'tribe/scheduler'
require 'tribe/registry'
require 'tribe/clock'
require 'tribe/timer'

module Tribe
  def self.scheduler
    @scheduler ||= Tribe::Scheduler.new
  end

  def self.registry
    @registry ||= Tribe::Registry.new
  end

  def self.clock
    @clock ||= Tribe::Clock.new
  end
end

Tribe.scheduler
Tribe.registry
Tribe.clock
