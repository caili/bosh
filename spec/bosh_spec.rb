require File.join(File.dirname(__FILE__), 'spec_helper')

describe Bosh do
  
  describe :post do
    before(:each) do
      @endpoint = "http://localhost:5280/http-bind"
      @jid = "me@server.tld"
      @password = "secret"
      @bosh = Bosh.new(@jid, @password, @endpoint)
      @xml = "string"
    end
    
    it "should use Nokogiri to POST an HTTP request" do
      Typhoeus::Request.should_receive(:post).with(@endpoint, :body => @xml).and_return(mock(Typhoeus::Response, :body => "<cool />", :code => 200))
      @bosh.post(@xml)
    end
    
  end
  
  describe :send do
    before(:each) do
      @endpoint = "http://localhost:5280/http-bind"
      @jid = "me@server.tld"
      @password = "secret"
      @bosh = Bosh.new(@jid, @password, @endpoint)
      @bosh.stub!(:post).and_return("<cool />")
      @xml = Nokogiri::XML("<hello><world /></hello>")
    end
    
    context "when sid is nil" do
      it "should call :post with a string form of the param" do
        @bosh.should_receive(:post).with(@xml.root.to_xml).and_return("<cool />")
        @bosh.send(@xml)
      end
      
      it "should return the parsed document's root" do
        Nokogiri::XML::Document.stub!(:parse).with("<cool />").and_return(@xml)
        @bosh.send(@xml).should == @xml.root
      end
    end
    
    context "when sid is not nil (the session was already established)" do
      before(:each) do
        @bosh.sid = "sessionid"
      end
      
      it "should encapsulate the argument in a <body> element" do
        @bosh.should_receive(:post).with("<body xmlns=\"http://jabber.org/protocol/httpbind\" rid=\"#{@bosh.rid}\" sid=\"sessionid\">\n<hello><world/></hello></body>").and_return("<cool />")
        @bosh.send(@xml)
      end
      
      it "should return the parsed document's root's first child" do
        Nokogiri::XML::Document.stub!(:parse).with("<cool />").and_return(@xml)
        @bosh.send(@xml).should == @xml.root
      end
      
      it "should incremenet the rid" do
        rid = @bosh.rid
        @bosh.send(@xml)
        @bosh.rid.should == rid + 1
      end
      
    end
    
    it "should parse the result from :post" do
      Nokogiri::XML::Document.should_receive(:parse).with("<cool />").and_return(@xml)
      @bosh.send(@xml)
    end
    
    
  end
  
  describe :connect do
    before(:each) do
      @endpoint = "http://localhost:5280/http-bind"
      @jid = "me@server.tld"
      @password = "secret"
      @bosh = Bosh.new(@jid, @password, @endpoint)
      @bosh.stub!(:create_session)
      @bosh.stub!(:authentify).and_return(true)
      @bosh.stub!(:restart)
    end
    
    it "should call :create_session" do
      @bosh.should_receive(:create_session)
      @bosh.connect
    end
    
    it "should authentify" do
      @bosh.should_receive(:authentify).and_return(true)
      @bosh.connect
    end
    
    describe "when authentication was successful" do
      before(:each) do
        @bosh.stub!(:authentify).and_return(true)
      end
      
      it "should restart the connection" do
        @bosh.should_receive(:restart)
        @bosh.connect
      end
    end
    
    it "should return self" do
      @bosh.connect.should == @bosh
    end
    
  end
  
  describe :create_session do
    before(:each) do
      @endpoint = "http://localhost:5280/http-bind"
      @jid = "me@server.tld"
      @password = "secret"
      @bosh = Bosh.new(@jid, @password, @endpoint)
      @response = {
       "sid" => "sessionid",
       "wait" => "wait",
       "polling" => "polling",
       "inactivity" => "inactivity",
       "requests" => "requests",
       "hold" => "hold"
      }
      @bosh.stub!(:send).and_return(@response)
    end
    
    it "should send a document that contains the session information" do
      @bosh.should_receive(:send).and_return(@response)
      @bosh.create_session
    end
    
    it "should extract sid from the response" do
      @bosh.create_session
      @bosh.sid.should == @response["sid"]
    end
    
    it "should extract wait from the response" do
      @bosh.create_session
      @bosh.wait.should == @response["wait"]
    end 
    
    it "should extract polling from the response" do
      @bosh.create_session
      @bosh.polling.should == @response["polling"]
    end
    
    it "should extract inactivity from the response" do
      @bosh.create_session
      @bosh.inactivity.should == @response["inactivity"]
    end
    
    it "should extract requests from the response" do
      @bosh.create_session
      @bosh.requests.should == @response["requests"]
    end
    
    it "should extract hold from the response" do
      @bosh.create_session
      @bosh.hold.should == @response["hold"]
    end
    
  end
  
  describe :authentify do
  end
  
  describe :bind_ressource do
  end
  
  describe :request_session do
  end
  
end
