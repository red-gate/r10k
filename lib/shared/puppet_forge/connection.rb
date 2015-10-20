require 'shared/puppet_forge/version'
require 'shared/puppet_forge/connection/connection_failure'

require 'faraday'
require 'faraday_middleware'
require 'openssl'

module PuppetForge
  # Provide a common mixin for adding a HTTP connection to classes.
  #
  # This module provides a common method for creating HTTP connections as well
  # as reusing a single connection object between multiple classes. Including
  # classes can invoke #conn to get a reasonably configured HTTP connection.
  # Connection objects can be passed with the #conn= method.
  #
  # @example
  #   class HTTPThing
  #     include PuppetForge::Connection
  #   end
  #   thing = HTTPThing.new
  #   thing.conn = thing.make_connection('https://non-standard-forge.site')
  #
  # @api private
  module Connection

    attr_writer :conn

    USER_AGENT = "PuppetForge/#{PuppetForge::VERSION} Faraday/#{Faraday::VERSION} Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})"

    def self.authorization=(token)
      @authorization = token
    end

    def self.authorization
      @authorization
    end

    # @return [Faraday::Connection] An existing Faraday connection if one was
    #   already set, otherwise a new Faraday connection.
    def conn
      @conn ||= make_connection('https://forgeapi.puppetlabs.com')
    end

    # Generate a new Faraday connection for the given URL.
    #
    # @param url [String] the base URL for this connection
    # @return [Faraday::Connection]
    def make_connection(url, adapter_args = nil)
      adapter_args ||= [Faraday.default_adapter]
      options = { :headers => { :user_agent => USER_AGENT }}

      if token = PuppetForge::Connection.authorization
        options[:headers][:authorization] = token
      end

      builder = Faraday::RackBuilder.new do |b|
        b.response(:json, :content_type => /\bjson$/)
        b.response(:raise_error)
        b.adapter(*adapter_args)
      end

      options[:builder] = builder

      if url.match(/^https/)
        conn = make_https_connection(url, options)
      else
        conn = make_http_connection(url, options)
      end

      conn
    end

    def make_http_connection(url, options)
      Faraday.new(url, options)
    end

    def make_https_connection(url, options)
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      add_rubygems_trusted_certs(cert_store)

      Faraday.new(url, options.merge(:ssl => {:cert_store => cert_store}))
    end

    def add_rubygems_trusted_certs(store)
      pattern = File.expand_path("./ssl_certs/*.pem", File.dirname(__FILE__))
      Dir.glob(pattern).each do |ssl_cert_file|
      store.add_file ssl_cert_file
    end
  end
  end
end
