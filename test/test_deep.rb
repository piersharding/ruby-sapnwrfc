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
		    fds = conn.discover("STFC_DEEP_STRUCTURE")
	      SAP_LOGGER.debug "Parameters: #{fds.parameters.keys.inspect}\n"
        fs = fds.new_function_call
			  fs.IMPORTSTRUCT = { 'I' => 123, 'C' => 'AbCdEf', 'STR' =>  'The quick brown fox ...', 'XSTR' => ["deadbeef"].pack("H*") }
		    fs.invoke
	      SAP_LOGGER.debug "RESPTEXT: #{fs.RESPTEXT.inspect}\n"
	      SAP_LOGGER.debug "ECHOSTRUCT: #{fs.ECHOSTRUCT.inspect}\n"
			  assert(fs.ECHOSTRUCT['I'] == 123)
			  assert(fs.ECHOSTRUCT['C'].rstrip == 'AbCdEf')
			  assert(fs.ECHOSTRUCT['STR'] == 'The quick brown fox ...')
			  assert(fs.ECHOSTRUCT['XSTR'].unpack("H*").first == 'deadbeef')
		    fdt = conn.discover("STFC_DEEP_TABLE")
	      SAP_LOGGER.debug "Parameters: #{fdt.parameters.keys.inspect}\n"
        ft = fdt.new_function_call
			  ft.IMPORT_TAB = [{ 'I' => 123, 'C' => 'AbCdEf', 'STR' =>  'The quick brown fox ...', 'XSTR' => ["deadbeef"].pack("H*") }]
		    ft.invoke
	      SAP_LOGGER.debug "RESPTEXT: #{ft.RESPTEXT.inspect}\n"
	      SAP_LOGGER.debug "EXPORT_TAB: #{ft.EXPORT_TAB.inspect}\n"
			  assert(ft.EXPORT_TAB[0]['I'] == 123)
			  assert(ft.EXPORT_TAB[0]['C'].rstrip == "AbCdEf")
			  assert(ft.EXPORT_TAB[0]['STR'] == 'The quick brown fox ...')
			  assert(ft.EXPORT_TAB[1]['C'].rstrip == "Appended")
	      ft.EXPORT_TAB.each do |row|
	        SAP_LOGGER.debug "XSTR: #{row['XSTR'].unpack("H*")}#\n"
			    assert(row['XSTR'].unpack("H*").first == 'deadbeef')
			  end
		    assert(conn.close)
			  GC.start unless iter % 50
			end
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
	end
	
	def test_BASIC_00020_Test_Deep
		begin 
	      assert(conn = SAPNW::Base.rfc_connect)
	      attrib = conn.connection_attributes
	      SAP_LOGGER.debug "Connection Attributes: #{attrib.inspect}\n"
		    fds = conn.discover("STFC_DEEP_STRUCTURE")
	      SAP_LOGGER.debug "Parameters: #{fds.parameters.keys.inspect}\n"
		    fdt = conn.discover("STFC_DEEP_TABLE")
	      SAP_LOGGER.debug "Parameters: #{fdt.parameters.keys.inspect}\n"
		    $ITER.times do |iter|
			    GC.start unless iter % 50
          fs = fds.new_function_call
			    fs.IMPORTSTRUCT = { 'I' => 123, 'C' => 'AbCdEf', 'STR' =>  'The quick brown fox ...', 'XSTR' => ["deadbeef"].pack("H*") }
		      fs.invoke
	        SAP_LOGGER.debug "RESPTEXT: #{fs.RESPTEXT.inspect}\n"
	        SAP_LOGGER.debug "ECHOSTRUCT: #{fs.ECHOSTRUCT.inspect}\n"
			    assert(fs.ECHOSTRUCT['I'] == 123)
			    assert(fs.ECHOSTRUCT['C'].rstrip == 'AbCdEf')
			    assert(fs.ECHOSTRUCT['STR'] == 'The quick brown fox ...')
			    assert(fs.ECHOSTRUCT['XSTR'].unpack("H*").first == 'deadbeef')
          ft = fdt.new_function_call
			    ft.IMPORT_TAB = [{ 'I' => 123, 'C' => 'AbCdEf', 'STR' =>  'The quick brown fox ...', 'XSTR' => ["deadbeef"].pack("H*") }]
		      ft.invoke
	        SAP_LOGGER.debug "RESPTEXT: #{ft.RESPTEXT.inspect}\n"
	        SAP_LOGGER.debug "EXPORT_TAB: #{ft.EXPORT_TAB.inspect}\n"
			    assert(ft.EXPORT_TAB[0]['I'] == 123)
			    assert(ft.EXPORT_TAB[0]['C'].rstrip == "AbCdEf")
			    assert(ft.EXPORT_TAB[0]['STR'] == 'The quick brown fox ...')
	        ft.EXPORT_TAB.each do |row|
	          SAP_LOGGER.debug "XSTR: #{row['XSTR'].unpack("H*")}#\n"
			      assert(row['XSTR'].unpack("H*").first == 'deadbeef')
			    end
			  end
		    assert(conn.close)
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
	end
	
	def test_BASIC_00030_Test_Deep
		begin 
	    assert(conn = SAPNW::Base.rfc_connect)
	    attrib = conn.connection_attributes
	    SAP_LOGGER.debug "Connection Attributes: #{attrib.inspect}\n"
	    fdt = conn.discover("STFC_DEEP_TABLE")
	    SAP_LOGGER.debug "Parameters: #{fdt.parameters.keys.inspect}\n"
      ft = fdt.new_function_call
		  ft.IMPORT_TAB = [{ 'I' => 123, 'C' => 'AbCdEf', 'STR' =>  'The quick brown fox ...', 'XSTR' => ["deadbeef"].pack("H*") }]
	    ft.invoke
	    SAP_LOGGER.debug "RESPTEXT: #{ft.RESPTEXT.inspect}\n"
	    SAP_LOGGER.debug "EXPORT_TAB: #{ft.EXPORT_TAB.inspect}\n"
		  assert(ft.EXPORT_TAB[0]['I'] == 123)
		  assert(ft.EXPORT_TAB[0]['C'].rstrip == "AbCdEf")
		  assert(ft.EXPORT_TAB[0]['STR'] == 'The quick brown fox ...')
		  assert(ft.EXPORT_TAB[1]['C'].rstrip == "Appended")
	    ft.EXPORT_TAB.each do |row|
	      SAP_LOGGER.debug "XSTR: #{row['XSTR'].unpack("H*")}#\n"
		    assert(row['XSTR'].unpack("H*").first == 'deadbeef')
		  end
	    assert(conn.close)
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
	end

	def test_BASIC_00040_Test_Deep
		begin 
	    assert(conn = SAPNW::Base.rfc_connect)
	    attrib = conn.connection_attributes
	    SAP_LOGGER.debug "Connection Attributes: #{attrib.inspect}\n"
		  fds = conn.discover("STFC_DEEP_STRUCTURE")
	    SAP_LOGGER.debug "Parameters: #{fds.parameters.keys.inspect}\n"
      fs = fds.new_function_call
		  fs.IMPORTSTRUCT = { 'I' => 123, 'C' => 'AbCdEf', 'STR' =>  'The quick brown fox ...', 'XSTR' => ["deadbeef"].pack("H*") }
		  fs.invoke
	    SAP_LOGGER.debug "RESPTEXT: #{fs.RESPTEXT.inspect}\n"
	    SAP_LOGGER.debug "ECHOSTRUCT: #{fs.ECHOSTRUCT.inspect}\n"
		  assert(fs.ECHOSTRUCT['I'] == 123)
		  assert(fs.ECHOSTRUCT['C'].rstrip == 'AbCdEf')
		  assert(fs.ECHOSTRUCT['STR'] == 'The quick brown fox ...')
		  assert(fs.ECHOSTRUCT['XSTR'].unpack("H*").first == 'deadbeef')
		  assert(conn.close)
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
	end

	def teardown
	end
end
