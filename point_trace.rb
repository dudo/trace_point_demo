require 'bundler'
Bundler.require
require 'securerandom'

KEEP_GEMS = Bundler.load.require(:default) \
                   .reject { |dep| (dep.groups & %i[test development]).any? } \
                   .map(&:name) \
                   .join('|')
CALLER_APP_REGEX = /demo\.rb/

Thread.current[:spans] = {}
trace = TracePoint.new(:call, :return, :raise) do |tp|
  case tp.path
  when /demo\.rb/
    type, service, version = :method, 'app', '1a42d39'
  when /#{KEEP_GEMS}/
    puts '------------'
    type, service, version = :import, $1, $2
    next unless caller[1][CALLER_APP_REGEX, 1] || tp.event == :raise
  else
    next
  end

  name = "#{tp.self.is_a?(Module) ? "#{tp.self}." : "#{tp.defined_class}#"}#{tp.method_id}"

  case tp.event
  when :call
    Thread.current[:spans][name] = {
      name: name,
      trace_id: Thread.current[:trace_id],
      caller_name: Thread.current[:caller_name],
      type: type,
      service: service,
      version: version,
      location: "#{tp.path}:#{tp.lineno}"
    }.tap do |span|
      tp.self.method(tp.method_id).parameters.map(&:last).map do |n|
        span[:arguments] = {}
        span[:arguments][n] = tp.binding.eval(n.to_s)
      end
    end
    Thread.current[:caller_name] = name
  when :return
    next unless (span = Thread.current[:spans][name])
    next if span.key?(:exception)

    Thread.current[:caller_name] = nil

    puts span.compact
  when :raise
    span = Thread.current[:spans][name] || {}
    span[:name] ||= name
    span[:trace_id] ||= Thread.current[:trace_id]
    span[:caller_name] ||= Thread.current[:caller_name] unless name == Thread.current[:caller_name]
    span[:type] ||= type
    span[:service] ||= service
    span[:version] ||= version
    span[:location] ||= "#{tp.path}:#{tp.lineno}"
    span[:exception] = tp.raised_exception
    tp.self.method(tp.method_id).parameters.map(&:last).map do |n|
      span[:arguments] = {}
      span[:arguments][n] = tp.binding.eval(n.to_s)
    end

    puts span.compact
  end
end
trace.enable
