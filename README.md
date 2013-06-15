# Tribe

Tribe is a Ruby gem that implements event-driven [actors] (http://en.wikipedia.org/wiki/Actor_model "actors").
Actors are lightweight concurrent objects that use asynchronous message passing for communication.

Tribe focuses on high performance, low latency, a simple API, and flexibility.
It's goal is to support at least one million actors running on a small group of threads.
It is built on top of the [Workers] (https://github.com/chadrem/workers "Workers") gem.

Event-driven servers can be built using [Tribe EM] (https://github.com/chadrem/tribe_em "Tribe EM").

## Contents

- [Installation](#installation)
- [Actors](#actors)
  - [Root](#root-actor)
  - [Handlers](#handlers)
  - [Messages](#messages)
- [Registries](#registries)
- [Timers](#timers)
- [Futures](#futures)
  - [Non-blocking](#non-blocking)
  - [Blocking](#blocking)
  - [Timeouts](#timeouts)
  - [Performance](#performance-summary)
- [Forwarding](#forwarding)
- [Linking](#linking)
- [Supervisors](#supervisors)
- [Benchmarks](#benchmarks)
- [Contributing](#contributing)

## Installation

Add this line to your application's Gemfile:

    gem 'tribe'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tribe

## Actors

Actors are the building blocks of your application.
There are three ways to create an actor class:

- Inherit from Tribe::Actor (uses the shared thread pool).
- Inherit from Tribe::DedicatedActor (uses a dedicated thread).
- Mixin Tribe::Actable and call the Actable#init_actable method in your constructor.


#### Root

Well designed applications built with the actor model tend to organize their actors in a tree like structure.
To encourage this, Tribe has a special built-in actor known as the root actor.
You should use this actor to spawn all of your application specific actors.

    Tribe.root

#### Handlers

There are two types of methods that you create in your actor classes:

1. *Command handlers* are prefixed with "on_" and define the types of commands your actor will process.
2. *System handlers* are postfixed with "_handler" and are built into the actor system.  These are hooks into the Tribe's actor system.

#### Messages

Actors communicate asynchronously using a number of methods that end in ! (exclamation point or “bang”).
The most basic type of communication is known as a message and can be sent using using the Actable#message! and Actable#deliver_message! methods.
These methods always return nil since they are fire-and-forget.

    # Create your custom actor class.
    class MyActor < Tribe::Actor
      private
      def on_my_custom(event)
        puts "Received a custom event (#{event.inspect})."
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

    # Create some named actors that are children of the root actor.
    100.times do |i|
      Tribe.root.spawn(MyActor, :name => "my_actor_#{i}")
    end

    # Send an event to each actor.
    100.times do |i|
      actor = Tribe.registry["my_actor_#{i}"]
      actor.deliver_message!(:my_custom, 'hello world')
    end

    # Shutdown the actors.
    100.times do |i|
      actor = Tribe.registry["my_actor_#{i}"]
      actor.shutdown!
    end

## Registries

Registries hold references to named actors so that you can easily find them.
In general you shouldn't have to create your own since there is a global one (Tribe.registry).

    actor = Tribe.root.spawn(Tribe::Actor, :name => 'some_actor')

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
      Tribe.root.spawn(MyActor, :name => "my_actor_#{i}")
    end

    # Sleep in order to observe the timers.
    sleep(10)

    # Shutdown the actors.
    10.times do |i|
      actor = Tribe.registry["my_actor_#{i}"]
      actor.shutdown!
    end

## Futures

Message passing with the Actable#message! and Actable#deliver_message! methods is asynchronous and always returns nil.
This can be a pain since in many cases you will be interested in the result.
The Actable#future! method solves this problem by returning a Tribe::Future object.
You can then use this object to obtain the result when it becomes available.

#### Non-blocking

Non-blocking futures are asynchronous and use callbacks.
No waiting for a result is involved and the actor will continue to process other events.

    class ActorA < Tribe::Actor
    private
      def exception_handler(e)
        super
        puts concat_e("ActorA (#{identifier}) died.", e)
      end

      def on_start(event)
        friend = registry['actor_b']
        future = future!(friend, :compute, 10)

        future.success do |result|
          puts "ActorA (#{identifier}) future result: #{result}"
        end

        future.failure do |exception|
          puts "ActorA (#{identifier}) future failure: #{exception}"
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

    actor_a = Tribe.root.spawn(ActorA, :name => 'actor_a')
    actor_b = Tribe.root.spawn(ActorB, :name => 'actor_b')

    actor_a.deliver_message!(:start)

    actor_a.shutdown!
    actor_b.shutdown!

#### Blocking

Blocking futures are synchronous.
The actor won't process any other events until the future has a result.

    class ActorA < Tribe::Actor
    private
      def exception_handler(e)
        super
        puts concat_e("ActorA (#{identifier}) died.", e)
      end

      def on_start(event)
        friend = registry['actor_b']
        future = future!(friend, :compute, 10)

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

    actor_a = Tribe.root.spawn(ActorA, :name => 'actor_a')
    actor_b = Tribe.root.spawn(ActorB, :name => 'actor_b')

    actor_a.deliver_message!(:start)

    actor_a.shutdown!
    actor_b.shutdown!

#### Timeouts

Futures can be confgured to timeout after a specified number of seconds.
When a timeout occurs, the result of the future will be a Tribe::FutureTimeout exception.

    # Manually create a future for this example (Use Actable#future! in your actors).
    future = Tribe::Future.new

    # Set a timeout (in seconds).
    future.timeout = 2

    # Wait for the timeout.
    sleep(3)

    # The result of the future is a timeout exception.
    puts "Result: #{future.result}"

#### Performance Summary

Below you will find a summary of performance recommendations regarding the use of futures:

- Use Actable#message! unless you really need Actable#future! since futures have overhead.
- If you use Actable#future!, prefer the non-blocking API over the blocking one.
- If you use the blocking API, the actor calling Future#wait should use a dedicated worker thread.

## Forwarding

Messages and futures can be forwarded to other actors.
This lets you build routers that delegate work to other actors.

    # Create your router class.
    class MyRouter < Tribe::Actor
      private
      def initialize(options = {})
        super
        @processors = 100.times.map { MyProcessor.new }
      end

      def on_process(event)
        forward!(@processors[rand(100)])
      end

      def exception_handler(e)
        super
        puts concat_e("MyRouter (#{identifier}) died.", e)
      end

      def shutdown_handler(event)
        super
        puts "MyRouter (#{identifier}) is shutting down.  Put cleanup code here."
        @processors.each { |p| p.shutdown! }
      end
    end

    # Create your processor class.
    class MyProcessor < Tribe::Actor
      private
      def on_process(event)
        puts "MyProcessor (#{identifier}) received a process event (#{event.inspect})."
      end

      def exception_handler(e)
        super
        puts concat_e("MyProcessor (#{identifier}) died.", e)
      end

      def shutdown_handler(event)
        super
        puts "MyProcessor (#{identifier}) is shutting down.  Put cleanup code here."
      end
    end

    # Create the router.
    router = Tribe.root.spawn(MyRouter, :name => 'router')

    # Send an event to the router and it will forward it to a random processor.
    100.times do |i|
      router.deliver_message!(:process, i)
    end

    # Shutdown the router.
    router.shutdown!

## Linking

Linking allows actors to group together into a tree structure such that they all live or die as one group.
Such linking is useful for breaking up complex problems into multiple smaller units.
To create a linked actor you use the Actable#spawn method.
By default, if any actor in a tree of linked actors dies, it will kill its parent and children.

    # Create the top-level actor class.
    class Level1 < Tribe::Actor
      private
      def on_spawn(event)
        5.times do |i|
          name = "level2_#{i}"
          puts name
          actor = spawn(Level2, :name => name)
          message!(actor, :spawn, i)
        end
      end
    end

    # Create the mid-level actor class.
    class Level2 < Tribe::Actor
      private
      def on_spawn(event)
        5.times do |i|
          name = "level3_#{event.data}_#{i}"
          actor = spawn(Level3, :name => name)
          message!(actor, :spawn)
        end
      end
    end

    # Create the bottom level actor class.
    class Level3 < Tribe::Actor
      private
      def on_spawn(event)
        puts "#{identifier} hello world!"
      end
    end

    # Create the top-level actor.
    top = Tribe.root.spawn(Level1, :name => 'level1')

    # Tell the root actor to create the tree of children.
    top.deliver_message!(:spawn)

## Supervisors

A failure in a linked actor will cause all associated actors (parent and children) to die.
Supervisors can be used to block the failure from propogating and allow you to restart the failed section of the tree.

    # Create the top-level actor class.
    class Level1 < Tribe::Actor
      private
      def on_spawn(event)
        5.times do |i|
          create_subtree
        end
      end

      def create_subtree
        actor = spawn(Level2)
        message!(actor, :spawn)
      end

      def child_died_handler(actor, exception)
        puts "My child (#{actor.identifier}) died.  Restarting it."
        create_subtree
      end
    end

    # Create the mid-level actor class.
    class Level2 < Tribe::Actor
      private
      def on_spawn(event)
        5.times do |i|
          actor = spawn(Level3)
          message!(actor, :spawn)
        end
      end
    end

    # Create the bottom level actor class.
    class Level3 < Tribe::Actor
      private
      def on_spawn(event)
        puts "#{identifier} says hello world!"
        raise 'Sometimes I like to die.' if rand < 0.5
      end
    end

    # Create the top-level actor.
    top = Tribe.root.spawn(Level1, :name => 'root')

    # Tell the top-level actor to create the tree of children.
    top.deliver_message!(:spawn)

#### Important!

Restarting named actors is NOT currently supported, but will be in a future update.
Attempting to do so may result in Tribe::RegistryError exceptions when trying to spawn a replacement child.

## Benchmarks

  Please see the [performance] (https://github.com/chadrem/tribe/wiki/Performance "performance") wiki page for more information.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
