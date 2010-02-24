#!/usr/bin/ruby
$KCODE = 'u'
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

require 'test/unit'
require 'test/unit/assertions'

class SAPSFlightTest < Test::Unit::TestCase
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
	
	def test_BASIC_00010_Test_Data
	  assert(conn = SAPNW::Base.rfc_connect)
	  attrib = conn.connection_attributes
	  #SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
		fld = conn.discover("BAPI_FLIGHT_GETLIST")
		flgd = conn.discover("BAPI_FLIGHT_GETDETAIL")
    fl = fld.new_function_call
		fl.AIRLINE = "AA "
		fl.invoke
		fl.FLIGHT_LIST.each do |row|
		  SAP_LOGGER.debug "row: #{row.inspect}\n"
      flg = flgd.new_function_call
		  flg.AIRLINEID = row['AIRLINEID']
		  flg.CONNECTIONID = row['CONNECTID']
		  flg.FLIGHTDATE = row['FLIGHTDATE']
		  flg.invoke
		  SAP_LOGGER.debug "\tflight data: #{flg.FLIGHT_DATA.inspect}\n"
		  SAP_LOGGER.debug "\tadditional info: #{flg.ADDITIONAL_INFO.inspect}\n"
		  SAP_LOGGER.debug "\tavailability: #{flg.AVAILIBILITY.inspect}\n"
		end
		fd = conn.discover("BAPI_FLBOOKING_CREATEFROMDATA")
		assert(fd.name == "BAPI_FLBOOKING_CREATEFROMDATA")
    f = fd.new_function_call
		assert(f.name == "BAPI_FLBOOKING_CREATEFROMDATA")
    f.BOOKING_DATA = { 'AIRLINEID' => "AA ", 'CONNECTID' => "0001", 'FLIGHTDATE' => "20070130", 'CLASS' => "F", 'CUSTOMERID' => "00000001", 'AGENCYNUM' => '00000093' }
		begin
		  f.invoke
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
		f.RETURN.each do |row|
		  SAP_LOGGER.debug "row: #{row.inspect}\n"
		end
		SAP_LOGGER.debug "PRICE: #{f.TICKET_PRICE.inspect}\n"
		cd = conn.discover("BAPI_TRANSACTION_COMMIT")
    c = cd.new_function_call
		c.WAIT = "X"
		c.invoke
		assert(conn.close)
	end

	def teardown
	end
end
