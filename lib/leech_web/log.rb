require "leech_web/config"

module LeechWeb
  module Log
    def self.start
      $stdout.sync = $stderr.sync = true
      @mutex = Mutex.new
      log(ns: "log", fn: "start")
    end

    def self.unparse(data)
      data.map do |(k, v)|
        if (v == true)
          k.to_s
        elsif (v == false)
          "#{k}=false"
        elsif (v.is_a?(String) && v.include?("\""))
          "#{k}='#{v}'"
        elsif (v.is_a?(String) && (v !~ /^[a-zA-Z0-9\:\.\-\_]+$/))
          "#{k}=\"#{v}\""
        elsif (v.is_a?(String) || v.is_a?(Symbol))
          "#{k}=#{v}"
        elsif v.is_a?(Float)
          "#{k}=#{format("%.3f", v)}"
        elsif v.is_a?(Numeric) || v.is_a?(Class) || v.is_a?(Module)
          "#{k}=#{v}"
        elsif v.is_a?(Time)
          "#{k}=\"#{v}\""
        end
      end.compact.join(" ")
    end

    def self.write(data)
      msg = unparse(data)
      @mutex.synchronize { $stdout.puts(msg) }
    end

    def self.merge(data1, data2)
      data1.to_a + data2.to_a
    end

    def self.log(data, &blk)
      if blk
        start = Time.now
        ret = nil
        log(merge(data, at: "start"))
        begin
          ret = yield
        rescue StandardError, Timeout::Error => e
          log(merge(data, at: "exception", reraise: "true", class: e.class, message: e.message, exception_id: e.object_id.abs, elapsed: (Time.now - start)))
          raise(e)
        end
        log(merge(data, at: "finish", elapsed: (Time.now - start)))
        ret
      else
        write(merge({app: "leech-web", deploy: Config.deploy}, data))
      end
    end

    def self.log_exception(data, e)
      log(merge(data, exception: true, class: e.class, message: e.message, exception_id: e.object_id.abs))
      e.backtrace.reverse.each do |line|
        log(merge(data, exception:true, exception_id: e.object_id.abs, site: line.gsub(/[`'"]/, "")))
      end
    end
  end
end
