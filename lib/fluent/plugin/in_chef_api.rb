#!/usr/bin/env ruby

module Fluent
  class ChefAPIInput < Input
    Plugin.register_input("chef_api", self)

    config_param :check_interval, :integer, :default => 60
    config_param :chef_server_url, :string, :default => nil
    config_param :client_key, :string, :default => nil
    config_param :config_file, :string, :default => "/etc/chef/client.rb"
    config_param :node_name, :string, :default => nil
    config_param :tag, :string, :default => "chef_api"
    config_param :chef_environment, :string, :default => nil

    def initialize
      super
      require "chef-api"
    end

    def configure(conf)
      super
    end

    def start
      @running = true
      @thread = ::Thread.new(&method(:run))
    end

    def shutdown
      @running = false
      @thread.join
    end

    def run
      connection = ChefAPI::Connection.new(
        :endpoint => @chef_server_url,
        :client   => @node_name,
        :key      => ::File.read(@client_key),
      )
      next_run = ::Time.new
      while @running
        if ::Time.new < next_run
          sleep(1)
        else
          begin
            run_once(connection)
          rescue => error
            $log.warn("failed to fetch metrics: #{error.class}: #{error.message}")
            next
          ensure
            next_run = ::Time.new + @check_interval
          end
        end
      end
    end

    def run_once(connection)
      if @chef_environment
        nodes = connection.environments.fetch(@chef_environment).nodes
        data = {"chef_environment" => @chef_environment}
      else
        nodes = connection.nodes
        data = {}
      end
      Engine.emit("#{@tag}.nodes", Engine.now, data.merge({"value" => nodes.count}))
      nodes.each do |node|
        begin
          Engine.emit("#{@tag}.run_list", Engine.now, data.merge({"value" => node.run_list.length, "node" => node.name}))
          ohai_time = node.automatic.fetch("ohai_time")
          Engine.emit("#{@tag}.ohai_time", Engine.now, data.merge({"value" => ohai_time, "node" => node.name}))
          Engine.emit("#{@tag}.behind_seconds", Engine.now, data.merge({"value" => Time.new.to_i - ohai_time, "node" => node.name}))
        rescue => error
          $log.warn("failed to fetch metrics from node: #{node.name}: #{error.class}: #{error.message}")
        end
      end
    end
  end
end
