require 'sinatra/base'
require 'active_record'
require 'active_support/core_ext/hash/keys'

require 'logger'
require 'pathname'
require 'yaml'
require 'erb'

module Sinatra
  module ActiveRecordHelper
    def database
      settings.database
    end
  end

  module ActiveRecordExtension
    def self.registered(app)
      app.set :database, ENV['DATABASE_URL'] if ENV['DATABASE_URL']
      app.set :database_file, "#{Dir.pwd}/config/database.yml" if File.exist?("#{Dir.pwd}/config/database.yml")
      ActiveRecord::Base.logger = Logger.new(STDOUT) unless defined?(Rake) || app.settings.production?

      app.helpers ActiveRecordHelper

      # re-connect if database connection dropped
      app.before { ActiveRecord::Base.verify_active_connections! if ActiveRecord::Base.respond_to?(:verify_active_connections!) }
      app.after  { ActiveRecord::Base.clear_active_connections! }
    end

    def database_file=(path)
      path = File.join(root, path) if Pathname(path).relative? and root
      spec = YAML.load(ERB.new(File.read(path)).result) || {}
      set :database, spec
    end

    def database=(spec)
      if spec.is_a?(Hash) and spec.symbolize_keys[environment.to_sym]
        ActiveRecord::Base.configurations = spec.stringify_keys
        ActiveRecord::Base.establish_connection(environment.to_sym)
      else
        ActiveRecord::Base.establish_connection(spec)
        ActiveRecord::Base.configurations = {
          environment.to_s => ActiveRecord::Base.connection.pool.spec.config
        }
      end
    end

    def database
      ActiveRecord::Base
    end
  end

  register ActiveRecordExtension
end
