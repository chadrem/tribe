module Tribe
  class Root < Tribe::Actor
    private

    def initialize(options = {})
      unless options[:permit_root]
        raise 'Application code should never create the root actor.'
      end

      options.delete(:permit_root)

      super
    end

    def child_died_handler(child, exception)
      # Let the children die silently since the root actor should live forever.
      begin
        super
      rescue Tribe::ActorChildDied => e
      end
    end
  end
end
