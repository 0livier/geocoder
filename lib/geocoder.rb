require "geocoder/configuration"
require "geocoder/calculations"
require "geocoder/cache"
require "geocoder/request"
require "geocoder/models/active_record"
require "geocoder/models/mongoid"

module Geocoder
  extend self

  ##
  # Search for information about an address or a set of coordinates.
  #
  def search(query, *args)
    # convert coordinates as separate arguments to an array
    if query.is_a?(Numeric) and args.first.is_a?(Numeric)
      warn "DEPRECATION WARNING: Instead of passing latitude/longitude as separate arguments to the search method, please pass an array: [#{query},#{args.first}]. The old argument format will not be supported in Geocoder v.1.0."
      query = [query, args.first]
    end
    if blank_query?(query)
      results = []
    else
      results = lookup(query).search(query)
    end
    results.instance_eval do
      def warn_search_deprecation(attr)
        warn "DEPRECATION WARNING: Geocoder.search now returns an array of Geocoder::Result objects. " +
          "Calling '%s' directly on the returned array will cause an exception in Geocoder v1.0." % attr
      end

      def coordinates; warn_search_deprecation('coordinates'); first.coordinates if first; end
      def latitude; warn_search_deprecation('latitude'); first.latitude if first; end
      def longitude; warn_search_deprecation('longitude'); first.longitude if first; end
      def address; warn_search_deprecation('address'); first.address if first; end
      def city; warn_search_deprecation('city'); first.city if first; end
      def country; warn_search_deprecation('country'); first.country if first; end
      def country_code; warn_search_deprecation('country_code'); first.country_code if first; end
    end
    return results
  end

  ##
  # Look up the coordinates of the given street or IP address.
  #
  def coordinates(address)
    if (results = search(address)).size > 0
      results.first.coordinates
    end
  end

  ##
  # Look up the address of the given coordinates ([lat,lon])
  # or IP address (string).
  #
  def address(query, *args)
    if lon = args.first
      warn "DEPRECATION WARNING: Instead of passing latitude/longitude as separate arguments to the address method, please pass an array: [#{query},#{args.first}]. The old argument format will not be supported in Geocoder v.1.0."
      query = [query, lon]
    end
    if (results = search(query)).size > 0
      results.first.address
    end
  end

  ##
  # The working Cache object, or +nil+ if none configured.
  #
  def cache
    if @cache.nil? and store = Configuration.cache
      @cache = Cache.new(store, Configuration.cache_prefix)
    end
    @cache
  end

  ##
  # Array of valid Lookup names.
  #
  def valid_lookups
    street_lookups + ip_lookups
  end

  ##
  # All street address lookups, default first.
  #
  def street_lookups
    [:google, :yahoo, :bing, :geocoder_ca, :yandex]
  end

  ##
  # All IP address lookups, default first.
  #
  def ip_lookups
    [:freegeoip]
  end

  def version
    File.read(File.join(File.dirname(__FILE__), "..", "VERSION")).chomp
  end


  # exception classes
  class Error < StandardError; end
  class ConfigurationError < Error; end


  private # -----------------------------------------------------------------

  ##
  # Get a Lookup object (which communicates with the remote geocoding API).
  # Takes a search query and returns an IP or street address Lookup
  # depending on the query contents.
  #
  def lookup(query)
    if ip_address?(query)
      get_lookup(ip_lookups.first)
    else
      get_lookup(Configuration.lookup || street_lookups.first)
    end
  end

  ##
  # Retrieve a Lookup object from the store.
  #
  def get_lookup(name)
    unless defined?(@lookups)
      @lookups = {}
    end
    unless @lookups.include?(name)
      @lookups[name] = spawn_lookup(name)
    end
    @lookups[name]
  end

  ##
  # Spawn a Lookup of the given name.
  #
  def spawn_lookup(name)
    if valid_lookups.include?(name)
      name = name.to_s
      require "geocoder/lookups/#{name}"
      klass = name.split("_").map{ |i| i[0...1].upcase + i[1..-1] }.join
      eval("Geocoder::Lookup::#{klass}.new")
    else
      valids = valid_lookups.map{ |l| ":#{l}" }.join(", ")
      raise ConfigurationError, "Please specify a valid lookup for Geocoder " +
        "(#{name.inspect} is not one of: #{valids})."
    end
  end

  ##
  # Does the given value look like an IP address?
  #
  # Does not check for actual validity, just the appearance of four
  # dot-delimited 8-bit numbers.
  #
  def ip_address?(value)
    !!value.to_s.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/)
  end

  ##
  # Is the given search query blank? (ie, should we not bother searching?)
  #
  def blank_query?(value)
    !!value.to_s.match(/^\s*$/)
  end
end

# load Railtie if Rails exists
if defined?(Rails)
  require "geocoder/railtie"
  Geocoder::Railtie.insert
end
