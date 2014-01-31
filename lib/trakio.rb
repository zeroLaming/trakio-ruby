require "trakio/version"
require "rest_client"
require "json"


class Trakio

  class Exceptions
    class UnInitiated < RuntimeError; end
    class InvalidToken < RuntimeError; end
    class NoDistinctIdForDefaultInstance < RuntimeError; end
  end

  class << self

    def init(*args)
      api_token, params = args
      raise Trakio::Exceptions::InvalidToken.new('Missing API Token') unless api_token
      if params and params.has_key?(:distinct_id)
        raise Trakio::Exceptions::NoDistinctIdForDefaultInstance
      end
      @default_instance = Trakio.new(*args)
    end

    def default_instance
      if @default_instance
        @default_instance
      else
        raise Trakio::Exceptions::UnInitiated
      end
    end

    def default_instance=(instance)
      @default_instance = instance
    end

    def distinct_id
      raise Trakio::Exceptions::NoDistinctIdForDefaultInstance
    end

    def distinct_id=(distinct_id)
      raise Trakio::Exceptions::NoDistinctIdForDefaultInstance
    end

    def method_missing(method, *args, &block)
      # passes to the default_instance so that
      # Trakio.channel returns Trakio.default_instance.channel
      @default_instance.send(method, *args, &block)
    end

  end

  attr_accessor :api_token

  # the following are set via params
  attr_accessor :https
  attr_accessor :host
  attr_accessor :channel # channel is some form of category
  attr_accessor :distinct_id

  def initialize(*args)
    api_token, params = args
    api_token = Trakio.default_instance.api_token unless api_token

    @api_token = api_token or raise Trakio::Exceptions::InvalidToken.new('Missing API Token')
    @https = true
    @host = 'api.trak.io/v1'

    %w{https host channel distinct_id}.each do |name|
      if params && params.has_key?(name.to_sym)
        instance_variable_set("@#{name}", params[name.to_sym])
      end
    end
  end

  def track(parameters)
    parameters.default = nil

    distinct_id = parameters[:distinct_id]
    distinct_id = @distinct_id unless distinct_id
    raise "No distinct_id specified" unless distinct_id

    event = parameters[:event] or raise "No event specified"

    channel = parameters[:channel]
    channel = @channel unless channel

    properties = parameters[:properties]

    params = {
      distinct_id: distinct_id,
      event: event,
    }
    params[:channel] = channel if channel
    params[:properties] = properties if properties

    send_request('track', params)
  end

  def identify(parameters)
    parameters.default = nil

    distinct_id = parameters[:distinct_id]
    distinct_id = @distinct_id unless distinct_id
    raise "No distinct_id specified" unless distinct_id

    properties = parameters[:properties]
    raise "Properties must be specified" unless properties and properties.length > 0

    params = {
      distinct_id: distinct_id,
      properties: properties,
    }
    send_request('identify', params)
  end

  def alias(parameters)
    parameters.default = nil

    distinct_id = parameters[:distinct_id]
    distinct_id = @distinct_id unless distinct_id
    raise "No distinct_id specified" unless distinct_id

    alias_ = parameters[:alias]
    raise "No alias specified" unless alias_
    raise "alias must be string or array" unless alias_.is_a?(String) or alias_.is_a?(Array)

    params = {
      distinct_id: distinct_id,
      alias: alias_,
    }
    send_request('alias', params)
  end

  def annotate(parameters)
    parameters.default = nil

    event = parameters[:event]
    raise "No event specified" unless event

    properties = parameters[:properties]
    properties = {} unless properties

    channel = parameters[:channel]
    channel = @channel unless channel

    params = {
      event: event,
    }
    params[:channel] = channel if channel
    params[:properties] = properties if properties
    send_request('annotate', params)
  end

  def send_request(endpoint, params)
    protocol = @https ? "https" : "http"
    url = "#{protocol}://#{@host}/#{endpoint}"
    data = { token: @api_token, data: params }.to_json
    resp = RestClient.post url, data, :content_type => :json, :accept => :json
    JSON.parse(resp.body, :symbolize_names => true)
  end

end
