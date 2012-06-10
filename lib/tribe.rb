require 'singleton'
require 'thread'

require 'tribe/actor'
require 'tribe/singleton'
require 'tribe/worker'
require 'tribe/scheduler'
require 'tribe/registry'

module Tribe
  def self.scheduler
    Tribe::Scheduler.instance
  end

  def self.registry
    Tribe::Registry.instance
  end
end
