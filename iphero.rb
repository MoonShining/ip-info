require 'ipaddr'
require 'csv'

class IPDB
  def initialize path
    @ip_db_path ||= File.expand_path path
  end

  def ip_db
    @ip_db ||= File.open @ip_db_path, 'rb'
  end

  def offset
    @offset ||= ip_db.read(4).unpack("Nlen")[0]
  end

  def index
    @index ||= ip_db.read(offset - 4)
  end

  def max_comp_length
    @max_comp_length ||= offset - 1028
  end

  def seek(_offset, length)
    IO.read(@ip_db_path, length, offset + _offset - 1024).split "\t"
  end

  def position ip_first, ip
    tmp_offset = ip_first * 4
    start = index[tmp_offset..(tmp_offset + 3)].unpack("V")[0] * 8 + 1024
    while start < max_comp_length
      if index[start..(start + 3)] >= [IPAddr.new(ip).to_i].pack('N')
        break
      end
      start += 8
    end
    start
  end

  def write_to_file
    start_byte = position(0, "0.0.0.0") #1024
    end_byte = position(255, "255.255.255.255") #1633320

    ips = []
    range = start_byte..end_byte
    range.step(8) {|i| 
      ip_int = index[i..(i + 3)].unpack("N")[0]
      ip_dot = "#{(ip_int >> 24) & 0xff}.#{(ip_int >> 16) & 0xff}.#{(ip_int >> 8) & 0xff}.#{ip_int & 0xff}"
      index_offset = "#{index[(i + 4)..(i + 6)]}\x0".unpack("V")[0]
      index_length = index[(i + 7)].unpack("C")[0]
      result = seek(index_offset, index_length).map do |str|
        str.encode("UTF-8", "UTF-8")
      end
      result[1] = '' if result.size < 2
      result[2] = '' if result.size < 3
      
      ips << [ip_int, ip_dot, result[0], result[1], result[2]]
    }
    CSV.open("./ips.csv", "wb") do |csv|
      ips.each { |ip| csv << ip }
    end
  end
end

IPDB.new('./17monipdb.dat').write_to_file