require "thread"
require "timeout"
class ServiceManager::Service
  CHDIR_SEMAPHORE = Mutex.new
  ANSI_COLOR_RESET = 0

  attr_accessor :name, :host, :port, :cwd, :reload_uri, :start_cmd, :process, :loaded_cue, :timeout, :color, :pid_file, :manage_pid_file

  class ServiceDidntStart < Exception; end

  def initialize(options = {})
    options.each { |k,v| send("#{k}=", v) }
    self.host ||= "localhost"
    self.color ||= ANSI_COLOR_RESET
    self.timeout ||= 30
    raise ArgumentError, "You need to provide a name for this app service" unless name
  end

  def url
    "http://#{host}:#{port}"
  end

  def server_info_hash
    {:name => name, :host => host, :port => port, :pid_file => pid_file}
  end

  def watch_for_cue
    process.detect(:both, timeout) do |output|
      STDOUT << colorize(output)
      output =~ loaded_cue
    end
  end

  def start_output_stream_thread
    Thread.new { process.detect { |output| STDOUT << colorize(output); nil} }
  end

  def start_cmd
    @start_cmd.is_a?(Proc) ? instance_eval(&@start_cmd) : @start_cmd
  end

  def without_bundler_env(&block)
    vars = %w{BUNDLE_PATH BUNDLE_GEMFILE BUNDLE_BIN_PATH}
    old_values = vars.map {|v| ENV.delete(v)}
    yield
    vars.zip(old_values).each { |var, value| ENV[var] = value }
  end

  def start
    if running?
      puts "Server for #{colorized_service_name} detected as running."
      reload || puts("Reloading not supported.  Any changes made to code for #{colorized_service_name} will not take effect!")
      return false
    end

    CHDIR_SEMAPHORE.synchronize do
      puts "Starting #{colorized_service_name} in #{cwd} with '#{start_cmd}'\n"
      Dir.chdir(cwd) do
        without_bundler_env do
          # system("bash -c set")
          self.process = PTYBackgroundProcess.run(start_cmd)
        end
      end
    end
    at_exit { stop }
    wait
    puts "Server #{colorized_service_name} is up."
    File.open(pid_file, "wb") { |f| f << process.pid } if manage_pid_file
  end

  # stop the service.  If we didn't start it, do nothing.
  def stop
    return unless process
    puts "Shutting down #{colorized_service_name}"
    process.kill
    process.wait(3)
    if process.running?
      process.kill("KILL") # ok... no more Mr. Nice Guy.
      process.wait
    end
    puts "Server #{colorized_service_name} (#{process.pid}) is shut down"
    self.process = nil
    FileUtils.rm(pid_file) if manage_pid_file && File.exist?(pid_file)
    true
  end

  # reload the service by hitting the configured reload_url. In this case, the service needs to be a web service, and needs to have an action that you can hit, in test mode, that will cause the process to gracefully reload itself.
  def reload
    return false unless reload_uri
    puts "Reloading #{colorized_service_name} app by hitting http://#{host}:#{port}#{reload_uri} ..."
    res = Net::HTTP.start(host, port) {|http| http.get(reload_uri) }
    raise("Reloading app #{colorized_service_name} did not return a 200! It returned a #{res.code}. Output:\n#{colorize(res.body)}") unless res.code.to_i == 200
    true
  end

  # detects if the service is running on the configured host and port (will return true if we weren't the ones who started it)
  def running?
    case
    when pid_file
      running_via_pid_file?
    when port
      TCPSocket.listening_service?(:port => port, :host => host || "127.0.0.1")
    else raise "Service Manager needs to be able to tell if the service is already running or not. You'll need to specify a pid file or a TCP port to check."
    end
  end

protected

  def running_via_pid_file?
    Process.kill(0, File.read(pid_file).to_i)
  rescue Errno::ESRCH, Errno::ENOENT
    return false
  end

  def colorize(output)
    no_color = output.gsub(/\e\[(\d*\;|)\d*m\d*/, "")
    "\e[0;#{color}m#{no_color}\e[0;#{ANSI_COLOR_RESET}m"
  end

  def colorized_service_name
    if process
      colorize("#{name} (#{process.pid})")
    else
      colorize("#{name}")
    end
  end

  def wait
    if loaded_cue
      raise(ServiceDidntStart) unless watch_for_cue
      start_output_stream_thread
    else
      start_output_stream_thread
      begin
        if pid_file
          wait_for_server_with_timeout
        else
          TCPSocket.wait_for_service_with_timeout({:host => host, :port => port, :timeout => timeout})
        end
      rescue SocketError
        raise ServiceDidntStart
      end
    end
    true
  end

  def wait_for_server_with_timeout
    Timeout::timeout(timeout) do
      sleep 0.25 while !running_via_pid_file?
    end
  end
end
