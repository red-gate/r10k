require 'r10k/module_repository'
require 'r10k/version'
require 'r10k/logging'
require 'r10k/errors'

require 'faraday'
require 'faraday_middleware/multi_json'
require 'faraday_middleware'

class R10K::ModuleRepository::Forge

  include R10K::Logging

  # @!attribute [r] forge
  #   @return [String] The forge hostname to use for requests
  attr_reader :forge

  # @!attribute [r] :conn
  #   @api private
  #   @return [Faraday]
  attr_reader :conn

  def initialize(forge = 'forgeapi.puppetlabs.com')
    if forge =~ /forge\.puppetlabs\.com/
      logger.warn("#{forge} does not support the latest puppet forge API. Please update to \"forge 'https://forgeapi.puppetlabs.com'\"")
      forge = 'forgeapi.puppetlabs.com'
    end
    @forge = forge
    @conn  = make_conn
  end

  # Query for all published versions of a module
  #
  # @example
  #   forge = R10K::ModuleRepository::Forge.new
  #   forge.versions('adrien/boolean')
  #   #=> ["0.9.0-rc1", "0.9.0", "1.0.0", "1.0.1"]
  #
  # @param module_name [String] The fully qualified module name
  # @return [Array<String>] All published versions of the given module
  def versions(module_name)
    path = "/v3/modules/#{module_name.tr('/','-')}"
    response = @conn.get(path)

    if response.status != 200
      raise R10K::Error.new("Request to Puppet Forge '#{path}' failed. Status: #{response.status}")
    end

    releases = response.body['releases'].reject { |r| r['deleted_at'] }
    releases = releases.map do |version_info|
      version_info['version']
    end
    releases.reverse
  end

  # Query for the newest published version of a module
  #
  # @example
  #   forge = R10K::ModuleRepository::Forge.new
  #   forge.latest_version('adrien/boolean')
  #   #=> "1.0.1"
  #
  # @param module_name [String] The fully qualified module name
  # @return [String] The latest published version of the given module
  def latest_version(module_name)
    versions(module_name).last
  end

  private

  def make_conn
    Faraday.new(:url => "https://#{@forge}") do |builder|
      builder.request(:multi_json)
      builder.response(:multi_json)

      # This needs to be _after_ request/response configuration for testing
      # purposes. Without this ordering the tests get badly mangled.
      builder.adapter(Faraday.default_adapter)
    end
  end
end
