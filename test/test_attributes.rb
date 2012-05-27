#!/usr/bin/ruby
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$SAP_CONFIG = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

require 'test/unit'
require 'test/unit/assertions'

class SAPConnectionAttributeTest < Test::Unit::TestCase
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
	
	def test_BASIC_00010_Connection_Attributes
	  assert(conn = SAPNW::Base.rfc_connect)
		attrib = conn.connection_attributes
		SAP_LOGGER.debug "Connection Attributes: #{attrib.inspect}\n"
		assert(attrib.length > 10)
		assert(attrib['sysId'].rstrip.length == 3)
		assert(attrib['progName'].strip == "SAPLSYST")
		assert(attrib['rfcRole'] == 'C')
		assert(conn.close)
	end
	
	def test_BASIC_00010_Connection_Attributes_Volume
	  50.times do
	    assert(conn = SAPNW::Base.rfc_connect)
		  attrib = conn.connection_attributes
		  SAP_LOGGER.debug "Connection Attributes: #{attrib.inspect}\n"
		  assert(attrib.length > 10)
		  assert(attrib['sysId'].rstrip.length == 3)
		  assert(attrib['progName'].strip == "SAPLSYST")
		  assert(attrib['rfcRole'] == 'C')
		  assert(conn.close)
		end
	end

	def teardown
	end
end
