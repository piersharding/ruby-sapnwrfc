#!/usr/bin/ruby
$KCODE = 'u'
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$SAP_CONFIG = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'


require 'test/unit'
require 'test/unit/assertions'

class StfcConnectionTest < Test::Unit::TestCase
	def setup
	  #SAP_LOGGER.warn "Current DIR: #{Dir.pwd}\n"
	  if FileTest.exists?($SAP_CONFIG)
  	  SAPNW::Base.config_location = $SAP_CONFIG
		else
  	  SAPNW::Base.config_location = 'test/' + $SAP_CONFIG
		end
	  SAPNW::Base.load_config
    #SAP_LOGGER.warn "program: #{$0}\n"
	end
	
	def test_BASIC_00010_Test_Stfc_Connection
		begin 
	    assert(conn = SAPNW::Base.rfc_connect)
	    attrib = conn.connection_attributes
	    SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
		  fds = conn.discover("STFC_CONNECTION")
      fs = fds.new_function_call
			fs.REQUTEXT = "Some Text"
		  fs.invoke
	    SAP_LOGGER.warn "RESPTEXT: #{fs.RESPTEXT}\n"
	    SAP_LOGGER.warn "ECHOTEXT: #{fs.ECHOTEXT}\n"
		  assert(conn.close)
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
	end
	
	def teardown
	end
end
