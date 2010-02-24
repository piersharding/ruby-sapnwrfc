
  # SAPNW is Copyright (c) 2006-2008 Piers Harding.  It is free software, and
  # may be redistributed under the terms specified in the README file of
  # the Ruby distribution.
  #
	# Configuration for an RFC connection can be passed in two distinct ways, but those two methods
	# can be combined together.
	#
	# (1) Config is loaded via a YAML based config file
	# (2) Config is passed in the code directly into the connection
	# (3) a combination of (1) and (2), where (2) overides (1) at run time.
	#
	# YAML config file format:
	#
  #   ashost: ubuntu.local.net
  #   sysnr: "01"
  #   client: "001"
  #   user: developer
  #   passwd: developer
  #   lang: EN
  #   trace: 2
	#
	# At connection time, any valid parameters can be added or over ridden:
	#
  #   conn = SAPNW::Base.rfc_connect(:user => 'developer', :passwd => 'developer')
	#
	# Valid connection parameters are:
  #   ashost
  #   dest - used in conjunction with sapnwrfc.ini file
  #   mshost
  #   group
  #   sysid
  #   msserv
  #   sysnr
  #   lang
  #   client
  #   user
  #   passwd
  #   trace
  #   tpname
  #   gwhost
  #   gwserv
  #   codepage
  #   x509cert
  #   extiddata
  #   extidtype
  #   mysapsso2
  #   mysapsso
  #   getsso2
  #   snc_mode
  #   snc_qop
  #   snc_myname
  #   snc_partnername
  #   snc_lib
	#
	#
  #
  # Author::   Piers Harding <piers@ompka.net>
  # Requires:: Ruby 1.8 or later
  #

Logger.class_eval do
  def set_logdev(logfile, logfile_age = 0, logfile_size = 1048576)
		@logdev = Logger::LogDevice.new(logfile, :shift_age => logfile_age, :shift_size => logfile_size)
	end
end

module SAPNW
	module Config
	  class << SAPNW::Base

      @configuration = {}

      attr_accessor :config_location, :config

      def load_config
			  file = self.config_location || './sap.yml'
				SAP_LOGGER.fatal("[#{self.name}] Configuration file not found:  #{file}") unless FileTest.exists?(file)
        self.config = File.open(file) { |f| YAML::load(f) }
        SAP_LOGGER.debug("[#{self.name}] Configuration: " + self.config.inspect)

		    if self.config.key? 'logfile'
				  if /STDOUT/i.match(self.config['logfile'])
					  SAP_LOGGER.set_logdev(STDOUT)
					else
					  SAP_LOGGER.set_logdev(self.config['logfile'],
					                        self.config['logfile_age'] || 0,
						  									  self.config['logfile_size'] || 1048576)
					  SAP_LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S"
					end
				end
		    if self.config.key? 'loglevel'
				  case self.config['loglevel'].upcase
					  when 'FATAL'
				      SAP_LOGGER.level = Logger::FATAL
					  when 'ERROR'
				      SAP_LOGGER.level = Logger::ERROR
					  when 'WARN'
				      SAP_LOGGER.level = Logger::WARN
					  when 'INFO'
				      SAP_LOGGER.level = Logger::INFO
					  when 'DEBUG'
				      SAP_LOGGER.level = Logger::DEBUG
					end
				else
				  # set default 
					SAP_LOGGER.level = Logger::WARN
				end
        return self.config
      end

    end
  end
end
