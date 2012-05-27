#!/usr/bin/ruby
$KCODE = 'u'
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$SAP_CONFIG = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

$ITER = 50

require 'test/unit'
require 'test/unit/assertions'

class SAPDeepTest < Test::Unit::TestCase
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
	
	def test_BASIC_00010_Test_Structure
		begin 
		  $ITER.times do |iter|
	      assert(conn = SAPNW::Base.rfc_connect)
	      attrib = conn.connection_attributes
	      SAP_LOGGER.debug "Connection Attributes: #{attrib.inspect}\n"
		    fds = conn.discover("STFC_STRUCTURE")
	      SAP_LOGGER.debug "Parameters: #{fds.parameters.keys.inspect}\n"
        fs = fds.new_function_call
			  fs.IMPORTSTRUCT = { 'RFCDATA1' =>  'The quick brown fox ...' }
		    fs.invoke
	      SAP_LOGGER.debug "RESPTEXT: #{fs.RESPTEXT.inspect}\n"
	      SAP_LOGGER.debug "ECHOSTRUCT: #{fs.ECHOSTRUCT.inspect}\n"
			  assert(fs.ECHOSTRUCT['RFCDATA1'] == 'The quick brown fox ...')
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
