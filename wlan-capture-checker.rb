require "json"

class WlanCaptureChecker
  def initialize ifnames, duration=10
    @ifnames = ifnames.split(",").map{|elm| if elm.empty? then nil else elm end}.compact
    @duration = duration.to_i
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
    system("touch #{name}")
    system("chmod +w #{name}")

    return name
  end

  def run_tshark ifname, fname
    system("tshark -i #{ifname} -w #{fname} -a duration:#{duration}")
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
  end
end

if __FILE__ == $0
  ifnames = ARGV.shift
  channel = ARGV.shift
  checker = WlanCaptureChecker.new(ifnames, channel)
end
