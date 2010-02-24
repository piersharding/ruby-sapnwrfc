require "rbconfig.rb"

system("mt -outputresource:nwsaprfc.so;2 -manifest nwsaprfc.so.manifest") if "mswin32".eql? Config::CONFIG["host_os"] and FileTest.exists?("nwsaprfc.so.manifest")
