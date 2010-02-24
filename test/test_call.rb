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

class SAPCallTest < Test::Unit::TestCase
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
	
	def test_BASIC_00010_Program_Read
	  $ITER.to_i.times do
			begin 
	      assert(conn = SAPNW::Base.rfc_connect)
		    attrib = conn.connection_attributes
		    #SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
		    fd = conn.discover("RPY_PROGRAM_READ")
		    assert(fd.name == "RPY_PROGRAM_READ")
        f = fd.new_function_call
		    assert(fd.parameters.has_key?("PROGRAM_NAME"))
		    assert(f.parameters.has_key?("PROGRAM_NAME"))
		    assert(f.name == "RPY_PROGRAM_READ")
				f.PROGRAM_NAME = 'SAPLGRFC'
			  #SAP_LOGGER.warn "FunctionCall: #{f.inspect}\n"
			  #SAP_LOGGER.warn "FunctionCall PROGRAM_NAME: #{f.PROGRAM_NAME}/#{f.parameters['PROGRAM_NAME'].type}\n"
				assert(f.PROGRAM_NAME == 'SAPLGRFC')
				begin
				  f.invoke
				rescue SAPNW::RFC::FunctionCallException => e
				  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
				  raise "gone"
				end
				#SAP_LOGGER.warn "#{f.PROG_INF.has_key?('PROG')}\n"
				#SAP_LOGGER.warn "#{f.PROG_INF.inspect}\n"
				#f.PROG_INF.each_pair do |k, v|
				#  SAP_LOGGER.warn "#{k} => #{v}\n"
				#end
				#SAP_LOGGER.warn "PROGNAME: #{f.PROG_INF['PROGNAME'].rstrip}#\n"
				assert(f.PROG_INF['PROGNAME'].rstrip == "SAPLGRFC")
				assert(f.SOURCE_EXTENDED.length > 10)
				#f.SOURCE_EXTENDED.each do |row|
				#  SAP_LOGGER.warn "Line: #{row['LINE']}\n"
				#end
		    assert(conn.close)
			rescue SAPNW::RFC::ConnectionException => e
			  SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
			end
		end
	  GC.start
	end


	def test_BASIC_00020_Program_Read_Volume
	  assert(conn = SAPNW::Base.rfc_connect)
		attrib = conn.connection_attributes
		fd = conn.discover("RPY_PROGRAM_READ")
		assert(fd.name == "RPY_PROGRAM_READ")
	  $ITER.to_i.times do |iter|
      f = fd.new_function_call
		  assert(fd.parameters.has_key?("PROGRAM_NAME"))
		  assert(f.parameters.has_key?("PROGRAM_NAME"))
		  assert(f.name == "RPY_PROGRAM_READ")
			f.PROGRAM_NAME = 'SAPLGRFC'
			assert(f.PROGRAM_NAME == 'SAPLGRFC')
			begin
			  f.invoke
			rescue SAPNW::RFC::FunctionCallException => e
			  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
			  raise "gone"
			end
			assert(f.PROG_INF['PROGNAME'].rstrip == "SAPLGRFC")
			assert(f.SOURCE_EXTENDED.length > 10)
	    GC.start unless iter % 50
		end
		assert(conn.close)
	  GC.start
	end


	def test_BASIC_00030_Read_table
	  assert(conn = SAPNW::Base.rfc_connect)
		attrib = conn.connection_attributes
		fd = conn.discover("RFC_READ_TABLE")
		assert(fd.name == "RFC_READ_TABLE")
	  $ITER.to_i.times do |iter|
      f = fd.new_function_call
		  assert(fd.parameters.has_key?("QUERY_TABLE"))
		  assert(f.parameters.has_key?("QUERY_TABLE"))
		  assert(f.name == "RFC_READ_TABLE")
			f.QUERY_TABLE = 'T000'
			f.DELIMITER = '|'
			f.ROWCOUNT = 2
			assert(f.QUERY_TABLE == 'T000')
			begin
			  f.invoke
			rescue SAPNW::RFC::FunctionCallException => e
			  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
			  raise "gone"
			end
			assert(f.DATA.length > 1)
			#f.DATA.each do |row|
			#  SAP_LOGGER.warn "Line: #{row.inspect}\n"
			#end
	    GC.start unless iter % 50
		end
		assert(conn.close)
	  GC.start
	end

	def teardown
	end
end
