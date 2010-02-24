
  #
  #
  # = SAPNWRFC - SAP Netweaver RFC support for Ruby 
	#
	# Welcome to sapnwrfc !
	#
	# sapnwrfc is an RFC based connector to SAP specifically designed for use with the
	# next generation RFC SDK supplied by SAP for NW2004+ .
	#
	# = Download and Documentation
	#
	# Documentation at: http://www.piersharding.com/download/ruby/sapnwrfc/doc/
	#
	# Project and Download at: http://raa.ruby-lang.org/project/sapnwrfc
	#
	# = Functionality
	#
	# The next generation RFCSDK from SAP provides a number of interesting new features.  The two most 
	# important are:
	# * UNICODE support
	# * deep/nested structures
	#
	# The UNICODE support is built fundamentally into the core of the new SDK, and as a result this is reflected in 
	# sapnwrfc.  sapnwrfc takes UTF-8 as its only input character set, and handles the translation of this to UTF-16
	# as required by the RFCSDK.
	#
	# Deep and complex structures are now supported fully.  Please see the test_deep.rb example in tests/ for
	# an idea as to how it works.
	#
	# sapnwrfc is a departure to the way the original saprfc (http://raa.ruby-lang.org/project/saprfc) works.
	# It aims to simplify the exchange of native Ruby data types between the user application and the 
	# connector.  This means that the following general rules should be observered, when passing values 
	# to and from RFC interface parameters and tables:
	#
	# * Tables expect Arrays of Hashes.
	# * Parameters with structures expect Hashes
	# * CHAR, DATE, TIME, STRING, XSTRING, and BYTE type parameters expect String values.
	# * all numeric parameter values must be Fixnum, Bignum or Float.
	#
	#
	# = Building and Installation
	#
  # After you have unpacked your kit, you should have all the files listed in the MANIFEST.
  #
  # In brief, the following should work on most systems: ruby setup.rb 
  #
  # if your rfcsdk is not findable in the system search path, then use the command line switches
  # for mkmf/setup.rb like so:
  #   ruby setup.rb config  --with-nwrfcsdk-dir=/path/to/rfcsdk
  #   ruby setup.rb setup
  #   ruby setup.rb install
	#
	# You must otain the latest RFCSDK for Netweaver from SAP - this <b>MUST</b> be the next 
	# generation SDK, if you are to have any chance of succeeding.
	#  
	#  
	# = WIN32 Support
	#
  # When Olivier (or anyone else offering) supplies prebuilt GEM files, I make them available
  # on http://www.piersharding.com/download/ruby/sapnwrfc/ .
  #
	#
	# = Support
	#
	# For both community based, and professional support, I can be contacted at Piers Harding <piers@ompka.net>.
	#
	# = Examples
	#
	# Please see the examples (test/*.rb) distributed with this packages (download source for this) for
	# a comprehensive shake-down on what you can do.
	#
	# Here is a taster using the standard Flight demo BAPIs supplied by SAP:
	#
  #  require 'sapnwrfc'
  #  
  #  TEST_FILE = 'ubuntu.yml'
  # 
	#  # specify the YAML config source and load
  #  SAPNW::Base.config_location = TEST_FILE
  #  SAPNW::Base.load_config
	#
	#  # Connec to SAP
  #  conn = SAPNW::Base.rfc_connect
	#
	#  # Inspect the connection attributes
  #  attrib = conn.connection_attributes
  #  $stderr.print "Connection Attributes: #{attrib.inspect}\n"
	#
	#  # pull in your RFC definitions
  #  fld = conn.discover("BAPI_FLIGHT_GETLIST")
  #  flgd = conn.discover("BAPI_FLIGHT_GETDETAIL")
  #  fd = conn.discover("BAPI_FLBOOKING_CREATEFROMDATA")
	#
	#  # get a new handle for each function call to be invoked
  #  fl = fld.new_function_call
	#
	#  # set the parameters for the call
  #  fl.AIRLINE = "AA "
	#
	#  # ivoke the call
  #  fl.invoke
	#
	#  # interogate the results
  #  fl.FLIGHT_LIST.each do |row|
  #  	  $stderr.print "row: #{row.inspect}\n"
	#
	#  	  # for each flight now do another RFC call to get the details
  #     flg = flgd.new_function_call
  #  	  flg.AIRLINEID = row['AIRLINEID']
  #  	  flg.CONNECTIONID = row['CONNECTID']
  #  	  flg.FLIGHTDATE = row['FLIGHTDATE']
  #  	  flg.invoke
  #  	  $stderr.print "\tflight data: #{flg.FLIGHT_DATA.inspect}\n"
  #  	  $stderr.print "\tadditional info: #{flg.ADDITIONAL_INFO.inspect}\n"
  #  	  $stderr.print "\tavailability: #{flg.AVAILIBILITY.inspect}\n"
  #  end
	#
	#  # create a new booking 
  #  fd.name == "BAPI_FLBOOKING_CREATEFROMDATA"
  #  f = fd.new_function_call
  #  f.BOOKING_DATA = { 'AIRLINEID' => "AA ", 'CONNECTID' => "0001", 'FLIGHTDATE' => "20070130",
  #                     'CLASS' => "F", 'CUSTOMERID' => "00000001", 'AGENCYNUM' => '00000093' }
	#
	#  # trap Function Call exceptions
  #  begin
  #    f.invoke
  #  rescue SAPNW::RFC::FunctionCallException => e
  #    $stderr.print "FunctionCallException: #{e.error.inspect}\n"
  #    raise "gone"
  #  end
  #  f.RETURN.each do |row|
  #    $stderr.print "row: #{row.inspect}\n"
  #  end
	#
	#  # use the standard COMMIT BAPI to commit the update
  #  cd = conn.discover("BAPI_TRANSACTION_COMMIT")
  #  c = cd.new_function_call
  #  c.WAIT = "X"
  #  c.invoke
	#
	#  # close the RFC connection and destroy associated resources
  #  conn.close
	#  
  #
	#
	# = A Closer Look At Handling Parameters
	#
	# Complex parameter types map naturally to Ruby data types.
  # Parameters that require structures are represented by a Hash of field/value pairs eg:
  #  f.BOOKING_DATA = { 'AIRLINEID' => "AA ", 'CONNECTID' => "0001", 'FLIGHTDATE' => "20070130",
  #                     'CLASS' => "F", 'CUSTOMERID' => "00000001", 'AGENCYNUM' => '00000093' }
  # Parameters that require tables are represented by an Array of Hashes of field/value pairs eg:
  #  ft.IMPORT_TAB = [{ 'I' => 123, 'C' => 'AbCdEf',
  #                     'STR' =>  'The quick brown fox ...',
  #                     'XSTR' => ["deadbeef"].pack("H*") }]
  #
	#
	# = Building your RFC Call
  #
  # When building a call for client-side RFC, you should always be inspecting the requirements 
  # of the RFC call by using transaction SE37 first.  You should also be in the the habit of 
  # testing out your RFC calls first using SE37 too.  YOu would be amazed how much this simple 
  # approach will save you (and me) time.
  #
  #
	#  
	# = Thanks to:
	#  
	# * Olivier Boudry - an Open Source guy
	# * Craig Cmehil   - SAP, and SDN 
	# * Ulrich Schmidt - SAP
	# For their help in making this possible.
	#  
	#  
	#  
  #
  # Author::   Piers Harding <piers@ompka.net>
  # License::  Copyright (c) 2006-2008 Piers Harding. sapnwrfc is free software, and may be redistributed under the terms specified in the README file of the Ruby distribution.
  # Requires:: Ruby 1.8.0 or later
  #


$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'yaml'
require 'fileutils'
require 'logger'

# setup defaults for logging
SAP_LOGGER = Logger.new(STDERR)
SAP_LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S"
SAP_LOGGER.level = Logger::WARN

require 'sapnwrfc/base'

# C extension
begin
  require 'nwsaprfc'
rescue LoadError => e
  SAP_LOGGER.error("Could not load nwsaprfc. Make sure nwrfcsdk libraries are properly installed: #{e.message}")
  raise e
end

require 'sapnwrfc/config'
require 'sapnwrfc/connection'
require 'sapnwrfc/server'
require 'sapnwrfc/functions'
require 'sapnwrfc/parameters'

SAPNW::Base.class_eval do
  include SAPNW::Config
  include SAPNW::Connections
  include SAPNW::Servers
  include SAPNW::Functions
  include SAPNW::Parameters
end

