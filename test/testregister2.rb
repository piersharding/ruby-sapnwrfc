#!/usr/bin/ruby
$KCODE = 'u'
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$TEST_FILE = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'
$WAIT = 10

require 'test/unit'
require 'test/unit/assertions'

class SAPRegisterTest < Test::Unit::TestCase
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
    
    def test_BASIC_00010_Test_Register
        begin 
        func = SAPNW::RFC::FunctionDescriptor.new("RFC_REMOTE_PIPE")
            pipedata = SAPNW::RFC::Type.new({:name => 'DATA', 
                                             :type => SAPNW::RFC::TABLE,
                                                                             :fields => [{:name => 'LINE',
                                                                                          :type => SAPNW::RFC::CHAR, 
                                                                                          :len => 80}
                                                                                                    ]
                                                                            })
          func.addParameter(SAPNW::RFC::Export.new(:name => "COMMAND", :len => 80, :type => SAPNW::RFC::CHAR))
          func.addParameter(SAPNW::RFC::Table.new(:name => "PIPEDATA", :len => 80, :type => pipedata))
          $stderr.print "Built up FunctionDescriptor: #{func.inspect}/#{func.parameters.inspect}\n"
            pass = 0
        func.callback = Proc.new do |fc|
            $stderr.print "#{fc.name} got called with #{fc.COMMAND}\n"
                if /^blah/.match(fc.COMMAND)
                  raise SAPNW::RFC::ServerException.new({'error' => "Got Blah", 'code' => 111, 'key' => "RUBY_RUNTIME", 'message' => "Got a blah message" })
                end
                call = `#{fc.COMMAND}`
                fc.PIPEDATA = []
                call.split(/\n/).each do |val|
                  fc.PIPEDATA.push({'LINE' => val})
                end
                pass += 1
                $stderr.print "pass: #{pass}\n"
        # dont ever "return" inside a callback - or it just exits 
                #   make the last value true or nil depending on whether 
                #   you successfully handled callback or not
                true
          end
          $stderr.print "Register...\n"
        assert(server = SAPNW::Base.rfc_register)
        attrib = server.connection_attributes
        SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
          $stderr.print "Install...\n"
        assert(server.installFunction(func))
        globalCallBack = Proc.new do |attrib|
          end
          $stderr.print "Process loop...\n"
          while rc = server.process($WAIT)
            $stderr.print "in process loop: #{rc}\n"
                case rc
                  when SAPNW::RFC::RFC_OK, SAPNW::RFC::RFC_RETRY
                    else
                    break
                end
                break unless pass < 10
            end
      rescue SAPNW::RFC::ServerException => e
        SAP_LOGGER.warn "ServerException ERROR: #{e.inspect} - #{e.error.inspect}\n"
      rescue SAPNW::RFC::FunctionCallException => e
        SAP_LOGGER.warn "FunctionCallException ERROR: #{e.inspect} - #{e.error.inspect}\n"
      rescue SAPNW::RFC::ConnectionException => e
        SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
      end
    end
    
    def teardown
    end
end
