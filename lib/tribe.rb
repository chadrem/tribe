require 'singleton'
require 'thread'
require 'set'
require 'securerandom'

require 'tribe/actor'
require 'tribe/worker'
require 'tribe/dispatcher'
require 'tribe/registry'
require 'tribe/scheduler'
require 'tribe/timer'
require 'tribe/message'
require 'tribe/mailbox'
require 'tribe/thread_pool'

module Tribe
  def self.dispatcher
    @dispatcher ||= Tribe::Dispatcher.new
  end 

  def self.registry
    @registry ||= Tribe::Registry.new
  end 

  def self.scheduler
    @scheduler ||= Tribe::Scheduler.new
  end 
end

Tribe.dispatcher
Tribe.registry
Tribe.scheduler
