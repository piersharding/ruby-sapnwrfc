#!/usr/bin/ruby
$KCODE = 'u'
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'
$WAIT = 10

	  #SAP_LOGGER.warn "Current DIR: #{Dir.pwd}\n"
	  if FileTest.exists?($TEST_FILE)
  	  SAPNW::Base.config_location = $TEST_FILE
		else
  	  SAPNW::Base.config_location = 'test/' + $TEST_FILE
		end
	  SAPNW::Base.load_config
    #SAP_LOGGER.warn "program: #{$0}\n"

		begin 
	    func = SAPNW::RFC::FunctionDescriptor.new("MY_TEST")
		  func.addParameter(SAPNW::RFC::Import.new(:name => "HELLO", :len => 80, :type => SAPNW::RFC::CHAR))
		  func.addParameter(SAPNW::RFC::Export.new(:name => "COMMAND", :len => 80, :type => SAPNW::RFC::CHAR))
		  $stderr.print "Built up FunctionDescriptor: #{func.inspect}/#{func.parameters.inspect}\n"
			pass = 0
	    func.callback = Proc.new do |fc|
		        $stderr.print "#{fc.name} got called with #{fc.COMMAND}\n"
                fc.HELLO = "Blah"
				true
		  end
		  $stderr.print "Register...\n"
	    server = SAPNW::Base.rfc_register
	    attrib = server.connection_attributes
	    SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
		  $stderr.print "Install...\n"
	    server.installFunction(func)
	    globalCallBack = Proc.new do |attrib|
	  	  $stderr.print "global got called: #{attrib.inspect}\n"
				if pass < 150
	  		  true
				else
				  # will tell the accept() loop to exit
				  false
				end
	  	end
		  $stderr.print "Accept...\n"
	  	server.accept($WAIT, globalCallBack)
	  rescue SAPNW::RFC::ServerException => e
	    SAP_LOGGER.warn "ServerException ERROR: #{e.inspect} - #{e.error.inspect}\n"
	  rescue SAPNW::RFC::FunctionCallException => e
	    SAP_LOGGER.warn "FunctionCallException ERROR: #{e.inspect} - #{e.error.inspect}\n"
	  rescue SAPNW::RFC::ConnectionException => e
	    SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
	  end
