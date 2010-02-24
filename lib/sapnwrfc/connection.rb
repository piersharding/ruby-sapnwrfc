
# SAPNW is Copyright (c) 2006-2008 Piers Harding.  It is free software, and
# may be redistributed under the terms specified in the README file of
# the Ruby distribution.
#
# Author::   Piers Harding <piers@ompka.net>
# Requires:: Ruby 1.8 or later
#

module SAPNW
  module Connections

    class << SAPNW::Base

# Build a connection to an R/3 system (ABAP AS)
#
# Connection parameters can be passed in a variety of ways
# (a) via a YAML based configuration file
# (b) a Hash of parameter arguments
# (c) a combination of both
  	  def rfc_connect(args = nil)
        parms = {}
				self.config = {} unless self.config
	  		parms[:ashost] = self.config['ashost']           if self.config.key? 'ashost'
	  		parms[:dest] = self.config['dest']               if self.config.key? 'dest'
	  		parms[:mshost] = self.config['mshost']           if self.config.key? 'mshost'
	  		parms[:group] = self.config['group']             if self.config.key? 'group'
	  		parms[:sysid] = self.config['sysid']             if self.config.key? 'sysid'
	  		parms[:msserv] = self.config['msserv']           if self.config.key? 'msserv'
	  		parms[:sysnr] = self.config['sysnr']             if self.config.key? 'sysnr'
	  		parms[:lang] = self.config['lang']               if self.config.key? 'lang'
  			parms[:client] = self.config['client']           if self.config.key? 'client'
  			parms[:user] = self.config['user']               if self.config.key? 'user'
  			parms[:passwd] = self.config['passwd']           if self.config.key? 'passwd'
  			parms[:trace] = self.config['trace'].to_i        if self.config.key? 'trace'
        parms[:codepage] = self.config['codepage'].to_i  if self.config.key? 'codepage'
	  		parms[:x509cert] = self.config['x509cert']       if self.config.key? 'x509cert'
	  		parms[:extiddata] = self.config['extiddata']     if self.config.key? 'extiddata'
	  		parms[:extidtype] = self.config['extidtype']     if self.config.key? 'extidtype'
  			parms[:mysapsso2] = self.config['mysapsso2']     if self.config.key? 'mysapsso2'
  			parms[:mysapsso] = self.config['mysapsso']       if self.config.key? 'mysapsso'
  			parms[:getsso2] = self.config['getsso2'].to_i    if self.config.key? 'getsso2'
  			parms[:snc_mode] = self.config['snc_mode']       if self.config.key? 'snc_mode'
  			parms[:snc_qop] = self.config['snc_qop']         if self.config.key? 'snc_qop'
  			parms[:snc_myname] = self.config['snc_myname']   if self.config.key? 'snc_myname'
  			parms[:snc_partnername] = self.config['snc_partnername'] if self.config.key? 'snc_partnername'
  			parms[:snc_lib] = self.config['snc_lib']         if self.config.key? 'snc_lib'
        SAP_LOGGER.debug("[" + self.name + "] base parameters to be passed are: " + parms.inspect)

        case args
				  when nil
				  when Hash
	  		    parms[:ashost] = args[:ashost]           if args.key? :ashost
	  		    parms[:dest] = args[:dest]               if args.key? :dest
	  		    parms[:mshost] = args[:mshost]           if args.key? :mshost
	  		    parms[:sysid] = args[:sysid]             if args.key? :sysid
	  		    parms[:group] = args[:group]             if args.key? :group
	  		    parms[:msserv] = args[:msserv]           if args.key? :msserv
    	  		parms[:sysnr] = args[:sysnr]             if args.key? :sysnr
    	  		parms[:lang] = args[:lang]               if args.key? :lang
      			parms[:client] = args[:client]           if args.key? :client
      			parms[:user] = args[:user]               if args.key? :user
      			parms[:passwd] = args[:passwd]           if args.key? :passwd
      			parms[:trace] = args[:trace].to_i        if args.key? :trace
            parms[:codepage] = args[:codepage].to_i  if args.key? :codepage
    	  		parms[:x509cert] = args[:x509cert]       if args.key? :x509cert
    	  		parms[:extiddata] = args[:extiddata]     if args.key? :extiddata
    	  		parms[:extidtype] = args[:extidtype]     if args.key? :extidtype
      			parms[:mysapsso2] = args[:mysapsso2]     if args.key? :mysapsso2
      			parms[:mysapsso] = args[:mysapsso]       if args.key? :mysapsso
      			parms[:getsso2] = args[:getsso2].to_i    if args.key? :getsso2
      			parms[:snc_mode] = args[:snc_mode]       if args.key? :snc_mode
      			parms[:snc_qop] = args[:snc_qop]         if args.key? :snc_qop
      			parms[:snc_myname] = args[:snc_myname]   if args.key? :snc_myname
      			parms[:snc_partnername] = args[:snc_partnername] if args.key? :snc_partnername
      			parms[:snc_lib] = args[:snc_lib]         if args.key? :snc_lib
            SAP_LOGGER.debug("[" + self.name + "] with EXTRA parameters to be passed are: " + parms.inspect)
				  else
					  raise "Wrong parameters for Connection - must pass a Hash\n"
				end


        connection = SAPNW::RFC::Connection.new(parms)
        SAP_LOGGER.debug("completed the connection (#{connection.handle.class}/#{connection.handle.object_id}) ...")
	  		return connection

	  	end
		end
  end

  module RFC
	  class Connection
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
	  			  raise "Wrong parameters for Connection - must pass a Hash\n"
	  		end
        SAP_LOGGER.debug("In #{self.class} initialize: #{@connection_parameters.inspect} ...")
				@functions = {}
		    @handle = SAPNW::RFC::Handle.new(self)
	  	end
    
	  	def connection_attributes
        SAP_LOGGER.debug("In #{self.class} connection_attributes ...")
        return self.handle.connection_attributes()
  		end
   
	    # discover() looks up the dictionary definition of an RFC interface
			# storing away the meta data of the associated Parameters/Tables and returns this
			# as an instance of SAPNW::RFC::FunctionDescriptor.  This is the MANDATORY starting 
			# point of all client side RFC.
	  	def discover(func = nil)
        SAP_LOGGER.debug("In #{self.class} discover (#{func}) ...")
				case func
				  when nil
					  return nil
					else
            func_def = self.handle.function_lookup(SAPNW::RFC::FunctionDescriptor, SAPNW::RFC::Parameter, func.to_s)
            @functions[func_def.name] = func_def
						return func_def
				end
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
   
	    # ping test a connection to see if it is still alive
  		def ping
          SAP_LOGGER.debug("In #{self.class} ping ...")
	  	  return nil unless self.handle
          SAP_LOGGER.debug("In #{self.class} handle: #{self.handle} ...")
          return self.handle.ping()
		end
  	end
	end
end
