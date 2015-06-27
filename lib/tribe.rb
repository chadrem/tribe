require 'set'

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
  def self.registry
    return @registry ||= Tribe::Registry.new
  end

  def self.root
    @root ||= Tribe::Root.new(:name => 'root', :permit_root => true)
  end
end
