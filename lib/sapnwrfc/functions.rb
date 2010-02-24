
# SAPNW is Copyright (c) 2006-2008 Piers Harding.  It is free software, and
# may be redistributed under the terms specified in the README file of
# the Ruby distribution.
#
# Author::   Piers Harding <piers@ompka.net>
# Requires:: Ruby 1.8 or later
#

module SAPNW
  module Functions
	  class Base

		end
	end

	module RFC

      # These are automatically created as a result of SAPNW::RFC::Connection#discover() -
			# do not instantiate these yourself yourself!
			#
		class FunctionDescriptor
		  attr_reader :name, :parameters
			attr_accessor :callback

      # create a new SAPNW::RFC::FunctionCall object for this FunctionDescriptor.
			#
			# You must call this each time that you want to invoke() a new function call, as
			# this creates a one shot container for the passing back and forth of interface parameters.
			def new_function_call
			  return create_function_call(SAPNW::RFC::FunctionCall)
			end

			def make_empty_function_call
			  return SAPNW::RFC::FunctionCall.new(self)
			end

	    def callback=(proc)
	      if proc.instance_of?(Proc)
	        @callback = proc
	      else
	        raise "Must pass in an instance of Proc for the callback"
	      end
	      return @callback
	    end

			def handler(function)
				begin
          return @callback.call(function)
				rescue SAPNW::RFC::ServerException => e
				  #$stderr.print "ServerException => #{e.error.inspect}\n"
				  return e
				rescue StandardError => e
				  #$stderr.print "StandardError => #{e.inspect}/#{e.message}\n"
				  return SAPNW::RFC::ServerException.new({'code' => 3, 'key' => 'RUBY_RUNTIME', 'message' => e.message})
				end
			end

      def method_missing(methid, *rest)
        meth = methid.id2name
        if @parameters.has_key?(meth)
			    return @parameters[meth]
			  else
			    raise NoMethodError
			  end
      end

			# internal method used to add parameters from within the C extension
			#def addParameter(name = nil, direction = 0, type = 0, len = 0, ulen = 0, decimals = 0)
			def addParameter(*parms)
				parms = parms.first if parms.class == Array and (parms.first.class == Hash || parms.first.kind_of?(SAPNW::RFC::Parameter))
			  case parms
				  when Array
					  name, direction, type, len, ulen, decimals = parms
				  when Hash
            name = parms.has_key?(:name) ? parms[:name] : nil
            direction = parms.has_key?(:direction) ? parms[:direction] : nil
            type = parms.has_key?(:type) ? parms[:type] : nil
            len = parms.has_key?(:len) ? parms[:len] : nil
            ulen = parms.has_key?(:ulen) ? parms[:ulen] : nil
            decimals = parms.has_key?(:decimals) ? parms[:decimals] : nil
			    when SAPNW::RFC::Export, SAPNW::RFC::Import, SAPNW::RFC::Changing, SAPNW::RFC::Table
					  # this way happens when a function def is manually defined
					  self.add_parameter(parms)
            @parameters[parms.name] = parms
						return parms
				  else
			      raise "invalid SAPNW::RFC::FunctionDescriptor parameter supplied: #{parms.inspect}\n"
				end
				
			  #$stderr.print "parm: #{name} direction: #{direction} type: #{type} len: #{len} decimals: #{decimals}\n"
        case direction
				  when SAPNW::RFC::IMPORT
					  if @parameters.has_key?(name) and @parameters[name].direction == SAPNW::RFC::EXPORT
					    p = SAPNW::RFC::Changing.new(self, name, type, len, ulen, decimals)
						else
					    p = SAPNW::RFC::Import.new(self, name, type, len, ulen, decimals)
						end
					when SAPNW::RFC::EXPORT
					  if @parameters.has_key?(name) and @parameters[name].direction == SAPNW::RFC::IMPORT
					    p = SAPNW::RFC::Changing.new(self, name, type, len, ulen, decimals)
						else
					    p = SAPNW::RFC::Export.new(self, name, type, len, ulen, decimals)
						end
					when SAPNW::RFC::CHANGING
					  p = SAPNW::RFC::Changing.new(self, name, type, len, ulen, decimals)
					when SAPNW::RFC::TABLES
					  p = SAPNW::RFC::Table.new(self, name, type, len, ulen, decimals)
					else
					  raise "unknown direction (#{name}): #{direction}\n"
				end
        @parameters[p.name] = p
				return p
			end

		end

		class FunctionCall
		  attr_reader :function_descriptor, :name, :parameters

      # These are automatically created as a result of SAPNW::RFC::FunctionDescriptor#new_function_call() -
			# do not instantiate these yourself!
			#
			# SAPNW::RFC::FunctionCall objects allow dynamic method calls of parameter, and table names 
			# for the setting and getting of interface values eg:
			#   fd = conn.discover("RFC_READ_TABLE")
			#   f = fd.new_function_call
			#   f.QUERY_TABLE = "T000" # <- QUERY_TABLE is a dynamic method serviced by method_missing
			#def initialize(fd=nil)
			def initialize(fd=nil)
			  @parameters = {}
			  if fd == nil
				  @function_descriptor.parameters.each_pair do |k,v|
				    @parameters[k] = v.clone
				  end
				else 
				  fd.parameters.each_pair do |k,v|
				    @parameters[k] = v.clone
				  end
				end
				@parameters_list = @parameters.values || []
			end

      # activate a parameter - parameters are active by default so it is unlikely that this
			# would ever need to be called.
			def activate(parm=nil)
			  raise "Parameter not found: #{parm}\n" unless @parameters.has_key?(parm)
				return set_active(parm, 1)
			end

      # deactivate a parameter - parameters can be deactivated for a function call, to reduce the 
			# amount of RFC traffic on the wire.  This is especially important for unrequired tables, or
			# parameters that are similar sources of large data transfer.
			def deactivate(parm=nil)
			  raise "Parameter not found: #{parm}\n" unless @parameters.has_key?(parm)
				return set_active(parm, 0)
			end

      # dynamic method calls for parameters and tables
      def method_missing(methid, *rest)
        meth = methid.id2name
			  #$stderr.print "method_missing: #{meth}\n"
				#$stderr.print "parameters: #{@parameters.keys.inspect}\n"
        if @parameters.has_key?(meth)
				  #$stderr.print "return parm obj\n"
			    return @parameters[meth].value
			  elsif mat = /^(.*?)\=$/.match(meth)
				  #$stderr.print "return parm val\n"
          if  @parameters.has_key?(mat[1])
					  return @parameters[mat[1]].value = rest[0]
				  else
					  raise NoMethError
          end
			  else
			    raise NoMethodError
			  end
      end
		end
  end
end
