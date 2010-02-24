$:.unshift('./test')

require 'test/unit/testsuite'
require 'test/unit/ui/console/testrunner'

require 'test_logger'
require 'test_config'
require 'test_connect'
require 'test_attributes'
require 'test_functions'
require 'test_call'
require 'test_changing'
require 'test_data'
require 'test_deep'
require 'test_sflight'

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
