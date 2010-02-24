$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$TEST_FILE = 'test_sap_logger.log'
require 'fileutils'

require 'test/unit'
require 'test/unit/assertions'

class SAPLoggerTest < Test::Unit::TestCase

	
	def setup
	  SAP_LOGGER.set_logdev($TEST_FILE)
    #SAP_LOGGER.warn "program: #{$0}\n"
	end
	
#  The different ways of connecting to SAP
  def get_log
    log = File.open($TEST_FILE) { |f| f.gets(nil) }
		#SAP_LOGGER.warn log
		return log
  end

  def log_lines
	  lines = get_log.split(/\n/)
		#SAP_LOGGER.warn lines.inspect
		return lines
	end

	def test_BASIC_00010_All_Messages
		assert( SAP_LOGGER.info("an info") )
		assert( SAP_LOGGER.warn("a warning") )
		assert( SAP_LOGGER.error("an error") )
		assert( SAP_LOGGER.fatal("a fatal") )
		assert( SAP_LOGGER.unknown("an unknown") )
		assert( FileTest.exists?($TEST_FILE) )
		#$stderr.print "lines: #{log_lines.length}\n"
    assert( log_lines.length >= 5 ) # one for each log entry and a header
	end

	def test_BASIC_00020_Above_Warn
	  SAP_LOGGER.level = Logger::WARN
		assert( SAP_LOGGER.info("an info") )
		assert( SAP_LOGGER.warn("a warning") )
		assert( SAP_LOGGER.error("an error") )
		assert( SAP_LOGGER.fatal("a fatal") )
		assert( SAP_LOGGER.unknown("an unknown") )
		assert( FileTest.exists?($TEST_FILE) )
		#$stderr.print "lines: #{log_lines.length}\n"
    assert( log_lines.length >= 5 ) # one for each log entry >= WARN and a header
	end

	def teardown
    if FileTest.exists?($TEST_FILE)
      SAP_LOGGER.set_logdev(STDERR) # Unlock the log file before deletion
      GC.start                      # Ensure garbage colletion is run (unlock)
      File.delete($TEST_FILE)
    end
	end
end
