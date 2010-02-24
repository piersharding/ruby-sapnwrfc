require "rbconfig.rb"
Gem::Specification.new do |spec|
  spec.authors = ["Piers Harding"]
  spec.email = 'piers@ompka.net'
  spec.name = 'sapnwrfc'
  spec.summary = 'SAP Netweaver RFC connector for Ruby'
  spec.description = <<-EOF
    sapnwrfc is a ruby module for performing RFC functions and BAPI calls on
    an SAP Netweaver system NW2004+
  EOF
  spec.version = '0.23'
  spec.autorequire = [ 'sapnwrfc' ]
  spec.platform = Config::CONFIG["arch"]
  spec.homepage = 'http://www.piersharding.com'
  spec.files = Dir['lib/**/*.rb']
  spec.files += Dir['ext/nwsaprfc/*.so']
  spec.required_ruby_version = '>= 1.8.0'
  spec.require_paths = ['ext/nwsaprfc', 'lib']
end
