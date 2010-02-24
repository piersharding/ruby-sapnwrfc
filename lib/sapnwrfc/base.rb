# SAPNW is Copyright (c) 2006-2008 Piers Harding.  It is free software, and
# may be redistributed under the terms specified in the README file of
# the Ruby distribution.
#
# Welcome to sapnwrfc !
#
# sapnwrfc is a RFC based connector to SAP specifically designed for use with the
# next generation RFC SDK supplied by SAP for NW2004+ .
#
#
# 

module SAPNW

  # Some doco in the SAPNW module
  class Base 

  # some doco in Base

	@@rfc_connections = {}


#     def rfc_connection(*args)
#		   return SAPNW::RFC::Connection.connect(args)
#		end
#
#     def rfc_register(*args)
#		   return SAPNW::RFC::Server.connect(args)
#		end
#
#     def installFunction(*args)
#		   return SAPNW::RFC::Server.installFunction(args)
#		end
#
    def Base.finalize(id)
      SAP_LOGGER.debug("[#{self.class}] finalize called")
    end

  end
end

