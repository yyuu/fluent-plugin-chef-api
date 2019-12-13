require 'fluent/plugin/input'

module Fluent
  class ChefAPIInput < Fluent::Plugin::Input
    Plugin.register_input("chef_api", self)

    helpers :thread

    config_param :check_interval, :integer, :default => 60
    config_param :chef_server_url, :string, :default => nil
    config_param :client_key, :string, :default => nil
    config_param :config_file, :string, :default => "/etc/chef/client.rb"
    config_param :node_name, :string, :default => nil
    config_param :tag, :string, :default => "chef_api"
    config_param :chef_environment, :string, :default => nil
    config_param :default_values, :hash, :default => {}
    config_param :monitor_multi, :bool, :default => true

    def initialize
      super
      require "chef-api"
    end

    class ChefConfig
      def self.load_file(file)
        new(file).instance_eval { @config.dup }
      end

      def initialize(file)
        @config = {}
        instance_eval(::File.read(file))
      end

      def chef_server_url(value)
        @config[:endpoint] = value
      end

      def node_name(value)
        @config[:client] = value
      end

      def client_key(value)
        @config[:key] = ::File.read(value)
      end

      def ssl_verify_mode(value)
        @config[:ssl_verify] = value != :verify_none
      end

      def method_missing(*args)
        # nop
      end
    end

    def configure(conf)
      super
      @config = {}
      if @config_file
        @config = @config.merge(ChefConfig.load_file(@config_file))
      end
      if @chef_server_url
        @config[:endpoint] = @chef_server_url
      end
      if @node_name
        @config[:client] = value
      end
      if @client_key
        @config[:key] = ::File.read(@client_key)
      end
    end

    def start
      thread_create(:chef_api, &method(:run))
    end

    def run
      connection = ChefAPI::Connection.new(@config.dup)
      next_run = ::Time.new
      while thread_current_running?
        if ::Time.new < next_run
          sleep(1)
        else
          begin
            if @monitor_multi
              run_once(connection)
            else
              run_once_single(connection)
            end
          rescue => error
            $log.warn("failed to fetch metrics: #{error.class}: #{error.message}")
            next
          ensure
            next_run = ::Time.new + @check_interval
          end
        end
      end
    end

    def run_once_single(connection)
      data = @default_values.dup
      if node = connection.nodes.fetch(connection.client)
        emit_node_metrics(node, data)
      end
    end

    def run_once(connection)
      data = @default_values.dup
      if @chef_environment
        nodes = connection.environments.fetch(@chef_environment).nodes
      else
        nodes = connection.nodes
      end
      router.emit("#{@tag}.nodes", Engine.now, data.merge({"value" => nodes.count}))
      begin
        nodes.instance_eval do
          if Hash === @collection
            @collection = Hash[@collection.to_a.shuffle]
          end
        end
      rescue => error
        $log.warn("failed to shuffle nodes: #{error.class}: #{error.message}")
      end
      nodes.each do |node|
        emit_node_metrics(node, data)
      end
    end

    def emit_node_metrics(node, data)
      begin
        router.emit("#{@tag}.run_list", Engine.now, data.merge({"value" => node.run_list.length, "node" => node.name}))
        if node.automatic["ohai_time"]
          ohai_time = node.automatic["ohai_time"].to_i
          router.emit("#{@tag}.ohai_time", Engine.now, data.merge({"value" => ohai_time, "node" => node.name}))
          router.emit("#{@tag}.behind_seconds", Engine.now, data.merge({"value" => Time.new.to_i - ohai_time, "node" => node.name}))
        end
      rescue => error
        $log.warn("failed to fetch metrics from node: #{node.name}: #{error.class}: #{error.message}")
      end
    end
  end
end
