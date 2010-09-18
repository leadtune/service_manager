require 'tcpsocket-wait'
require 'background_process'
require 'net/http'

module ServiceManager
  SERVICES_PATH = "./config/services.rb"

  extend self

  def services
    return @services if @services
    @services = []
    load_services
    @services
  end

  def load_services(path = nil)
    path ||= SERVICES_PATH
    return if @services_loaded
    load path
    @services_loaded = true
  end

  def define_service(name = nil, &block)
    name ||= File.basename(caller.first.gsub(/.rb:.+$/, ""))
    ServiceManager::Service.new(:name => name).tap do |service|
      yield service
      services << service
    end
  end

  def services_hash
    Hash[ServiceManager.services.map { |s| [s.name.to_sym, s]}]
  end

  def stop(which = :all)
    puts "Stopping the services..."
    services.map {|s| Thread.new { s.stop } }.map(&:join)
  end

  def start(which = :all)
    load_services
    raise RuntimeError, "No services defined" if services.empty?
    threads = services.map do |s|
      Thread.new do
        begin
          s.start
        rescue ServiceManager::Service::ServerDidntStart
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
