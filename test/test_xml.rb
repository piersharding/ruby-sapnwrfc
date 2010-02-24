#!/usr/bin/ruby
$KCODE = 'u'
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

$ITER = 1

require 'test/unit'
require 'test/unit/assertions'

class SAPDeepTest < Test::Unit::TestCase
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
	
	def test_BASIC_00010_Test_Deep
		begin 
		  $ITER.times do |iter|
	      assert(conn = SAPNW::Base.rfc_connect)
	      attrib = conn.connection_attributes
	      SAP_LOGGER.debug "Connection Attributes: #{attrib.inspect}\n"
		    fds = conn.discover("RFC_XML_TEST_1")
	      SAP_LOGGER.debug "Parameters: #{fds.parameters.keys.inspect}\n"
        fs = fds.new_function_call
			  #fs.IM_XML_TABLE = [{ 'RFCIXMLLIN' => ["deadbeef"].pack("H*") } ]
		    #fs.invoke
	      SAP_LOGGER.debug "OUT_XML_TABLE: #{fs.OUT_XML_TABLE.inspect}\n"
		    assert(conn.close)
			  GC.start unless iter % 50
			end
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
	end
	
	def teardown
	end
end
