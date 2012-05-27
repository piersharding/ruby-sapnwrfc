$:.unshift('./test')
require 'test/unit'
#require "test/unit/runner/gtk2"
#require 'test/unit/ui/console/testrunner'
#require 'test/unit/testsuite'
require 'test/unit/ui/console/testrunner'

require_relative 'test_logger'
require_relative 'test_config'
require_relative 'test_connect'
require_relative 'test_attributes'
require_relative 'test_functions'
require_relative 'test_call'
require_relative 'test_changing'
require_relative 'test_data'
require_relative 'test_deep'
require_relative 'test_sflight'

class TS_MyTests
   def self.suite
     suite = Test::Unit::TestSuite.new
     suite = SAPLoggerTest.suite
     suite << SAPConfigTest.suite
     suite << SAPConnectTest.suite
     suite << SAPConnectionAttributeTest.suite
     suite << SAPFunctionsTest.suite
     suite << SAPCallTest.suite
     suite << SAPChangingTest.suite
     suite << SAPDataTest.suite
     suite << SAPDeepTest.suite
     suite << SAPSFlightTest.suite
     return suite
   end
end
Test::Unit::UI::Console::TestRunner.run(TS_MyTests)
