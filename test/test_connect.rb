#!/usr/bin/ruby
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

require 'test/unit'
require 'test/unit/assertions'

class SAPConnectTest < Test::Unit::TestCase
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
	
	def test_BASIC_00010_Basic_Connect
		conn = nil
		begin
	    assert(conn = SAPNW::Base.rfc_connect)
		  assert(conn.close)
	    #assert(conn = SAPNW::Base.rfc_connect(:user => 'developer', :passwd => 'developer'))
		  #assert(conn.close)
		rescue SAPNW::RFC::ConnectionException => e
		  SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
		end
		SAP_LOGGER.warn "end of test 1\n"
	end
	
	def test_BASIC_00015_Basic_Connect_Ping
		conn = nil
		begin
	    assert(conn = SAPNW::Base.rfc_connect)
        assert(conn.ping)
		assert(conn.close)
        assert(!conn.ping)
	    #assert(conn = SAPNW::Base.rfc_connect(:user => 'developer', :passwd => 'developer'))
		  #assert(conn.close)
		rescue SAPNW::RFC::ConnectionException => e
		  SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
		end
		SAP_LOGGER.warn "end of test 1\n"
	end
	
	def test_BASIC_00020_Connection_Out_Of_Scope
		5.times do
		  conn = nil
		  begin
	      assert(conn = SAPNW::Base.rfc_connect)
		  rescue SAPNW::RFC::ConnectionException => e
		    SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
		  end
		end
		GC.start
		SAP_LOGGER.warn "end of test 2\n"
	end
	
	def test_BASIC_00030_Volume_Connections
		50.times do
		  conn = nil
	    assert(conn = SAPNW::Base.rfc_connect)
		end
		GC.start
		SAP_LOGGER.warn "end of test 3.1\n"
		50.times do
		  conn = nil
	    assert(conn = SAPNW::Base.rfc_connect)
		end
		GC.start
		SAP_LOGGER.warn "end of test 3.2\n"
		50.times do
		  conn = nil
	    assert(conn = SAPNW::Base.rfc_connect)
		end
		GC.start
		SAP_LOGGER.warn "end of test 3.3\n"
		50.times do
		  conn = nil
	    assert(conn = SAPNW::Base.rfc_connect)
		end
		GC.start
		SAP_LOGGER.warn "end of test 3.4\n"
	end
	
	def test_BASIC_00040_Volume_Connections_With_Close
		99.times do
		  conn = nil
	    assert(conn = SAPNW::Base.rfc_connect)
		  assert(conn.close)
		end
		SAP_LOGGER.warn "end of test 4\n"
		GC.start
		sleep(5)
		GC.start
	end

	def teardown
	end
end
