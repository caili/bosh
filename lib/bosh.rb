require 'nokogiri'
require 'typhoeus'
require 'base64'

class Bosh  
  class Error < StandardError; end
  class AuthenticationNotsupported < Bosh::Error; end
  class AuthenticationError < Bosh::Error; end

  attr_accessor :jid, :rid, :sid, :wait, :polling, :hold, :window, :inactivity, :requests
  
  @@logger = nil
  
  def self.logger(&block)
    @@logger = block
    @@logger.call("Logging on")
  end
  
  def self.log(message)
    @@logger.call(message) if @@logger
  end
  
  def self.connect(jid, password, endpoint, options = {})
    Bosh.new(jid, password, endpoint, options).connect
  end
  
  def host
    @host ||= @jid.split("@").last
  end
  
  def initialize(jid, password, endpoint, options = {}) 
    @jid, @password, @endpoint = jid, password, endpoint
    @success = false
    @headers = {"Content-Type" => "text/xml; charset=utf-8", "Accept" => "text/xml"}
    @wait    = options[:wait]   || 60
    @hold    = options[:hold]   || 1
    @window  = options[:window] || 10
    @rid     = options[:rid]    || rand(1000000)
  end
  
  ##
  # Performs the connection
  # After this, the connection is ready to be used. You can safely extract the jid, sid and rid.
  def connect
    create_session
    authentified = authentify
    restart if authentified
    self
  end
  
  ##
  # When authentified, the needs to restart the connection.
  def restart
    restart = <<-EOXML
      <body rid='#{@rid}'
            sid='#{@sid}'
            to='jabber.org'
            xml:lang='en'
            xmpp:restart='true'
            xmlns='http://jabber.org/protocol/httpbind'
            xmlns:xmpp='urn:xmpp:xbosh'/>
    EOXML
    @sid = nil
    session = send(Nokogiri::XML::Document.parse(restart))
    @sid = session["sid"]
    @wait = session["wait"]
    @polling = session["polling"]
    @inactivity = session["inactivity"]
    @requests = session["requests"]
    @hold = session["hold"]
    @rid += 1
    if !session.xpath("./stream:features/bind:bind", {"stream" => "http://etherx.jabber.org/streams", "bind" => "urn:ietf:params:xml:ns:xmpp-bind"}).empty?
      bind_ressource
    end
    if !session.xpath("./stream:features/session:session", {"stream" => "http://etherx.jabber.org/streams", "session" => "urn:ietf:params:xml:ns:xmpp-session"})
      # Create session?
    end
  end
  
  ##
  # Sends the resource binding stanza
  # Updates the @jid to reflect the resource.
  def bind_ressource
    bind = <<-EOXML
      <iq id='bind_#{rand(1000)}'
            type='set'
            xmlns='jabber:client'>
          <bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>
            <resource>bosh_#{rand(1000)}</resource>
          </bind>
        </iq>
    EOXML
    result = send(Nokogiri::XML::Document.parse(bind))
    @jid = result.at_xpath("./bind:bind/bind:jid", {"bind" => "urn:ietf:params:xml:ns:xmpp-bind"}).text
    true
  end
  
  ##
  # Sends the necessary stanzas to authentify a user.
  # This is not part of the regular Bosh protocol, but also one of the most common uses of Bosh, so we include it here :)
  def authentify
    auth = <<-EOXML
      <auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>
    EOXML
    result = send(Nokogiri::XML::Document.parse(auth))
    if methods = result.xpath("./sasl:mechanisms/sasl:mechanism", "sasl" => "urn:ietf:params:xml:ns:xmpp-sasl").map(&:text) and methods.include?("PLAIN")
      challenge = <<-EOXML
        <auth mechanism="PLAIN" xmlns="urn:ietf:params:xml:ns:xmpp-sasl">#{Base64::encode64([@jid, @jid.split("@").first, @password].join("\000")).gsub(/\s/, '')}</auth>
      EOXML
      result = send(Nokogiri::XML::Document.parse(challenge))
      if result.name == "success"
        true
      elsif result.name == "failure"
        raise AuthenticationError, "Authentication failed : #{result.children.first.name}"
      else
        raise Error, "Got unexpected response : #{result.to_xml}"
      end
    else
      raise AuthenticationNotsupported, methods.empty? ? "No Authentication Method Supported" : "Supported : #{methods.join}"
    end
  end
  
  ##
  # Asks the Bosh Server for a session. 
  # http://xmpp.org/extensions/xep-0124.html#session-request
  def create_session
    xml = <<-EOXML
    <body content='text/xml; charset=utf-8'
          wait='#{@wait}'
          hold='#{@hold}'
          rid='#{@rid}'
          to='#{host}'
          window="10" 
          xmlns:xmpp="urn:xmpp:xbosh" 
          xmpp:version="1.0"
          xmlns='http://jabber.org/protocol/httpbind'/>
    EOXML
    body = Nokogiri::XML::Document.parse(xml)
    session = send(body)
    @sid = session["sid"]
    @wait = session["wait"]
    @polling = session["polling"]
    @inactivity = session["inactivity"]
    @requests = session["requests"]
    @hold = session["hold"]
  end
  
  ##
  # Posts the XML Document and parses the ansnwer. Returns a Nokogiri Document
  # If the session was established, it encapsulate the right <body> element
  def send(xml)
    if !@sid
      response = Nokogiri::XML::Document.parse(post(xml.root.to_xml)).root
    else
      body = <<-EOXML
        <body rid='#{@rid}'
              sid='#{@sid}'
              xmlns='http://jabber.org/protocol/httpbind'>
      EOXML
      doc = Nokogiri::XML::Document.parse(body)
      doc.root.add_child(xml.root) if xml.root
      response = Nokogiri::XML::Document.parse(post(doc.root.to_xml)).root.children.first
      @rid += 1
    end
    response
  end
  
  ##
  # Performs an HTTP POST with the string param as body and returns the body of the response.
  def post(string)
    Bosh.log("\nSENDING : \n" + string)
    response = Typhoeus::Request.post(@endpoint, :body => string)
    Bosh.log("\nRECEIVED (#{response.code}): \n" + response.body)
    response.body
  end
end

