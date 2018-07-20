require "json"

class WlanChannelChecker
  CHANNEL = [
    # 2.4GHz
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,

    # 5GHz: W52 & J52 or U-NII-1
    34, 36, 38, 40, 42, 44, 46, 48,

    # 5GHz: W53 or U-NII-2A
    52, 56, 60, 64,

    # 5GHz: W56 or U-NII-2C
    100, 104, 108, 112, 116,
    120, 124, 128, 132, 136, 140,

    # 5GHz: W58 or U-NII-3
    144, 149, 153, 157, 161, 165, 169, 173,

    # 4.9GHz
    184, 188, 192, 196
  ]
  CHANNEL_IDX_LIMIT=CHANNEL.length
  DEFAULT_IFNAME="wlan0"

  def initialize ifname=DEFAULT_IFNAME
    @ifname = ifname.to_s
    check_privilege()
    init_device()
    @results = {}
  rescue => e
    STDERR.puts e.message
    exit 1
  end

  def check_privilege()
    unless Process.uid == 0
      raise "not executed with root privilege"
    end
  end

  def init_device()
    unless @ifname.match(/^wlan\d+$/) or @ifname.match(/^wlp\d+s\d+$/)
      raise "ERROR: non-wlan device"
    end

    unless execute_cmd("ip link set #{@ifname} down")
      raise "failed to turn down #{@ifname}"
    end

    unless execute_cmd("iw #{@ifname} set monitor fcsfail otherbss control")
      raise "failed to set #{@ifname} to monitor mode"
    end

    unless execute_cmd("ip link set #{@ifname} up")
      raise "failed to turn up #{@ifname}"
    end
  end

  def check_channels
    prev_channel = 0
    CHANNEL.each do |new_channel|
      result = move_channel(prev_channel, new_channel)
      @results[new_channel] = result
      prev_channel = new_channel
    end
  end

  def json_result
    return JSON.pretty_generate(@results)
  end

  def move_channel current_channel, next_channel
    STDERR.print "channel move #{current_channel} => #{next_channel}: "

    cmd_result = execute_cmd("iw #{@ifname} set channel #{next_channel}")
    STDERR.print "command=#{cmd_result ? "success" : "failed"}, "

    info_result = (next_channel == check_current_channel())
    STDERR.print "info=#{info_result ? "success" : "failed"}"

    puts("")
    return cmd_result & info_result
  end

  def check_current_channel
    lines = `iw #{@ifname} info`
    channel = lines.split("\n").map{|elm| if elm.match(/\s+channel (\d+) /) then $1.to_i else nil end }.compact.shift
    return channel.to_i
  end

  def execute_cmd str
    return system("#{str} 2>/dev/null")
  end
end

if __FILE__ == $0
  checker = WlanChannelChecker.new(ARGV.shift)
  checker.check_channels()
  puts checker.json_result()
end
