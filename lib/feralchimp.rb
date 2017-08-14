require "feralchimp/version"
require "faraday"
require "json"

class Feralchimp
  class MailchimpError < StandardError
    def initialize(msg)
      super
    end
  end

  # --------------------------------------------------------------------------

  class KeyError < StandardError
    def initialize(msg)
      super
    end
  end

  # --------------------------------------------------------------------------

  @raise = false
  @exportar = false
  @api_key = nil
  @timeout = 5

  # --------------------------------------------------------------------------

  def initialize(opts = {})
    @raw_api_key = opts[:api_key] || self.class.api_key || ENV["MAILCHIMP_API_KEY"]
    @api_key = parse_mailchimp_key(
      @raw_api_key
    )
  end

  # --------------------------------------------------------------------------

  def method_missing(method, *args)
    if method == :export
      self.class.exportar = true
      raise ArgumentError, "#{args.count} for 0" if args.count > 0
      return self
    end

    raise_or_return send_to_mailchimp(
      method, *args
    )
  end

  # --------------------------------------------------------------------------

  protected
  def send_to_mailchimp(method, bananas = {}, export = self.class.exportar)
    path = api_path(mailchimp_method(method), export)
    self.class.exportar = false

    http = mailchimp_http(@api_key[:region], export)
    bananas = bananas.merge(:apikey => @api_key[:secret]).to_json
    http.post(path, bananas).body
  end

  # --------------------------------------------------------------------------

  protected
  def mailchimp_http(zone, export)
    Faraday.new(:url => api_url(zone)) do |h|
      h.headers[:content_type] = "application/json"
      h.response export ? :mailchimp_export : :mailchimp
      h.options[:open_timeout] = self.class.timeout
      h.options[:timeout] = self.class.timeout
      h.adapter Faraday.default_adapter
    end
  end

  # --------------------------------------------------------------------------

  protected
  def parse_mailchimp_key(api_key)
    api_key = api_key.to_s

    if !api_key || api_key.empty? || api_key !~ /[a-z0-9]+-[a-z]{2}\d{1}/
      raise KeyError, "Invalid key '#{api_key}.'"

    else
      api_key = api_key.to_s.split("-")

      {
        :region => api_key.last,
        :secret => api_key.first
      }
    end
  end

  # --------------------------------------------------------------------------

  protected
  def api_path(method, export = false)
    return "/export/1.0/#{method}/" if export
    "/2.0/#{method}.json"
  end

  # --------------------------------------------------------------------------

  protected
  def api_url(zone)
    URI.parse(
      "https://#{zone}.api.mailchimp.com"
    )
  end

  # --------------------------------------------------------------------------

  protected
  def raise_or_return(rtn)
    if rtn.is_a?(Hash) && rtn.key?("error")
      raise MailchimpError, rtn["error"]
    end

    rtn
  end

  # --------------------------------------------------------------------------

  protected
  def mailchimp_method(method)
    method = method.to_s.split("_")
    "#{method[0]}#{("/" + method[1..-1].join("-")) if method.count > 1}"
  end

  # --------------------------------------------------------------------------

  class << self
    attr_accessor :exportar, :timeout, :api_key
    def method_missing(method, *args)
      if method != :to_ary
        return new.send(
          method, *args
        )
      end

      super
    end
  end

  # --------------------------------------------------------------------------

  module Response
    class JSONParser < Faraday::Middleware
      def call(environment)
        @app.call(environment).on_complete do |e|
          e[:raw_body] = e[:body]
          e[:body] = ::JSON.parse("[" + e[:raw_body].to_s + "]").first
        end
      end
    end

    # ------------------------------------------------------------------------

    class JSONExport < Faraday::Middleware
      def call(environment)
        @app.call(environment).on_complete do |e|
          body = e[:body].each_line.to_a
          e[:raw_body] = e[:body]

          e[:body] = begin
            if JSON.parse(body.first).is_a?(Hash)
              body.map do |line|
                JSON.parse(
                  line
                )
              end
            else
              keys = JSON.parse(body.shift)
              body.inject([]) do |a, k|
                a.push(Hash[keys.zip(
                  JSON.parse(k)
                )])
              end
            end
          end
        end
      end
    end
  end
end

# ----------------------------------------------------------------------------

{ :mailchimp => :JSONParser, :mailchimp_export => :JSONExport }.each do |m, o|
  o = Feralchimp::Response.const_get(o)
  Faraday::Response.register_middleware m => proc { o }
end
