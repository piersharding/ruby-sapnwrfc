$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$TEST_FILE = 'test/alternate_sap.yml'

require 'test/unit'
require 'test/unit/assertions'

class SAPConfigTest < Test::Unit::TestCase

	
	def setup
	  FileUtils.cp('./test/sap.yml', 'sap.yml')
	  SAPNW::Base.load_config
    #SAP_LOGGER.warn "program: #{$0}\n"
	end
	
	def test_BASIC_00010_Config_Loaded
		assert( SAPNW::Base.config.length >= 5 )
		assert( SAPNW::Base.config['ashost'].length > 3)
		assert( SAPNW::Base.config['sysnr'].length == 2 )
		assert( SAPNW::Base.config['client'].length == 3 )
		assert( SAPNW::Base.config['user'].length >= 2 )
	end
	
	def test_BASIC_00020_Alternate_Config
	  SAPNW::Base.config_location = $TEST_FILE
		assert( config = SAPNW::Base.load_config )
		#$stderr.print "config length: #{config.length}\n"
		assert( config.length >= 5 )
		assert( SAPNW::Base.config.length >= 5 )
		assert( SAPNW::Base.config['ashost'].length > 3)
		assert( SAPNW::Base.config['sysnr'].length == 2 )
		assert( SAPNW::Base.config['client'].length == 3 )
		assert( SAPNW::Base.config['user'].length >= 2 )
	end

	def teardown
	end
end
