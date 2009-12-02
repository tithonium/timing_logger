unless defined?(METRICS_LOGGER)
  begin
    log_path = File.join(Rails.configuration.root_path, 'log', "#{Rails.configuration.environment}_metrics.log")
    logger = ActiveSupport::BufferedLogger.new(log_path)
    logger.level = ActiveSupport::BufferedLogger::INFO
    if Rails.configuration.environment == "production"
      logger.auto_flushing = false
    end
  rescue StandardError => e
    logger = ActiveSupport::BufferedLogger.new(STDERR)
    logger.level = ActiveSupport::BufferedLogger::DEBUG
    logger.warn(
      "Rails Error: Unable to access metrics log file. Please ensure that #{log_path} exists and is chmod 0666. " +
      "The output directed to STDERR until the problem is fixed."
    )
  end
  silence_warnings { Object.const_set "METRICS_LOGGER", logger }
end
module TimingLogger
  def self.log(type, description, &block)
    start_time = Time.now
    ret = yield block
    finish_time = Time.now
    METRICS_LOGGER.info %Q[#{type}\t#{start_time.strftime('%d %b %Y %H:%M:%S')}\t#{"%.3f" % (finish_time.to_f - start_time.to_f)}s\t#{description}]
    ret
  end
  
  def self.wrap_function(klass, function)
    toeval=<<-"EVAL"
      def #{function}_with_timing *args, &block
        TimingLogger::log("FUNCTION", "#{function}(\#{args.inspect})") { #{function}_without_timing(*args, &block) }
      end
      alias_method_chain :#{function.to_sym}, :timing
    EVAL
    klass.class_eval toeval
  end

  module Controller
    def self.included(base)
      base.extend(ClassMethods)
    end
    def action_timing_wrapper &block
      TimingLogger::log("ACTION", params.inspect, &block)
    end
    def time_block type="BLOCK", desc=nil, &block
      TimingLogger::log(type, desc, &block)
    end
    module ClassMethods
      def time_actions *args
        options = {}
        options[:only] = args unless args.empty?
        around_filter :action_timing_wrapper, options
      end
    end
  end
end
