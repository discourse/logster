# frozen_string_literal: true

require "bundler/gem_tasks"
require "digest"
require "net/http"
require "rake/testtask"
require "rbconfig"
require "redis"
require "socket"
require "uri"

Rake::TestTask.new do |t|
  t.test_files = FileList["test/**/test_*"].exclude(%r{test/logster/test_railtie\.rb})
end

task(default: :test)

module DevServer
  extend self

  ROOT = File.expand_path(__dir__)
  CLIENT_DIR = File.join(ROOT, "client-app")
  WEBSITE_DIR = File.join(ROOT, "website")
  INSTALL_STAMP = File.join(CLIENT_DIR, "node_modules", ".logster-package-lock.sha256")

  def run
    backend_port = Integer(ENV.fetch("BACKEND_PORT", 9292))
    frontend_port = Integer(ENV.fetch("FRONTEND_PORT", 4200))
    backend_url = "http://127.0.0.1:#{backend_port}"
    frontend_url = "http://127.0.0.1:#{frontend_port}/logs/"
    processes = []

    check_redis!
    check_npm!
    ensure_port_available!(backend_port)
    ensure_port_available!(frontend_port)
    install_frontend_dependencies!
    install_website_dependencies!

    puts "Starting Logster development servers..."
    processes << ["backend", spawn_backend(backend_port)]
    processes << ["frontend", spawn_frontend(frontend_port, backend_url)]

    wait_for!("backend", "#{backend_url}/", processes)
    wait_for!("frontend", frontend_url, processes)

    puts
    puts "Logster is ready at #{frontend_url}"
    puts "Generate rich test data at #{backend_url}/report_error"
    puts "Press Ctrl-C to stop."
    open_browser(frontend_url)

    name, pid = processes.find { |_, process_pid| process_pid == Process.wait } || ["server", nil]
    abort "#{name.capitalize} process #{pid} stopped unexpectedly"
  rescue Interrupt
    puts "\nStopping Logster..."
  ensure
    stop_processes(processes || [])
  end

  private

  def check_redis!
    Redis.new.ping
    puts "✓ Redis is available"
  rescue Redis::BaseError, SystemCallError => error
    abort <<~MESSAGE
      Redis is not available: #{error.message}

      Start Redis, then run `bundle exec rake dev` again.
    MESSAGE
  end

  def check_npm!
    available = system("npm", "--version", out: File::NULL, err: File::NULL)
    unless available
      abort "npm is required. Install the Node version from `.node-version`, then try again."
    end

    puts "✓ npm is available"
  rescue Errno::ENOENT
    abort "npm is required. Install the Node version from `.node-version`, then try again."
  end

  def ensure_port_available!(port)
    socket = Socket.tcp("127.0.0.1", port, connect_timeout: 0.2)
    socket.close
    abort "Port #{port} is already in use. Set #{port == 9292 ? "BACKEND_PORT" : "FRONTEND_PORT"} to use another port."
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
    nil
  end

  def install_frontend_dependencies!
    lockfile = File.join(CLIENT_DIR, "package-lock.json")
    expected = Digest::SHA256.file(lockfile).hexdigest
    current = File.file?(INSTALL_STAMP) ? File.read(INSTALL_STAMP).strip : nil
    return puts("✓ Frontend dependencies are current") if current == expected

    puts "Installing frontend dependencies..."
    abort "`npm ci` failed" unless system("npm", "ci", chdir: CLIENT_DIR)

    File.write(INSTALL_STAMP, expected)
    puts "✓ Frontend dependencies are current"
  end

  def install_website_dependencies!
    gemfile = File.join(WEBSITE_DIR, "Gemfile")
    env = { "BUNDLE_GEMFILE" => gemfile }
    available =
      Bundler.with_unbundled_env do
        system(env, "bundle", "check", chdir: WEBSITE_DIR, out: File::NULL)
      end
    return puts("✓ Website dependencies are current") if available

    puts "Installing website dependencies..."
    installed = Bundler.with_unbundled_env { system(env, "bundle", "install", chdir: WEBSITE_DIR) }
    abort "Website dependency installation failed" unless installed

    puts "✓ Website dependencies are current"
  end

  def spawn_backend(port)
    env = {
      "BUNDLE_GEMFILE" => File.join(WEBSITE_DIR, "Gemfile"),
      "LOGSTER_ENV" => "development",
      "LOGSTER_ENABLE_CUSTOM_PATTERNS_VIA_UI" => "1",
    }
    spawn(
      env,
      "bundle",
      "exec",
      "puma",
      "-p",
      port.to_s,
      "-e",
      "development",
      chdir: WEBSITE_DIR,
      pgroup: true,
    )
  end

  def spawn_frontend(port, backend_url)
    spawn(
      "npm",
      "run",
      "start",
      "--",
      "--port",
      port.to_s,
      "--proxy",
      backend_url,
      chdir: CLIENT_DIR,
      pgroup: true,
    )
  end

  def wait_for!(name, url, processes, timeout: 90)
    uri = URI(url)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

    loop do
      stopped = processes.find { |_, pid| Process.waitpid(pid, Process::WNOHANG) }
      abort "#{stopped.first.capitalize} stopped before #{name} was ready" if stopped

      begin
        response =
          Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 1) do |http|
            http.get(uri.request_uri)
          end
        if response.code.to_i < 500
          puts "✓ #{name.capitalize} is ready"
          return
        end
      rescue SystemCallError, Timeout::Error, EOFError
        # The server is still starting.
      end

      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        abort "Timed out waiting for #{name} at #{url}"
      end
      sleep 0.25
    end
  end

  def open_browser(url)
    return puts("Browser opening disabled; visit #{url}") if ENV["NO_OPEN"] == "1"

    command =
      case RbConfig::CONFIG["host_os"]
      when /darwin/
        ["open", url]
      when /mswin|mingw|cygwin/
        ["cmd", "/c", "start", "", url]
      else
        ["xdg-open", url]
      end

    pid = spawn(*command, out: File::NULL, err: File::NULL)
    Process.detach(pid)
  rescue Errno::ENOENT
    puts "Could not open a browser automatically; visit #{url}"
  end

  def stop_processes(processes)
    processes.reverse_each do |_, pid|
      Process.kill("TERM", -pid)
    rescue Errno::ESRCH
      nil
    end

    remaining = processes.map(&:last)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    while remaining.any? && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      remaining.reject! do |pid|
        Process.waitpid(pid, Process::WNOHANG)
      rescue Errno::ECHILD
        true
      end
      sleep 0.1 if remaining.any?
    end

    remaining.each do |pid|
      Process.kill("KILL", -pid)
      Process.waitpid(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end
end

desc "Start the Logster backend and frontend development servers"
task :dev do
  DevServer.run
end

desc "Deprecated alias for dev"
task client_dev: :dev
