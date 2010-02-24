#!/usr/bin/ruby
$KCODE = 'u'
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

$ITER = 50

require 'test/unit'
require 'test/unit/assertions'

class SAPChangingTest < Test::Unit::TestCase
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
	
	def test_BASIC_00010_Test_Changing
		begin 
		  $ITER.times do |iter|
	      assert(conn = SAPNW::Base.rfc_connect)
	      attrib = conn.connection_attributes
	      SAP_LOGGER.debug "Connection Attributes: #{attrib.inspect}\n"
		    fd = conn.discover("STFC_CHANGING")
	      SAP_LOGGER.debug "Parameters: #{fd.parameters.keys.inspect}\n"
        f = fd.new_function_call
			  f.START_VALUE = iter
			  f.COUNTER = iter
		    f.invoke
	      SAP_LOGGER.debug "RESULT: #{f.RESULT}\n"
	      SAP_LOGGER.debug "COUNTER: #{f.COUNTER}\n"
			  assert(f.RESULT == iter + iter)
			  assert(f.COUNTER == iter + 1)
		    assert(conn.close)
			  GC.start unless iter % 50
			end
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
	end
	
	def test_BASIC_00020_Test_Changing
		begin 
	      assert(conn = SAPNW::Base.rfc_connect)
	      attrib = conn.connection_attributes
	      SAP_LOGGER.debug "Connection Attributes: #{attrib.inspect}\n"
		    fd = conn.discover("STFC_CHANGING")
	      SAP_LOGGER.debug "Parameters: #{fd.parameters.keys.inspect}\n"
		    $ITER.times do |iter|
			    GC.start unless iter % 50
          f = fd.new_function_call
			    f.START_VALUE = iter
			    f.COUNTER = iter
		      f.invoke
	        SAP_LOGGER.debug "RESULT: #{f.RESULT}\n"
	        SAP_LOGGER.debug "COUNTER: #{f.COUNTER}\n"
			    assert(f.RESULT == iter + iter)
			    assert(f.COUNTER == iter + 1)
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
