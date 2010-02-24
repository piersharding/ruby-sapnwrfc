#!/usr/bin/ruby
$KCODE = 'u'

require 'rubygems'
require_gem 'sapnwrfc'

ITER = 5
INNER = 5
TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'

require 'test/unit'
require 'test/unit/assertions'

class SAPDataTest < Test::Unit::TestCase
	def setup
	  #SAP_LOGGER.warn "Current DIR: #{Dir.pwd}\n"
	  if FileTest.exists?(TEST_FILE)
  	  SAPNW::Base.config_location = TEST_FILE
		else
  	  SAPNW::Base.config_location = 'test/' + TEST_FILE
		end
	  SAPNW::Base.load_config
    #SAP_LOGGER.warn "program: #{$0}\n"
	end
	
	def test_BASIC_00010_Test_Data
	  ITER.to_i.times do |iter|
			begin 
	      assert(conn = SAPNW::Base.rfc_connect)
		    attrib = conn.connection_attributes
		    #SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
		    fd = conn.discover("Z_TEST_DATA")
		    assert(fd.name == "Z_TEST_DATA")
        f = fd.new_function_call
		    assert(f.name == "Z_TEST_DATA")
        f.CHAR = "German: öäüÖÄÜß"
        f.INT1 = 123
        f.INT2 = 1234
        f.INT4 = 123456
        f.FLOAT = 123456.00
        f.NUMC = '12345'
        f.DATE = '20060709'
        f.TIME = '200607'
        f.BCD = 200607.123
        f.ISTRUCT = { 'ZCHAR' => "German: öäüÖÄÜß", 'ZINT1' => 54, 'ZINT2' => 134, 'ZIT4' => 123456, 'ZFLT' => 123456.00, 'ZNUMC' => '12345', 'ZDATE' => '20060709', 'ZTIME' => '200607', 'ZBCD' => '200607.123' }
        f.DATA = [{ 'ZCHAR' => "German: öäüÖÄÜß", 'ZINT1' => 54, 'ZINT2' => 134, 'ZIT4' => 123456, 'ZFLT' => 123456.00, 'ZNUMC' => '12345', 'ZDATE' => '20060709', 'ZTIME' => '200607', 'ZBCD' => '200607.123' }]
			  #SAP_LOGGER.warn "FunctionCall: #{f.inspect}\n"
			  #SAP_LOGGER.warn "FunctionCall PROGRAM_NAME: #{f.PROGRAM_NAME.value}/#{f.parameters['PROGRAM_NAME'].type}\n"
				begin
				  f.invoke
				rescue SAPNW::RFC::FunctionCallException => e
				  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
				  raise "gone"
				end
				f.RESULT.each do |row|
				  SAP_LOGGER.warn "row: #{row.inspect}\n"
				end
				f.DATA.each do |row|
				  SAP_LOGGER.warn "row: #{row.inspect}\n"
				end

        SAP_LOGGER.warn "ECHAR: #{f.ECHAR}\n"
        SAP_LOGGER.warn "EINT1: #{f.EINT1}\n"
        SAP_LOGGER.warn "EINT2: #{f.EINT2}\n"
        SAP_LOGGER.warn "EINT4: #{f.EINT4}\n"
        SAP_LOGGER.warn "EFLOAT: #{f.EFLOAT}\n"
        SAP_LOGGER.warn "ENUMC: #{f.ENUMC}\n"
        SAP_LOGGER.warn "EDATE: #{f.EDATE}\n"
        SAP_LOGGER.warn "ETIME: #{f.ETIME}\n"
        SAP_LOGGER.warn "EBCD: #{f.EBCD}\n"

        SAP_LOGGER.warn "ESTRUCT: #{f.ESTRUCT.inspect}\n"
		    #assert(conn.close)
			rescue SAPNW::RFC::ConnectionException => e
			  SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
			end
			GC.start unless iter % 50
		end
	  GC.start
	end
	
	def test_BASIC_00020_Test_Data
		begin 
		  ITER.times do |cnt|
  	    assert(conn = SAPNW::Base.rfc_connect)
  	    attrib = conn.connection_attributes
  	    #SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
  	    fd = conn.discover("Z_TEST_DATA")
  	    assert(fd.name == "Z_TEST_DATA")
	      INNER.to_i.times do |iter|
				  SAP_LOGGER.warn "Start of iteration: #{cnt}/#{iter}\n"
          f = fd.new_function_call
		      assert(f.name == "Z_TEST_DATA")
          f.CHAR = "German: öäüÖÄÜß"
          f.INT1 = 123
          f.INT2 = 1234
          f.INT4 = 123456
          f.FLOAT = 123456.00
          f.NUMC = '12345'
          f.DATE = '20060709'
          f.TIME = '200607'
          f.BCD = 200607.123
          f.ISTRUCT = { 'ZCHAR' => "German: öäüÖÄÜß", 'ZINT1' => 54, 'ZINT2' => 134, 'ZIT4' => 123456, 'ZFLT' => 123456.00, 'ZNUMC' => '12345', 'ZDATE' => '20060709', 'ZTIME' => '200607', 'ZBCD' => '200607.123' }
          f.DATA = [
	  			{ 'ZCHAR' => "German: öäüÖÄÜß", 'ZINT1' => 54, 'ZINT2' => 134, 'ZIT4' => 123456, 'ZFLT' => 123456.00, 'ZNUMC' => '12345', 'ZDATE' => '20060709', 'ZTIME' => '200607', 'ZBCD' => '200607.123' },
	  			{ 'ZCHAR' => "German: öäüÖÄÜß", 'ZINT1' => 54, 'ZINT2' => 134, 'ZIT4' => 123456, 'ZFLT' => 123456.00, 'ZNUMC' => '12345', 'ZDATE' => '20060709', 'ZTIME' => '200607', 'ZBCD' => '200607.123' },
	  			{ 'ZCHAR' => "German: öäüÖÄÜß", 'ZINT1' => 54, 'ZINT2' => 134, 'ZIT4' => 123456, 'ZFLT' => 123456.00, 'ZNUMC' => '12345', 'ZDATE' => '20060709', 'ZTIME' => '200607', 'ZBCD' => '200607.123' },
	  			{ 'ZCHAR' => "German: öäüÖÄÜß", 'ZINT1' => 54, 'ZINT2' => 134, 'ZIT4' => 123456, 'ZFLT' => 123456.00, 'ZNUMC' => '12345', 'ZDATE' => '20060709', 'ZTIME' => '200607', 'ZBCD' => '200607.123' },
	  			{ 'ZCHAR' => "German: öäüÖÄÜß", 'ZINT1' => 54, 'ZINT2' => 134, 'ZIT4' => 123456, 'ZFLT' => 123456.00, 'ZNUMC' => '12345', 'ZDATE' => '20060709', 'ZTIME' => '200607', 'ZBCD' => '200607.123' }
	  			]
	  		  #SAP_LOGGER.warn "FunctionCall: #{f.inspect}\n"
	  		  #SAP_LOGGER.warn "FunctionCall PROGRAM_NAME: #{f.PROGRAM_NAME.value}/#{f.parameters['PROGRAM_NAME'].type}\n"
	  			begin
	  			  f.invoke
	  			rescue SAPNW::RFC::FunctionCallException => e
	  			  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
	  			  raise "gone"
	  			end
	  			f.RESULT.each do |row|
	  			  #SAP_LOGGER.warn "row: #{row.inspect}\n"
	  			end
	  			f.DATA.each do |row|
	  			  #SAP_LOGGER.warn "row: #{row.inspect}\n"
	  			end

          #SAP_LOGGER.warn "ECHAR: #{f.ECHAR}\n"
          #SAP_LOGGER.warn "EINT1: #{f.EINT1}\n"
          #SAP_LOGGER.warn "EINT2: #{f.EINT2}\n"
          #SAP_LOGGER.warn "EINT4: #{f.EINT4}\n"
          #SAP_LOGGER.warn "EFLOAT: #{f.EFLOAT}\n"
          #SAP_LOGGER.warn "ENUMC: #{f.ENUMC}\n"
          #SAP_LOGGER.warn "EDATE: #{f.EDATE}\n"
          #SAP_LOGGER.warn "ETIME: #{f.ETIME}\n"
          #SAP_LOGGER.warn "EBCD: #{f.EBCD}\n"
  
          #SAP_LOGGER.warn "ESTRUCT: #{f.ESTRUCT.inspect}\n"
  			  GC.start unless iter % 10
  	  	end
	  	  assert(conn.close)
	      GC.start
			end
		rescue SAPNW::RFC::ConnectionException => e
		  SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
		end
	  GC.start
	end

	def teardown
	end
end
