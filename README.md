# Tribe

Tribe is a Ruby gem that implements event driven actors.
Actors are light weight concurrent objects that use asynchronous message passing to communicate with each other.

## Installation

Add this line to your application's Gemfile:

    gem 'tribe'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tribe

## Actors

    # Create your custom actor class.
    class MyActor < Workers::Actor
      private
      def initialize(options = {})
        super
      end
      
      def process_event(event)
       case event.command
       when :my_custom
         my_custom_handler(event)
       end
      end
      
      def my_custom_handler(event)
        puts "Received a custom event (#{event.inspect})"
      end
      
      def exception_handler(e)
        puts concat_e("MyActor (#{identifier}) died.", e)
      end
      
      def shutdown_handler(event)
        puts "MyActor (#{identifier}) is shutting down.  Put cleanup code here."
      end
    end
    
    # Create some named actors.
    100.times do |i|
      MyActor.new(:name => "my_actor_#{i}")
    end
    
    # Send an event to each actors.  Find each actor using the registry.
    100.times do |i|
      actor = Workers.registry["my_actor_#{i}"]
      actor.enqueue(:my_custom, 'hello world')
    end
    
    # Shutdown the actors.
    100.times do |i|
      actor = Workers.registry["my_actor_#{i}"]
      actor.enqueue(:shutdown)
    end

### Implementation notes
Because actors use a shared thread pool, it is important that they don't block for long periods of time.
Actors that block for long periods of time should use a dedicated thread (:dedicated => true or subclass from Tribe::DedicatedActor).

## Registries

Registries hold references to named actors.
In general you shouldn't have to create your own since there is a global one (Workers.registry).

## Options (defaults below):

    actor = Workers::Actor.new(
      :logger => nil,                   # Ruby logger instance.
      :dedicated => false,              # If true, the actor runs with a worker pool that has one thread.
      :pool => Workers.pool,            # The workers pool used to execute events.
      :mailbox => Workers::Mailbox.new, # The mailbox used to receive events.
      :registry => Workers.registry,    # The registry used to store a reference to the actor if it has a name.
      :name => nil                      # The name of the actor (must be unique in the registry).
    )

    actor = Workers::DedicatedActor.new(
      :logger => nil,                   # Ruby logger instance.
      :mailbox => Workers::Mailbox.new, # The mailbox used to receive events.
      :registry => Workers.registry,    # The registry used to store a reference to the actor if it has a name.
      :name => nil                      # The name of the actor (must be unique in the registry).
    )

## TODO - missing features

- Futures.
- Workers::Timer integration.
- Supervisors.
- Linking.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

Copyright (c) 2012 Chad Remesch. See LICENSE.txt for further details.
