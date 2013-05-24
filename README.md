# Tribe

Tribe is a Ruby gem that implements event-driven [actors] (http://en.wikipedia.org/wiki/Actor_model "actors").
Actors are lightweight concurrent objects that use asynchronous message passing for communication.
Tribe focuses on high performance, low latency, an easy to use API, and flexibility.
It is built on top of the [Workers] (https://github.com/chadrem/workers "Workers") gem, which allows it to support many actors (millions should be possible).
Actors can use a shared thread pool (default) or dedicted threads.

Event-driven servers can be built using [Tribe EM] (https://github.com/chadrem/tribe_em "Tribe EM").

## Installation

Add this line to your application's Gemfile:

    gem 'tribe'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tribe

## Actors

    # Create your custom actor class.
    class MyActor < Tribe::Actor
      private
      def initialize(options = {})
        super
      end
      
      def on_my_custom(event)
        puts "Received a custom event (#{event.inspect})"
      end
      
      def exception_handler(e)
        super
        puts concat_e("MyActor (#{identifier}) died.", e)
      end
      
      def shutdown_handler(event)
        super
        puts "MyActor (#{identifier}) is shutting down.  Put cleanup code here."
      end
    end
    
    # Create some named actors.
    100.times do |i|
      MyActor.new(:name => "my_actor_#{i}")
    end
    
    # Send an event to each actors.  Find each actor using the global registry.
    100.times do |i|
      actor = Tribe.registry["my_actor_#{i}"]
      actor.enqueue(:my_custom, 'hello world')
    end
    
    # Shutdown the actors.
    100.times do |i|
      actor = Tribe.registry["my_actor_#{i}"]
      actor.enqueue(:shutdown)
    end

### Implementation notes
Because actors use a shared thread pool, it is important that they don't block for long periods of time (short periods are fine).
Actors that block for long periods of time should use a dedicated thread (:dedicated => true or subclass from Tribe::DedicatedActor).

## Registries

Registries hold references to named actors.
In general you shouldn't have to create your own since there is a global one (Tribe.registry).

## Options (defaults below):

    actor = Tribe::Actor.new(
      :logger => nil,                   # Ruby logger instance.
      :dedicated => false,              # If true, the actor runs with a worker pool that has one thread.
      :pool => Workers.pool,            # The workers pool used to execute events.
      :mailbox => Tribe::Mailbox.new,   # The mailbox used to receive events.
      :registry => Tribe.registry,      # The registry used to store a reference to the actor if it has a name.
      :name => nil                      # The name of the actor (must be unique in the registry).
    )

    actor = Tribe::DedicatedActor.new(
      :logger => nil,                   # Ruby logger instance.
      :mailbox => Tribe::Mailbox.new,   # The mailbox used to receive events.
      :registry => Tribe.registry,      # The registry used to store a reference to the actor if it has a name.
      :name => nil                      # The name of the actor (must be unique in the registry).
    )

## Timers

Actors can create timers to perform some work in the future.
Both one-shot and periodic timers are provides.

    class MyActor < Tribe::Actor
      private
      def initialize(options = {})
        super

        timer(1, :timer, Time.now)
        periodic_timer(1, :periodic_timer, Time.now)
      end

      def on_timer(event)
        puts "MyActor (#{identifier}) ONE-SHOT: #{event.data}"
      end

      def on_periodic_timer(event)
        puts "MyActor (#{identifier}) PERIODIC: #{event.data}"
      end
    end

    # Create some named actors.
    10.times do |i|
      MyActor.new(:name => "my_actor_#{i}")
    end

    # Sleep in order to observe the timers.
    sleep 10

    # Shutdown the actors.
    10.times do |i|
      actor = Tribe.registry["my_actor_#{i}"]
      actor.enqueue(:shutdown)
    end

## TODO - missing features

- Futures.
- Supervisors.
- Linking.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
