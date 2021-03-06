require 'middleman-core'

# Load extension nonetheless, as child apps may/will require this file.
require 'middleman/apps/extension'

# Register this extension with the name of `apps`
Middleman::Extensions.register :apps, Middleman::Apps::Extension

# Namespace for the Middleman project
module Middleman
  # Base namespace for `middleman-apps` extension.
  #
  module Apps
    # Environment in which MM should be run
    ENVIRONMENT = (ENV['MM_ENV'] || ENV['RACK_ENV'] || 'development').to_sym

    # Middleman options that would be passed to create a reference instance.
    MIDDLEMAN_OPTIONS = {
      mode: :config,
      watcher_disable: true,
      exit_before_ready: true,
      environment: ENVIRONMENT
    }.freeze

    # Middleman app instance for reference to configuration, etc.
    #
    # @return [Middleman::Application] an instance of Middleman::Application
    #   using configuration in {MIDDLEMAN_OPTIONS}
    #
    def self.middleman_app
      Middleman.setup_load_paths
      ::Middleman::Application.new do
        MIDDLEMAN_OPTIONS.each do |key, val|
          config[key] = val
        end
      end
    end

    # Evaluate some code within the context of this extension.
    #
    # @param [Proc] block block to be executed
    # @return [Any] - result of execution of the provided block
    #
    # @see .rack_app `.rack_app` method which uses this internally
    #
    def self.with_app_list(app = nil, &block)
      app ||= middleman_app
      options = app.extensions[:apps].options.to_h
      ex = Middleman::Apps::Extension.new(app, options)
      app.sitemap.register_resource_list_manipulator(:child_apps, ex.collection)
      app.sitemap.ensure_resource_list_updated!
      block ? ex.collection.instance_eval(&block) : ex.collection
    end

    # Rack app comprising of the static (middleman) app with 404 pages, and
    # child apps properly mounted.
    #
    # This method can be used directly to create a Rack app. Refer to the
    # generated `config.ru` for an example.
    #
    # @return [Rack::App] rack application configuration
    def self.rack_app
      with_app_list { mount_child_apps(middleman_static_app) }
    end

    # Find App Resource for the given class name
    #
    # @param [Class] klass - klass to search
    # @return [Middleman::Sitemap::AppResource, nil] - found app resource if any
    def self.find_app_resource_for(klass, app = nil)
      Middleman::Sitemap::AppResource.find_by_klass(klass, app)
    end

    # Get content for the not found page as specified in options.
    #
    def self.not_found(rack_app = nil)
      rack_app ||= middleman_app
      path = with_app_list(rack_app) do
        build_dir.join(find_resource(@options.not_found))
      end
      path.exist? ? path.read : "Not found\n"
    end
  end
end
