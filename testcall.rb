#!/usr/bin/ruby
require 'rubygems'
require_gem 'sapnwrfc'
require 'sapnwrfc'

$ITER = 1
$TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

require 'test/unit'
require 'test/unit/assertions'

class SAPCallTest < Test::Unit::TestCase
	def setup
	  SAP_LOGGER.warn "Current DIR: #{Dir.pwd}\n"
	end
	
	def test_BASIC_00010_Program_Read
	  $ITER.to_i.times do
			begin 
	      assert(conn = SAPNW::Base.rfc_connect(:ashost => '86.111.163.145',
				                                      :sysnr => '01',
																							:user => 'developer',
																							:passwd => 'developer',
																							:client => '001',
																							:lang => 'EN',
																							:trace => 1) )
		    attrib = conn.connection_attributes
		    SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
		    fd = conn.discover("RPY_PROGRAM_READ")
		    assert(fd.name == "RPY_PROGRAM_READ")
        f = fd.new_function_call
		    assert(fd.parameters.has_key?("PROGRAM_NAME"))
		    assert(f.parameters.has_key?("PROGRAM_NAME"))
		    assert(f.name == "RPY_PROGRAM_READ")
				f.PROGRAM_NAME = 'SAPLGRFC'
			  SAP_LOGGER.warn "FunctionCall: #{f.inspect}"
			  SAP_LOGGER.warn "FunctionCall PROGRAM_NAME: #{f.PROGRAM_NAME}/#{f.parameters['PROGRAM_NAME'].type}"
				assert(f.PROGRAM_NAME == 'SAPLGRFC')
				begin
				  f.invoke
				rescue SAPNW::RFC::FunctionCallException => e
				  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
				  raise "gone"
				end
				SAP_LOGGER.warn "#{f.PROG_INF.has_key?('PROG')}"
				SAP_LOGGER.warn "#{f.PROG_INF.inspect}"
				f.PROG_INF.each_pair do |k, v|
				  SAP_LOGGER.warn "#{k} => #{v}"
				end
				SAP_LOGGER.warn "PROGNAME: #{f.PROG_INF['PROGNAME'].rstrip}#"
				assert(f.PROG_INF['PROGNAME'].rstrip == "SAPLGRFC")
				assert(f.SOURCE_EXTENDED.length > 10)
				f.SOURCE_EXTENDED.each do |row|
				  SAP_LOGGER.warn "Line: #{row['LINE']}"
				end
		    assert(conn.close)
			rescue SAPNW::RFC::ConnectionException => e
			  SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
			end
		end
	  GC.start
	end

	def teardown
	end
end
