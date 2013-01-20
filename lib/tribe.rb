require 'workers'

require 'tribe/mailbox'
require 'tribe/actor'
require 'tribe/dedicated_actor'
require 'tribe/registry'

module Tribe
  def self.registry
    return @registry ||= Tribe::Registry.new
  end 

  def self.registry=(val)
    @registry.dispose if @registry
    @registry = val 
  end 
end

# Force initialization of defaults.
Tribe.registry
