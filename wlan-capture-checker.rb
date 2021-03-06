require "json"

class WlanCaptureChecker
  def initialize ifnames, channel=36, duration=10
    @ifnames = ifnames.split(",").map{|elm| if elm.empty? then nil else elm end}.compact
    @channel = channel.to_i
    @duration = duration.to_i
    STDERR.puts "ifnames = #{ifnames}, duration = #{duration}"
    check_privilege
    @ifnames.each do |ifname|
      init_device(ifname)
    end
  rescue => e
    STDERR.puts e.message
    exit 1
  end

  def check_privilege()
    unless Process.uid == 0
      raise "not executed with root privilege"
    end
  end

  def generate_filename ifname
    now = Time.now.strftime("%Y%m%d-%H%M%S")
    name = "#{now}.#{ifname}.pcapng"
    execute_cmd("touch #{name}")
    execute_cmd("chmod +w #{name}")

    return name
  end

  def run_tshark ifname, fname
    STDERR.puts "start capturing #{ifname} to '#{fname}'"
    execute_cmd("tshark -i #{ifname} -w #{fname} -a duration:#{@duration}")
  end

  def run
    threads = []
    fnames = []
    @ifnames.each do |ifname|
      fname = generate_filename(ifname)
      fnames << fname
      threads << Thread.new do
        run_tshark(ifname, fname)
      end
    end

    threads.each do |thr|
      thr.join
    end
  end

  def init_device(ifname)
    unless ifname.match(/^wlan\d+$/) or ifname.match(/^wlp\d+s\d+$/) or ifname.match(/^wlx.+$/)
      raise "ERROR: non-wlan device"
    end

    unless execute_cmd("ip link set #{ifname} down")
      raise "failed to turn down #{ifname}"
    end

    unless execute_cmd("iw #{ifname} set monitor fcsfail otherbss control")
      raise "failed to set #{ifname} to monitor mode"
    end

    unless execute_cmd("ip link set #{ifname} up")
      raise "failed to turn up #{ifname}"
    end

    unless execute_cmd("iw #{ifname} set channel #{@channel}")
      raise "failed to set #{ifname} to channel #{@channel}"
    end
  end

  def execute_cmd str
    return system("#{str} 2>/dev/null")
  end
end

if __FILE__ == $0
  ifnames = ARGV.shift
  channel = ARGV.shift || 36
  duration = ARGV.shift || 10
  checker = WlanCaptureChecker.new(ifnames, channel, duration)
  checker.run
end
