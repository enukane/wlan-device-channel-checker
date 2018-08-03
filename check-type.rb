FNAME=ARGV.shift

cmd = "tshark -e wlan.fc.type -Tfields -r #{FNAME}"
io = IO.popen(cmd)
data = io.read
io.close

lines = data.split("\n")
num2type = {
  2 => "Data",
  1 => "Control",
  0 => "Management",
  nil => nil
}
type_histogram = {}
num2type.values.each do |val|
  type_histogram[val] = 0
end
lines.each do |line|
  num = line.strip.to_i
  type = num2type[num]
  type_histogram[num2type[num]] += 1
end

p "### check type"
p "total => #{type_histogram.values.inject(:+)}"
p type_histogram


## check ht
cmd = "tshark -Tfields -Eseparator=, -e wlan_radio.11n.mcs_index -e wlan_radio.data_rate -r #{FNAME}"
io = IO.popen(cmd)
lines = io.read.split("\n")
io.close

mcshash = {}
nsshash = {}
ratehash = {}

def nmcs2nss idx
  if idx >= 0 and idx <= 7
    return 1
  elsif idx >= 8 and idx <= 15
    return 2
  elsif idx >= 16 and idx <= 23
    return 3
  elsif idx >= 24 and idx <= 31
    return 4
  end

  return 0
end

class Hash
  def countup(elm)
    if self[elm].nil?
      self[elm] = 0
    end

    self[elm] += 1
  end
  def to_s
    str = "{ "
    first = true
    self.keys.sort.each do |key|
      unless first
        str += ", "
      end
      str += "#{key} => #{self[key]}"
      first = false
    end
    str += " }"

    str
  end
end

lines.each do |line|
  mcs, rate = line.split(",")
  if mcs == ""
    next
  end
  mcshash.countup(mcs.to_i)
  nsshash.countup(nmcs2nss(mcs.to_i))
  ratehash.countup(rate.to_i)
end

p "### check ht"
p"totalframes => #{mcshash.values.inject(:+)}"
p "mcs => #{mcshash}"
p "nss => #{nsshash}"
p "rate => #{ratehash}"

## check vht
cmd = "tshark -Tfields -Eseparator=, -e wlan_radio.11ac.mcs -e wlan_radio.11ac.nss -e wlan_radio.data_rate -r #{FNAME}"
io = IO.popen(cmd)
lines = io.read.split("\n")
io.close

ac_mcshash = {}
ac_nsshash = {}
ac_ratehash = {}

lines.each do |line|
  mcs, nss, rate = line.split(",")
  if mcs == ""
    next
  end
  ac_mcshash.countup(mcs.to_i)
  ac_nsshash.countup(nss.to_i)
  ac_ratehash.countup(rate.to_i)
end

p "### check vht"
p"totalframes => #{ac_mcshash.values.inject(:+)}"
p "ac_mcs => #{ac_mcshash}"
p "ac_nss => #{ac_nsshash}"
p "ac_rate => #{ac_ratehash}"
