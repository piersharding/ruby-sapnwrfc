#!/usr/bin/ruby
# Sort out UNICODE
$KCODE = 'u'

# Stupid inter release gem dance...
require 'rubygems'
gem 'sapnwrfc'
require 'sapnwrfc'


require 'getopts'

def usage
  $stderr.print "\n
Usage: #{File.basename($0)} -t [-h -s -c -u -p -l]
Options
  -h ashost
  -s sysnr
  -c client
  -u user
  -p passwd
  -l lang
  -t Text to be echoed
"
  exit!
end

# Coneciton option defaults
conn_opts = { :ashost => "ubuntu.local.net", :sysnr => "01", :client => "001", :user => "developer", :passwd => "developer", :lang => "EN", :loglevel => "warn" }

# get options and check
getopts('h:s:c:u:p:l:t:')
usage unless $OPT_t

conn_opts[:ashost] = $OPT_h if $OPT_h
conn_opts[:sysnr]  = $OPT_s if $OPT_s
conn_opts[:client] = $OPT_c if $OPT_c
conn_opts[:user]   = $OPT_u if $OPT_u
conn_opts[:passwd] = $OPT_p if $OPT_p
conn_opts[:lang]   = $OPT_l if $OPT_l


SAP_LOGGER.warn "Connection Options: #{conn_opts.inspect}\n"

begin 
  conn = SAPNW::Base.rfc_connect(conn_opts)
  attrib = conn.connection_attributes
  SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
  fds = conn.discover("STFC_CONNECTION")
  fs = fds.new_function_call
	fs.REQUTEXT = $OPT_t
  fs.invoke
  SAP_LOGGER.warn "RESPTEXT: #{fs.RESPTEXT}\n"
  SAP_LOGGER.warn "ECHOTEXT: #{fs.ECHOTEXT}\n"
  conn.close
rescue SAPNW::RFC::ConnectionException => e
  SAP_LOGGER.warn "ConnectionException: #{e.error}\n"
  raise "gone"
rescue SAPNW::RFC::FunctionCallException => e
  SAP_LOGGER.warn "FunctionCallException: #{e.error}\n"
  raise "bork!"
end
