base_dir = File.expand_path(File.join(File.dirname(__FILE__), "."))
test_dir = File.join(base_dir, "test")
ENV['SAP_YML'] = File.join(test_dir,'sap.yml')

require 'test/unit'

exit Test::Unit::AutoRunner.run(true, test_dir)
