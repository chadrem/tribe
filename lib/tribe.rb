require 'singleton'
require 'thread'
require 'set'

require 'tribe/actor'
require 'tribe/singleton'
require 'tribe/worker'
require 'tribe/scheduler'
require 'tribe/registry'
require 'tribe/clock'
require 'tribe/timer'

module Tribe
  def self.scheduler
    Tribe::Scheduler.instance
  end

  def self.registry
    Tribe::Registry.instance
  end

  def self.clock
    Tribe::Clock.instance
  end
end
