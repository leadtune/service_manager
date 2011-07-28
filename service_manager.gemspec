Gem::Specification.new do |s|
  s.name = %q{service_manager}
  s.version = "0.6.1"
  s.authors = ["Tim Harper"]
  s.date = Date.today.to_s
  s.default_executable = %q{start_services}
  s.description = <<-EOF
It launches and interacts with a set of services from a single terminal window.

* Colorizes output for each process to help distinguish them.
* Useful for integration-test applications where you need to start up several processes and test them all.
* Built because servolux wasn't working very well for me.
* Can detect exactly when a service is successfully launched by watching the output of the process.
EOF
  s.email = ["tim@leadtune.com"]
  s.executables = ["start_services"]
  s.extra_rdoc_files = [
    "MIT-LICENSE"
  ]
  s.files = ["MIT-LICENSE"] + Dir["lib/**/*"]
  s.homepage = %q{http://github.com/leadtune/service_manager}
  s.require_paths = ["lib"]
  s.summary = %q{service_manager}
  s.test_files = []

  s.add_dependency('background_process', ">= 1.2")
  s.add_dependency "tcpsocket-wait"
end
