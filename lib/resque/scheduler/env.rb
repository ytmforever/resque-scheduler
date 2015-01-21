# vim:fileencoding=utf-8

module Resque
  module Scheduler
    class Env
      def initialize(options)
        @options = options
      end

      def setup
        require 'resque'
        require 'resque/scheduler'

        setup_backgrounding
        setup_pid_file
        setup_scheduler_configuration
      end

      private

      attr_reader :options

      def setup_backgrounding
        # Need to set this here for conditional Process.daemon redirect of
        # stderr/stdout to /dev/null
        Resque::Scheduler.quiet = !!options[:quiet]

        if options[:background]
          unless Process.respond_to?('daemon')
            abort 'background option is set, which requires ruby >= 1.9'
          end

          Process.daemon(true, !Resque::Scheduler.quiet)
          Resque.redis.client.reconnect
        end
      end

      def setup_pid_file
        # File.open(options[:pidfile], 'w') do |f|
        #   f.puts $PROCESS_ID
        # end if options[:pidfile]
        manage_pidfile(options[:pidfile])
      end
      def manage_pidfile(pidfile)
        return unless pidfile
        pid = Process.pid
        if File.exist? pidfile
          if process_still_running? pidfile
            raise "Pidfile already exists at #{pidfile} and process is still running."
          else
            File.delete pidfile
          end
        else
          FileUtils.mkdir_p File.dirname(pidfile)
        end
        File.open pidfile, "w" do |f|
          f.write pid
        end
        at_exit do
          if Process.pid == pid
            File.delete pidfile
          end
        end
      end

      def process_still_running?(pidfile)
        old_pid = open(pidfile).read.strip.to_i
        Process.kill 0, old_pid
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      rescue ::Exception => e
        $stderr.puts "While checking if PID #{old_pid} is running, unexpected #{e.class}: #{e}"
        true
      end

      def setup_scheduler_configuration
        Resque::Scheduler.configure do |c|
          # These settings are somewhat redundant given the defaults present
          # in the attr reader methods.  They are left here for clarity and
          # to serve as an example of how to use `.configure`.

          c.app_name = options[:app_name]
          c.dynamic = !!options[:dynamic]
          c.env = options[:env]
          c.logfile = options[:logfile]
          c.logformat = options[:logformat]
          c.poll_sleep_amount = Float(options[:poll_sleep_amount] || '5')
          c.verbose = !!options[:verbose]
        end
      end
    end
  end
end
