
# SAPNW is Copyright (c) 2006-2008 Piers Harding.  It is free software, and
# may be redistributed under the terms specified in the README file of
# the Ruby distribution.
#
# Author::   Piers Harding <piers@ompka.net>
# Requires:: Ruby 1.8 or later
#

module SAPNW
  module Parameters
	 
	  # base class for all parameters
	  class Base

		  # they all have:
			#   a name
			#   may or may not have a structure = a type
			#   type may be complex or simple
			#
			#

		end
	end

	module RFC

    # Parameter types
		IMPORT = 1
		EXPORT = 2
		CHANGING = 3
		TABLES = 7

    # basic data types
		CHAR = 0
		DATE = 1
		BCD = 2
		TIME = 3
		BYTE = 4
		TABLE = 5
		NUM = 6
		FLOAT = 7
		INT = 8
		INT2 = 9
		INT1 = 10
		NULL = 14
		STRUCTURE = 17
		DECF16 = 23
		DECF34 = 24
		XMLDATA = 28
		STRING = 29
		XSTRING = 30
		EXCEPTION = 98

		# return codes
		RFC_OK = 0
		RFC_COMMUNICATION_FAILURE = 1
		RFC_LOGON_FAILURE = 2
		RFC_ABAP_RUNTIME_FAILURE = 3
		RFC_ABAP_MESSAGE = 4
		RFC_ABAP_EXCEPTION = 5
		RFC_CLOSED = 6
		RFC_CANCELED = 7
		RFC_TIMEOUT = 8
		RFC_MEMORY_INSUFFICIENT = 9
		RFC_VERSION_MISMATCH = 10
		RFC_INVALID_PROTOCOL = 11
		RFC_SERIALIZATION_FAILURE = 12
		RFC_INVALID_HANDLE = 13
		RFC_RETRY = 14
		RFC_EXTERNAL_FAILURE = 15
		RFC_EXECUTED = 16
		RFC_NOT_FOUND = 17
		RFC_NOT_SUPPORTED = 18
		RFC_ILLEGAL_STATE = 19
		RFC_INVALID_PARAMETER = 20
		RFC_CODEPAGE_CONVERSION_FAILURE = 21
		RFC_CONVERSION_FAILURE = 22
		RFC_BUFFER_TOO_SMALL = 23
		RFC_TABLE_MOVE_BOF = 24
		RFC_TABLE_MOVE_EOF = 25


    # Base class for all Parameter types
		class Parameter < SAPNW::Parameters::Base
		  attr_reader :name, :type, :typdef, :direction, :len, :ulen, :decimals, :value

		  # constructor called only from the SAPNW::RFC::Connector#discover process
			#def initialize(funcdesc, name, type, len, ulen, decimals)
			def initialize(*parms)
				parms = parms.first if parms.class == Array and parms.first.class == Hash
			  case parms
				  when Array
					  # this way happens when the interface of the parameter has been discover()ed
					  funcdesc, name, type, len, ulen, decimals, typedef = parms
					when Hash
					  # This way happens when a parameter is being manually constructed
					  raise "Missing parameter :name => #{parms.inspect}\n" unless parms.has_key?(:name)
					  raise "Missing parameter :type => #{parms.inspect}\n" unless parms.has_key?(:type)
						case parms[:type]
						  when SAPNW::RFC::CHAR, SAPNW::RFC::DATE, SAPNW::RFC::BCD, SAPNW::RFC::TIME, SAPNW::RFC::BYTE, SAPNW::RFC::TABLE, SAPNW::RFC::NUM, SAPNW::RFC::FLOAT, SAPNW::RFC::INT, SAPNW::RFC::INT2, SAPNW::RFC::INT1, SAPNW::RFC::NULL, SAPNW::RFC::STRUCTURE, SAPNW::RFC::DECF16, SAPNW::RFC::DECF34, SAPNW::RFC::XMLDATA, SAPNW::RFC::STRING, SAPNW::RFC::XSTRING, SAPNW::RFC::EXCEPTION
							else
							  if parms[:type].class == SAPNW::RFC::Type
							    parms[:typedef] = parms[:type]
									parms[:type] = parms[:typedef].type
									raise "Parameter type (#{self.class}) does not match Type type (#{parms[:typedef].inspect})\n" if self.class == SAPNW::RFC::Table and parms[:type] != SAPNW::RFC::TABLE
						    else		  
							    raise "Invalid SAPNW::RFC* type supplied (#{parms[:type]})\n"
								end
						end
			      funcdesc = nil
			      len = 0
			      ulen = 0
			      decimals = 0
						name = parms[:name]
						type = parms[:type]
						typedef = parms[:typedef] if parms.has_key?(:typedef)
						len = parms[:len] if parms.has_key?(:len)
						ulen = parms[:ulen] if parms.has_key?(:ulen)
						decimals = parms[:decimals] if parms.has_key?(:decimals)
					else
					  raise "invalid parameters: #{parms.inspect}\n"
				end
			  @function_descriptor = funcdesc
				@name = name
				@type = type
				@typedef = typedef
				@len = len
				@ulen = ulen
				@decimals = decimals
				@value = nil
				#$stderr.print "initilised parameter(#{@name}): #{self.inspect}\n"
			end

      # method_missing is used to pass on any method call to a parameter
			# to the underlying native Ruby data type
      def method_missing(methid, *rest, &block)
        meth = methid.id2name
        #$stderr.print "method_missing: #{meth}\n"
        #$stderr.print "parameters: #{@parameters.keys.inspect}\n"
        if block
          @value.send(meth, &block)
        else
          #$stderr.print "Export method_missing - no block: #{meth}\n"
          @value.send(meth, *rest)
        end
      end

      # value setting for parameters - does basic Type checking to preserve
			# sanity for the underlying C extension
			def value=(val=nil)
				#$stderr.print "setting: #{@name} type: #{@type} value: #{val}/#{val.class}\n"
        case @type
				  when SAPNW::RFC::INT, SAPNW::RFC::INT2, SAPNW::RFC::INT1
            unless val.is_a?(Fixnum)
					    raise TypeError, "Must be Fixnum for INT, INT1, and INT2 (#{@name}/#{@type}/#{val.class})\n"
						end
				  when SAPNW::RFC::NUM
            unless val.is_a?(String)
					    raise TypeError, "Must be String for NUMC (#{@name}/#{@type}/#{val.class})\n"
						end
				  when SAPNW::RFC::BCD
            unless val.is_a?(Float) || val.is_a?(Fixnum) || val.is_a?(Bignum)
					    raise TypeError, "Must be FLoat or *NUM for BCD (#{@name}/#{@type}/#{val.class})\n"
						end
						val = val.to_s
				  when SAPNW::RFC::FLOAT
            unless val.is_a?(Float)
					    raise TypeError, "Must be FLoat for FLOAT (#{@name}/#{@type}/#{val.class})\n"
						end
				  when SAPNW::RFC::STRING, SAPNW::RFC::XSTRING
            unless val.is_a?(String)
					    raise TypeError, "Must be String for STRING, and XSTRING (#{@name}/#{@type}/#{val.class})\n"
						end
				  when SAPNW::RFC::BYTE
            unless val.is_a?(String)
					    raise TypeError, "Must be String for BYTE (#{@name}/#{@type}/#{val.class})\n"
						end
				  when SAPNW::RFC::CHAR, SAPNW::RFC::DATE, SAPNW::RFC::TIME
            unless val.is_a?(String)
					    raise TypeError, "Must be String for CHAR, DATE, and TIME (#{@name}/#{@type}/#{val.class})\n"
						end
				  when SAPNW::RFC::TABLE
            unless val.is_a?(Array)
    			    raise TypeError, "Must be Array for table value (#{@name}/#{val.class})\n"
    				end
    				cnt = 0
    			  val.each do |row|
    				  cnt += 1
              unless row.is_a?(Hash)
    			      raise TypeError, "Must be Hash for table row value (#{@name}/#{cnt}/#{row.class})\n"
    				  end
    				end
				  when SAPNW::RFC::STRUCTURE
            unless val.is_a?(Hash)
					    raise TypeError, "Must be a Hash for a Structure Type (#{@name}/#{@type}/#{val.class})\n"
						end
					else # anything - barf
					  raise "unknown SAP data type (#{@name}/#{@type})\n"
				end
				@value = val
				return val
			end

		end

    # RFC Import Parameters
		class Import < SAPNW::RFC::Parameter
		  def initialize(*args)
			  @direction = SAPNW::RFC::IMPORT
				super
			end
		end

    # RFC Export Parameters
		class Export < SAPNW::RFC::Parameter
		  def initialize(*args)
			  @direction = SAPNW::RFC::EXPORT
				super
			end
		end

    # RFC Changing Parameters
		class Changing < SAPNW::RFC::Parameter
		  def initialize(*args)
			  @direction = SAPNW::RFC::CHANGING
				super
			end
		end

    # RFC Table type Parameters
		class Table < SAPNW::RFC::Parameter
		  def initialize(*args)
			  @direction = SAPNW::RFC::TABLES
				super
			end

      # returns the no. of rows currently in the table
      def length
        return @value.length
      end

      # assign an Array, of rows represented by Hashes to the value of
			# the Table parameter.
		  def value=(val=[])
        unless val.is_a?(Array)
			    raise TypeError, "Must be Array for table value (#{@name}/#{val.class})\n"
				end
				cnt = 0
			  val.each do |row|
				  cnt += 1
          unless row.is_a?(Hash)
			      raise TypeError, "Must be Hash for table row value (#{@name}/#{cnt}/#{row.class})\n"
				  end
				end
				@value = val
			end

      # Yields each row of the table to passed Proc
		  def each
			  return nil unless @value
				@value.each do |row|
				  yield row
				end
			end
		end

		class Type

		  attr_reader :name, :type, :len, :ulen, :decimals, :fields

		  def initialize(*args)
				args = args.first if args.class == Array and args.first.class == Hash
			  case args
				  when Array
					  name, type, len, ulen, decimals, fields = args
					when Hash
					  raise "Missing Type :name => #{args.inspect}\n" unless args.has_key?(:name)
					  raise "Missing Type :type => #{args.inspect}\n" unless args.has_key?(:type)
					  #raise "Missing Type :len => #{args.inspect}\n" unless args.has_key?(:len)
						case args[:type]
						  when SAPNW::RFC::CHAR, SAPNW::RFC::DATE, SAPNW::RFC::BCD, SAPNW::RFC::TIME, SAPNW::RFC::BYTE, SAPNW::RFC::TABLE, SAPNW::RFC::NUM, SAPNW::RFC::FLOAT, SAPNW::RFC::INT, SAPNW::RFC::INT2, SAPNW::RFC::INT1, SAPNW::RFC::NULL, SAPNW::RFC::STRUCTURE, SAPNW::RFC::DECF16, SAPNW::RFC::DECF34, SAPNW::RFC::XMLDATA, SAPNW::RFC::STRING, SAPNW::RFC::XSTRING, SAPNW::RFC::EXCEPTION
							else
							  raise "Invalid SAPNW::RFC* type supplied (#{args[:type]})\n"
						end
			      len = 0
			      ulen = 0
			      decimals = 0
						name = args[:name]
						type = args[:type]
						len = args[:len] if args.has_key?(:len)
						ulen = 2 * len
						ulen = args[:ulen] if args.has_key?(:ulen)
						decimals = args[:decimals] if args.has_key?(:decimals)
						fields = args[:fields] if args.has_key?(:fields)
					else
					  raise "invalid parameters in SAPNW::RFC::Type: #{args.inspect}\n"
				end
				@name = name
				@type = type
				@len = len
				@ulen = ulen
				@decimals = decimals
				if fields
				  raise "Fields must be an Array (#{fields.inspect})\n" unless fields.class == Array
				  slen = 0
				  sulen = 0
				  fields.each do |val|
				    raise "each field definition must be a Hash (#{val.inspect})\n" unless val.class == Hash
						unless val.has_key?(:name) and
						       val.has_key?(:type) and
						       val.has_key?(:len)
				      raise "each field definition must have :name, :type, and :len (#{val.inspect})\n"
						end
						val[:ulen] = val[:len] * 2 unless val.has_key?(:ulen)
						val[:decimals] = 0 unless val.has_key?(:decimals)
						slen += val[:len]
						sulen += val[:ulen]
						# sort out nested types
						if val[:type].class == SAPNW::RFC::Type
						  val[:typedef] = val[:type]
							val[:type] = val[:typedef].type
						end
					end
					@len = slen unless @len > 0
					@ulen = sulen unless @ulen > 0
				end
				@fields = fields
				#$stderr.print "initilised Type(#{name}): #{type} - #{@fields.inspect}\n"
			end
		end
  end
end
