#!/usr/bin/env ruby

module Fluent
  class ChefAPIInput < Input
    Plugin.register_input("chef_api", self)

    def initialize
      super
    end

    def configure(conf)
      super
    end

    def start
    end

    def shutdown
    end

    def run
    end
  end
end
