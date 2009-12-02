require File.join(File.dirname(__FILE__), *%w[.. lib timing_logger])

ActionController::Base.send :include, TimingLogger::Controller

RAILS_DEFAULT_LOGGER.info("** TimingLogger: initialized properly")