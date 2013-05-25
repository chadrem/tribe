# Tribe

Tribe is a Ruby gem that implements event-driven [actors] (http://en.wikipedia.org/wiki/Actor_model "actors").
Actors are lightweight concurrent objects that use asynchronous message passing for communication.
Tribe focuses on high performance, low latency, a simple API, and flexibility.
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

#### Implementation notes
*Important*: Because actors use a shared thread pool, it is important that they don't block for long periods of time (short periods are fine).
Actors that block for long periods of time should use a dedicated thread (:dedicated => true or subclass from Tribe::DedicatedActor).

#### Options (defaults below):

    actor = Tribe::Actor.new(
      :logger => nil,                   # Ruby logger instance.
      :dedicated => false,              # If true, the actor runs with a worker pool that has one thread.
      :pool => Workers.pool,            # The workers pool used to execute events.
      :mailbox => Tribe::Mailbox.new,   # The mailbox used to receive events.
      :registry => Tribe.registry,      # The registry used to store a reference to the actor if it has a name.
      :name => nil                      # The name of the actor (must be unique in the registry).
    )

    The DedicatedActor class is a simple wrapper around the Actor class.
    It takes all the same options except for :pool and :dedicated since they aren't applicable.

## Registries

Registries hold references to named actors so that you can easily find them.
In general you shouldn't have to create your own since there is a global one (Tribe.registry).

    actor = Tribe::Actor.new(:name => 'some_actor')

    if actor == Tribe.registry['some_actor']
      puts 'Successfully found some_actor in the registry.'
    end

## Timers

Actors can create timers to perform some work in the future.
Both one-shot and periodic timers are provided.

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

## Futures (experimental)

Futures allow an actor to ask another actor to perform a computation and then return the result.
Tribe includes both blocking and non-blocking actors.
You should prefer to use non-blocking actors in your code when possible due to performance reasons (see details below).

#### Non-blocking

Non-blocking actors are asynchronous and use callbacks.
No waiting for a result is involved.
The actor will continue to process other events.

    class ActorA < Tribe::Actor
    private
      def exception_handler(e)
        super
        puts concat_e("ActorA (#{identifier}) died.", e)
      end

      def on_start(event)
        friend = registry['actor_b']

        future = friend.enqueue_future(:compute, 10)

        future.success do |result|
          perform do
            puts "ActorA (#{identifier}) future result: #{result}"
          end
        end

        future.failure do |exception|
          perform do
            puts "ActorA (#{identifier}) future failure: #{exception}"
          end
        end
      end
    end

    class ActorB < Tribe::Actor
      def exception_handler(e)
        super
        puts concat_e("ActorB (#{identifier}) died.", e)
      end

      def on_compute(event)
        return factorial(event.data)
      end

      def factorial(num)
        return 1 if num <= 0
        return num * factorial(num - 1)
      end
    end

    actor_a = ActorA.new(:name => 'actor_a')
    actor_b = ActorB.new(:name => 'actor_b')

    actor_a.enqueue(:start)

    actor_a.enqueue(:shutdown)
    actor_b.enqueue(:shutdown)

*Important*: You must use Actor#perform inside the above callbacks.
This ensures that your code executes within the context of the correct actor.
Failure to do so will result in race conditions and other nasty things.

#### Blocking

Blocking actors are synchronous.
The actor won't process any other events until the future has a result.

    class ActorA < Tribe::Actor
    private
      def exception_handler(e)
        super
        puts concat_e("ActorA (#{identifier}) died.", e)
      end

      def on_start(event)
        friend = registry['actor_b']

        future = friend.enqueue_future(:compute, 10)

        future.wait # The current thread will sleep until a result is available.

        if future.success?
          puts "ActorA (#{identifier}) future result: #{future.result}"
        else
          puts "ActorA (#{identifier}) future failure: #{future.result}"
        end
      end
    end

    class ActorB < Tribe::Actor
      def exception_handler(e)
        super
        puts concat_e("ActorB (#{identifier}) died.", e)
      end

      def on_compute(event)
        return factorial(event.data)
      end

      def factorial(num)
        return 1 if num <= 0
        return num * factorial(num - 1)
      end
    end

    actor_a = ActorA.new(:name => 'actor_a')
    actor_b = ActorB.new(:name => 'actor_b')

    actor_a.enqueue(:start)

    actor_a.enqueue(:shutdown)
    actor_b.enqueue(:shutdown)

#### Futures and Performance

You should prefer non-blocking futures as much as possible in your application code.
This is because a blocking future (Future#wait) causes the current actor (and thread) to sleep.

Tribe is designed specifically to support a large number of actors running on a small number of threads.
Thus, you will run into performance and/or deadlock problems if too many actors are waiting at the same time.

If you choose to use blocing futures then it is highly recommended that you only use them with dedicated actors.
Each dedicated actor runs in a separate thread (instead of a shared thread pool).
The downside to using dedicated actors is that they consume more resources and you can't have as many of them.

## TODO - missing features

- Supervisors.
- Linking.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
