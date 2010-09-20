require 'tcpsocket-wait'
require 'background_process'
require 'net/http'

module ServiceManager
  SERVICES_PATH = "./config/services.rb"

  extend self

  def services
    return @services if @services

    (@services = []).tap do
      load_services if service_files_loaded.empty?
    end
  end

  def service_files_loaded
    @service_files_loaded ||= []
  end

  def load_services(path = nil)
    path = File.expand_path(path || SERVICES_PATH, Dir.pwd)
    return if service_files_loaded.include?(path)
    service_files_loaded << path
    load path
  end

  def define_service(name = nil, &block)
    name ||= File.basename(caller.first.gsub(/.rb:.+$/, ""))
    ServiceManager::Service.new(:name => name).tap do |service|
      yield service
      services << service
    end
  end

  def services_hash
    Hash[services.map { |s| [s.name.to_sym, s]}]
  end

  # Stop all services.  If service wasn't started by this service manager session, don't try and stop it.
  def stop
    return unless services.any? { |s| s.process }
    puts "Stopping the services..."
    services.map {|s| Thread.new { s.stop } }.map(&:join)
  end

  # Starts all configured services. If service is detected as running already, don't try and start it.
  def start
    raise RuntimeError, "No services defined" if services.empty?
    threads = services.map do |s|
      Thread.new do
        begin
          s.start
        rescue ServiceManager::Service::ServiceDidntStart
          puts "Quitting due to failure."
          exit(1)
        rescue Exception => e
          puts e
          puts e.backtrace
          exit(1)
        end
      end
    end
    threads.map(&:join)
  end
end

require "service_manager/service"
