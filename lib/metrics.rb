require 'mysql'
require 'net/http'

class MetricNotAvailable < RuntimeError
end

module Metrics
  def apache_active_workers
    from_apache_mod_status("BusyWorkers").to_i
  end

  def apache_idle_workers
    from_apache_mod_status("IdleWorkers").to_i
  end
  
  def filesystem_space
    `df -kP | grep "^/"`.split(/\n/).collect do |line|
      fields = line.split(/\s+/)
      device = fields[0].split(/\//).last
      used = fields[1].to_i - fields[3].to_i
      [device, (used.to_f / fields[1].to_f * 100).round]
    end
  end
  
  def load_1m
    IO.read('/proc/loadavg').split(/\s/)[0]
  end
  
  def mem_free
    from_proc_meminfo('MemFree').gsub(" kB$", '').to_i
  end
  
  def mem_total
    from_proc_meminfo('MemTotal').gsub(" kB$", '').to_i
  end
  
  def slave_lag
    begin
      db = Mysql.new('localhost', '', '', '')
      db.query('show slave status') do |result|
        result.fetch_hash['Seconds_Behind_Master']
      end
    rescue Mysql::Error
      raise MetricNotAvailable
    end
  end
  
  def swap_free
    from_proc_meminfo('SwapFree').gsub(" kB$", '').to_i
  end
  
  def swap_total
    from_proc_meminfo('SwapTotal').gsub(" kB$", '').to_i
  end

  private
  
  def from_apache_mod_status(string)
    begin
      response = Net::HTTP.get_response('localhost', '/server-status?auto')
      if response.code == '200' then
        response.body.split(/\n/).detect {|line| line =~ /^#{Regexp.quote(string)}: (.*)/}
        $1
      else
        raise MetricNotAvailable
      end
    rescue Errno::ECONNREFUSED
      raise MetricNotAvailable
    end
  end

  def from_proc_meminfo(string)
    IO.read('/proc/meminfo').split(/\n/).detect {|line| line =~ /^#{Regexp.quote(string)}:\s+(.*)/}
    $1
  end
end
