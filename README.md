# Tribe

Tribe is a Ruby gem that implements the [actor model] (http://en.wikipedia.org/wiki/Actor_model "actors") in an event-driven way.

Tribe focuses on high performance, low latency, a simple API, and flexibility.
It's goal is to support at least one million actors running on a small group of threads.
It is built on top of the [Workers] (https://github.com/chadrem/workers "Workers") gem.

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

- Inherit from ````Tribe::Actor```` (uses the shared thread pool).
- Inherit from ````Tribe::DedicatedActor```` (uses a dedicated thread).
- Mixin ````Tribe::Actable```` and call the ````init_actable```` in your constructor.


#### Root

A well designed application organizes its actors in a tree like structure.
To encourage this, Tribe has a special built-in actor known as the root actor.
You should use the root actor to spawn all of your application specific actors.

    class MyActor < Tribe::Actor
      private
      # Your code goes here.
    end

    Tribe.root.spawn(MyActor)

#### Command Handlers

Command handlers are how you customize your actors.
They are private methods that are prefixed with "on_" and they define the commands your actor knows how to handle.
They accept one argument, an instance of ````Tribe::Event```` that shouuld always be named ````event````.

A few command handlers are built into every actor to handle system specific events.  They are:

- ````on_initialize```` This handler takes the place of Ruby's ````initialize````.  It is the first event processsed by all actors.
- ````on_exception```` This handler will be called whenever an exception occurs.  You can access the exception through ````event.data```` in case you want to print it, log it, etc.  An exception inside of an actor will result in that actor's death.
- ````on_shutdown```` This handler will be called whenever an actor is asked to shutdown cleanly.
- ````on_child_died```` This handler gives an actor a chance to spawn a replacement child.  You can access a reference to the child through ````event.data````.  If the actor is a supervisor, it will continue to live otherwise it will die too.
- ````on_child_shutdown```` This handler is similar to ````on_child_died````, but for when a child is shutdown cleanly.
- ````on_parent_died```` This handler is also similar to ````on_child_died```` except for the parent actor.  Child actors die when their parent dies.

You should never call the build in command handlers yourself.
They are reserved for the actor system and calling them yourself could result in unexpected behavior.

## Messages

Messages are the most basic type of communication.  They are sent using using two methods:

- ````message!````: This method is used to tell one actor to send another actor a message.  A reference to the source actor is included in the message in case the destination actor wants to respond.  Usually it is used when your actor code wants to message another actor.
- ````direct_message!````: This method is used to directly message an actor.  Usually it is used when non-actor code wants to message an actor.  No source actor is associated with the message.

Since messages are fire-and-forget, both of the above methods always return ````nil````.

Messages can include data that you want to pass between actors.  It is best practice to treat data as owned by only one actor at a time.  By doing this, you prevent race conditions and the need to create locks for your data.

    # Create your custom actor class.
    class MyActor < Tribe::Actor
      private
      def on_my_custom(event)
        puts "Received a custom event (#{event.inspect})."
      end

      def on_shutdown(event)
        puts "MyActor (#{identifier}) is shutting down."
      end
    end

    # Create some named actors that are children of the root actor.
    100.times do |i|
      Tribe.root.spawn(MyActor, :name => "my_actor_#{i}")
    end

    # Send an event to each actor.
    100.times do |i|
      actor = Tribe.registry["my_actor_#{i}"]
      actor.direct_message!(:my_custom, 'hello world')
    end

    # Shutdown the actors.
    100.times do |i|
      actor = Tribe.registry["my_actor_#{i}"]
      actor.shutdown!
    end

## Registries

Registries hold references to named actors so that you can easily find them.
You don't have to create your own since there is a global one called ````Tribe.registry````.
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
      def on_start(event)
        friend = registry['actor_b']
        future = future!(friend, :compute, 10)

        future.success do |result|
          puts "ActorA (#{identifier}) future result: #{result}"
        end
      end

      def on_shutdown(event)
        puts "MyActor (#{identifier}) is shutting down."
      end
    end

    class ActorB < Tribe::Actor
    private
      def on_shutdown(event)
        puts "MyActor (#{identifier}) is shutting down."
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

    actor_a.direct_message!(:start)

    # Shutdown the actors.
    sleep(3)
    actor_a.shutdown!
    actor_b.shutdown!

#### Blocking

Blocking futures are synchronous.
The actor won't process any other events until the future has a result.

    class ActorA < Tribe::Actor
    private
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
    private
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

    actor_a.direct_message!(:start)

    sleep(3)

    actor_a.shutdown!
    actor_b.shutdown!

#### Timeouts

Futures can be confgured to timeout after a specified number of seconds.
When a timeout occurs, the result of the future will be a ````Tribe::FutureTimeout```` exception.

    class ActorA < Tribe::Actor
    private
      def on_start(event)
        friend = registry['actor_b']
        future = future!(friend, :compute, 10)
        future.timeout = 2

        future.wait # The current thread will sleep until a result is available.

        if future.success?
          puts "ActorA (#{identifier}) future result: #{future.result}"
        else
          puts "ActorA (#{identifier}) future failure: #{future.result}"
        end
      end
    end

    class ActorB < Tribe::Actor
    private
      def on_compute(event)
        sleep(4) # Force a timeout.
        return event.data * 2
      end
    end

    actor_a = Tribe.root.spawn(ActorA, :name => 'actor_a')
    actor_b = Tribe.root.spawn(ActorB, :name => 'actor_b')

    actor_a.direct_message!(:start)

    sleep(6)

    actor_a.shutdown!
    actor_b.shutdown!

#### Performance Summary

Below you will find a summary of performance recommendations for futures:

- Use ````message!```` unless you really need ````future!```` since futures have overhead.
- If you use ````future!````, prefer the non-blocking API over the blocking one.
- If you use the blocking API, the actor calling ````wait```` should use a dedicated worker thread.  Failure to use a dedicated thread will cause a thread from the shared thread pool to block (thus decreasing the size of the thread pool and risking deadlock:).

## Forwarding

Messages and futures can be forwarded to other actors.
This lets you build routers that delegate work to other actors.

    # Create your router class.
    class MyRouter < Tribe::Actor
      private
      def on_initialize(event)
        @processors = 100.times.map { spawn(MyProcessor) }
      end

      def on_process(event)
        forward!(@processors[rand(100)])
      end
    end

    # Create your processor class.
    class MyProcessor < Tribe::Actor
      private
      def on_process(event)
        puts "MyProcessor (#{identifier}) received a process event (#{event.inspect})."
      end
    end

    # Create the router.
    router = Tribe.root.spawn(MyRouter, :name => 'router')

    # Send an event to the router and it will forward it to a random processor.
    100.times do |i|
      router.direct_message!(:process, i)
    end

    # Shutdown the router.
    sleep(3)
    router.shutdown!

## Timers

Actors can create timers to perform some work in the future.
Both one-shot and periodic timers are provided.

    class MyActor < Tribe::Actor
      private
      def on_initialize(event)
        timer(1, :timer, 'hello once')
        periodic_timer(1, :periodic_timer, 'hello many times')
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
To create a linked actor you use the ````spawn```` method.
By default, if a linked actor dies, it will cause its parent and children to die too.
You an override this behavior by using supervisors.

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
    top.direct_message!(:spawn)

## Supervisors

A failure in a linked actor will cause all associated actors (parent and children) to die.
Supervisors can be used to block the failure from propogating.
You then have the option to re-spawn the failed actor.
They are created by passing ````{:supervise => true}```` as a third argument to ````spawn````.
You can then detect dead children by overriding ````on_child_died````.

    # Create the Parent actor class.
    class Parent < Tribe::Actor
      private
      def on_child_died(event)
        puts "My child died.  Creating a new child."
        $second_child = spawn(Child, {:name => 'Child'}, {:supervise => true})
      end
    end

    # Create the Child actor class.
    class Child < Tribe::Actor
      private
    end

    # Create the parent actor.
    $parent = Tribe.root.spawn(Parent, {:name => 'Parent'})

    # Create the first child actor.
    $first_child = $parent.spawn(Child, {:name => 'Child'}, {:supervise => true})

    # Force the first child to die by executing an exception.
    $first_child.perform! { raise 'good bye' }

    # Wait for the first child and parent to run.
    sleep(3)

    # Check if the parent is alive.
    puts "Parent is alive? #{$parent.alive?}"

    # Check if the first child is alive.
    puts "First child is alive? #{$first_child.alive?}"

    # Check if the second child is alive.
    puts "Second child is alive? #{$second_child.alive?}"

## Benchmarks

  Please see the [performance] (https://github.com/chadrem/tribe/wiki/Performance "performance") wiki page for more information.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
