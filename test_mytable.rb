#!/usr/bin/ruby
$KCODE = 'u'
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

$ITER = 100

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
	    assert(conn = SAPNW::Base.rfc_connect)
	    attrib = conn.connection_attributes
	    SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
		  fds = conn.discover("Z_MY_RFC_HARD")
		  $ITER.times do |iter|
	      SAP_LOGGER.warn "Parameters: #{fds.parameters.keys.inspect}\n"
        fs = fds.new_function_call
				fs.IMPORT_ELEMENT = { 'OTYPE' => "AA", 'FIRST' => "The first desc", 'CAPABILITIES' => 
				[ 
				{ 'OBJID' => "1", 'TEXT' => "The short text1" },
				{ 'OBJID' => "2", 'TEXT' => "The short text2" },
				{ 'OBJID' => "3", 'TEXT' => "The short text3" }
				]
				}
		    fs.invoke
	      SAP_LOGGER.warn "EXPORT_ELEMENT: #{fs.EXPORT_ELEMENT.inspect}\n"
			  GC.start unless iter % 50
			end
		  assert(conn.close)
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
	end
	
	def teardown
	end
end
