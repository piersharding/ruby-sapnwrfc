#!/usr/bin/ruby
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$ITER = 50
$TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

require 'test/unit'
require 'test/unit/assertions'

class SAPFunctionsTest < Test::Unit::TestCase
	def setup
	  #SAP_LOGGER.warn "Current DIR: #{Dir.pwd}\n"
	  if FileTest.exists?($TEST_FILE)
  	  SAPNW::Base.config_location = $TEST_FILE
		else
  	  SAPNW::Base.config_location = 'test/' + $TEST_FILE
		end
	  SAPNW::Base.load_config
    #SAP_LOGGER.warn "program: #{$0}\n"
	end
	
	def test_BASIC_00010_Function_LookUp
	  $ITER.to_i.times do
			begin 
	      assert(conn = SAPNW::Base.rfc_connect)
		    attrib = conn.connection_attributes
		    #SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
		    fd = conn.discover("RFC_READ_TABLE")
		    assert(fd.name == "RFC_READ_TABLE")
        f = fd.new_function_call
			  #SAP_LOGGER.warn "FunctionDescriptor: #{fd.inspect}\n"
			  #SAP_LOGGER.warn "FunctionDescriptor parameters: #{fd.parameters.inspect}\n"
		    assert(fd.parameters.has_key?("QUERY_TABLE"))
		    assert(f.name == "RFC_READ_TABLE")
			  #SAP_LOGGER.warn "FunctionCall: #{f.inspect}\n"
		    assert(conn.close)
			rescue SAPNW::RFC::ConnectionException => e
			  SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
			end
		end
	  GC.start
	end
	
	def test_BASIC_00020_Function_LookUp_Volume
	  $ITER.to_i.times do
	    assert(conn = SAPNW::Base.rfc_connect)
	    ["STFC_CHANGING", "STFC_XSTRING", "RFC_READ_TABLE", "RFC_READ_REPORT", "RPY_PROGRAM_READ", "RFC_PING", "RFC_SYSTEM_INFO"].each do |f|
		    fd = conn.discover(f)
		    assert(fd.name == f)
				#SAP_LOGGER.warn "FunctionDescriptor: #{fd.inspect}\n"
			  #SAP_LOGGER.warn "FunctionDescriptor parameters: #{fd.parameters.inspect}\n"
        c = fd.new_function_call
		    #SAP_LOGGER.warn "Function Name: #{c.name}\n"
		    assert(c.name == f)
	  	end
	  	GC.start
		end
	end

	def teardown
	end
end
