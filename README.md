# Tribe

Tribe is a Ruby gem that implements the [actor model] (http://en.wikipedia.org/wiki/Actor_model "actors") in an event-driven way.

Tribe focuses on high performance, low latency, a simple API, and flexibility.
It's goal is to support at least one million actors running on a small group of threads.
It is built on top of the [Workers] (https://github.com/chadrem/workers "Workers") gem.

Event-driven servers can be built using [Tribe EM] (https://github.com/chadrem/tribe_em "Tribe EM").

## Contents

- [Installation](#installation)
- [Actors](#actors)
  - [Root](#root)
  - [Handlers](#handlers)
- [Messages](#messages)
- [Registries](#registries)
- [Futures](#futures)
  - [Non-blocking](#non-blocking)
  - [Blocking](#blocking)
  - [Timeouts](#timeouts)
  - [Performance](#performance-summary)
- [Forwarding](#forwarding)
- [Timers](#timers)
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

A well designed application organizes its actors in a tree like structure.
To encourage this, Tribe has a special built-in actor known as the root actor.
You should use the root actor to spawn all of your application specific actors.

    class MyActor < Tribe::Actor
      # Your code goes here.
    end

    Tribe.root.spawn(MyActor)

#### Handlers

There are two types of methods that you create in your actor classes to extend or change actor behavior:

- *Command handlers* are prefixed with "on_" and define the types of commands your actor will process.  None of these are included by default.  You define them for your specific needs.
- *System handlers* are postfixed with "_handler" and are built into the actor system.  You must always first call ````super```` if you override a system handler unless you are prepared to handle internal actor state (advanced users only!).
  - ````event_handler````: Default behavior is to route messages to the correct 'on_' (command handler) or '_handler' (system handler).
  - ````exception_handler````: Default behavior is to kill itself and tell both children and parent to die.
  - ````shutdown_handler````: Default behavior is to shutdown itself and tell children to shutdown.  The parent will be notified of the shutdown also.
  - ````cleanup_handler````: Default behavior is to cleanup state.
  - ````perform_handler````: Default behavior is to execute an arbitrary code block.
  - ````child_died_handler````: Default behavior is to kill itself if a child dies.  The root actor overrides this behavior and you can do the same in order to turn an actor into a supervisor.
  - ````child_shutdown_handler````: Default behavior is to unregister the child.
  - ````parent_died_handler````: default behavior is to kill itself if the parent dies.

## Messages

Messages are the most basic type of communication.  They are sent using using two methods:

- ````message!````: This method is used to tell one actor to send another actor a message.  A reference to the source actor is included in the message in case the destination actor wants to respond.  Usually it is used when your actor code wants to message another actor.
- ````deliver_message!````: This method is used to directly message an actor.  Usually it is used when non-actor code wants to message an actor.

Since messages are fire-and-forget, both of these methods always return ````nil````.

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
You don't have to create your own since there is a global one (Tribe.registry).
The Root actor is named 'root' and stored in the default registry.

    actor = Tribe.root.spawn(Tribe::Actor, :name => 'some_actor')

    if actor == Tribe.registry['some_actor']
      puts 'Successfully found some_actor in the registry.'
    end

## Futures

Messages are limited in that they are one way (fire-and-forget).
Many times you'll be interested in receiving a response and this is when futures become useful.
To send a future you use ````future!```` instead of ````message!````.
It will return a ````Future```` object (instead of ````nil````) that will give you access to the result when it becomes available.

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

    # Shutdown the actors.
    sleep(3)
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

Below you will find a summary of performance recommendations for futures:

- Use Actable#message! unless you really need Actable#future! since futures have overhead.
- If you use Actable#future!, prefer the non-blocking API over the blocking one.
- If you use the blocking API, the actor calling Future#wait should use a dedicated worker thread.  Failure to use a dedicated thread will cause a thread from the shared thread pool to block (thus decreasing the size of the thread pool and risking deadlock:).

## Forwarding

Messages and futures can be forwarded to other actors.
This lets you build routers that delegate work to other actors.

    # Create your router class.
    class MyRouter < Tribe::Actor
      private
      def initialize(options = {})
        super
        @processors = 100.times.map { Tribe.root.spawn(MyProcessor) }
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
    sleep(3)
    router.shutdown!

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

## Linking

Linking allows actors to group together so that they all live or die together.
Such linking is useful for breaking up complex problems into multiple smaller units.
To create a linked actor you use the Actable#spawn method.
By default, if a linked actor dies, it will cause its parent and children to die too.
You an override this behavior using by using supervisors.

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
Supervisors can be used to block the failure from propogating.
You then have the option to re-spawn the failed actor.

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
        begin
          super
        rescue Tribe::ActorChildDied => e
        end

        puts "My child (#{actor.identifier}) died.  Restarting it."
        create_subtree
      end

      def child_shutdown_handler(actor, exception)
        super
        puts "My child (#{actor.identifier}) shutdown.  Ignoring it."
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
    top = Tribe.root.spawn(Level1, :name => 'Level1')

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
