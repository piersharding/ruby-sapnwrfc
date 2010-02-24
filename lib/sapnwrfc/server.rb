
# SAPNW is Copyright (c) 2006-2008 Piers Harding.  It is free software, and
# may be redistributed under the terms specified in the README file of
# the Ruby distribution.
#
# Author::   Piers Harding <piers@ompka.net>
# Requires:: Ruby 1.8 or later
#

module SAPNW

  module Servers

    class << SAPNW::Base

	    # registers with an R/3 systems gateway service.  Uses parameters supplied
			# in the YAML config file by default, but overrides these with any passed
			# as a Hash.  returns a SAPNW::RFC::Server object
  	  def rfc_register(args = nil)
        parms = {}
  			parms[:trace] = self.config['trace'].to_i        if self.config.key? 'trace'
  			parms[:tpname] = self.config['tpname']           if self.config.key? 'tpname'
  			parms[:gwhost] = self.config['gwhost']           if self.config.key? 'gwhost'
  			parms[:gwserv] = self.config['gwserv']           if self.config.key? 'gwserv'
        SAP_LOGGER.debug("[" + self.name + "] base parameters to be passed are: " + parms.inspect)

        case args
				  when nil
				  when Hash
      			parms[:trace] = args[:trace].to_i        if args.key? :trace
      			parms[:tpname] = args[:tpname]           if args.key? :tpname
      			parms[:gwhost] = args[:gwhost]           if args.key? :gwhost
      			parms[:gwserv] = args[:gwserv]           if args.key? :gwserv
            SAP_LOGGER.debug("[" + self.name + "] with EXTRA parameters to be passed are: " + parms.inspect)
				  else
					  raise "Wrong parameters for Connection - must pass a Hash\n"
				end

        server = SAPNW::RFC::Server.new(parms)
        SAP_LOGGER.debug("completed the server connection (#{server.handle.class}/#{server.handle.object_id}) ...")
	  		return server
	  	end
		end
  end


  module RFC
	  class ServerException < Exception
		  def initialize(error=nil)
			  unless error.class == Hash
				  error = {'code' => 3, 'key' => 'RUNTIME', 'message' => error.to_s}
				end
			  @error = error
			end
		end

	  class Server
	    attr_accessor :handle
		  attr_reader   :connection_parameters, :functions

  	  def initialize(args = nil)
  			@connection_parameters = []
        case args
	  		  when nil
	  		  when Hash
	  		    args.each_pair { |key, val|
	  		      @connection_parameters << { 'name' => key.to_s, 'value' => val.to_s }
	  		    }
	  		  else
	  			  raise "Wrong parameters for Server Connection - must pass a Hash\n"
	  		end
        SAP_LOGGER.debug("In #{self.class} initialize: #{@connection_parameters.inspect} ...")
				@functions = {}
				@attributes = nil
		    @handle = SAPNW::RFC::ServerHandle.new(self)
	  	end

	    # installs a SAPNW::RFC::FunctionDescriptor object, and optionally associates
			# this with a particular SysId.
  	  def installFunction(*args)
			  args = args.first if args.class == Array and args.first.class == Hash
				case args
				  when Hash
				    raise "Must pass an instance of SAPNW::RFC::FunctionDescriptor to installFunction()\n" unless args.has_key?(:descriptor) and args[:descriptor].class == SAPNW::RFC::FunctionDescriptor
						func = args[:descriptor]
						sysid = args.has_key?(:sysid) ? args[:sysid] : ""
					when Array
				    raise "Must pass an instance of SAPNW::RFC::FunctionDescriptor to installFunction()\n" unless args.first.class == SAPNW::RFC::FunctionDescriptor 
						func = args.first
						sysid = args.length > 1 ? args[1] : ""
					else
				    raise "Must pass an instance of SAPNW::RFC::FunctionDescriptor to installFunction()\n"
				end
        #$stderr.print "sysid: #{sysid}\n"
				res = func.install(sysid)
				@functions[func.name] = func
				return res
	  	end

			def self.handler(callback=nil,attributes=nil)
			  return if callback == nil
        begin
          return callback.call(attributes)
        rescue SAPNW::RFC::ServerException => e
          #$stderr.print "ServerException => #{e.error.inspect}\n"
          return e
        rescue StandardError => e
          #$stderr.print "StandardError => #{e.inspect}/#{e.message}\n"
          return SAPNW::RFC::ServerException.new({'code' => 3, 'key' => 'RUBY_RUNTIME', 'message' => e.message})
        end
			end


	    # fire the accept loop taking optionally a wait time for each loop, and a global
			# callback to be triggered after each loop/loop timeout.
			# Callback - if supplied - must be a Proc object, that takes a simgle parameter, 
			# which is a hash of the system connection attributes.
			def accept(wait=120, callback=nil)
        trap('INT', 'EXIT')
        return @handle.accept_loop(wait, callback);
			end


	    # similar to the accept() loop only that it does a single RfcListenAndDispatch()
			# on the SAPNW::RFC::Server connection handle.  The result is the RFC return code
			# as per the SAPNW::RFC::RFC_* return code constants.
			# process() optionally takes asingle parameter which is the wait-time.
			def process(wait=120)
        trap('INT', 'EXIT')
        return @handle.process_loop(wait);
			end
    
			# Returns a Hash of the connections attributes of this server connection.
	  	def connection_attributes
        SAP_LOGGER.debug("In #{self.class} connection_attributes ...")
        return @attributes = self.handle.connection_attributes()
  		end
   
	    # terminate an established RFC connection.  This will invalidate any currently in-scope
			# FunctionDescriptors associated with this Connection.
  		def close
        SAP_LOGGER.debug("In #{self.class} close ...")
	  	  return nil unless self.handle
        SAP_LOGGER.debug("In #{self.class} handle: #{self.handle} ...")
        res = self.handle.close()
		  	self.handle = nil
				# XXX Should destroy all cached functions and structures and types tied to handle ?
		  	return true
		  end
  	end
	end
end
