# This code was taking from https://github.com/arcage/crystal-quotedprintable/tree/master
# I was not able to do a 'shards install' on it, due to this error:
#   shard.yml: mapping values are not allowed in this context

module RMail
  module QuotedPrintable

    extend self

    class Error < Exception; end

    class InvalidEncodedData < Error
      def initialize(*data : String | Char)
	super(data.map { |s| "\"#{s.inspect.delete("\"'")}\"" }.join(", "))
      end
    end

    enum CharType
      CR
      LF
      WHITE_SPACE
      PRINTABLE
      EQUAL
      OTHER
    end

    LINE_BREAK      = "\r\n"
    SOFT_LINE_BREAK = "=\r\n"
    MAX_LENGTH      = 76

    def encode(data : String | Enumerable(UInt8))
      String.build do |str|
	encode(data, str)
      end
    end

    def encode(bytes : Enumerable(UInt8), io : IO)
      encode_bytes(bytes, 0, false, io)
    end

    def encode(string : String, io : IO)
      lines = 0
      string.split(/\r?\n/).each do |line|
	io << LINE_BREAK if lines > 0
	chars = Char::Reader.new(line)
	char = chars.current_char
	line_length = 0
	until char == '\0'
	  has_next = (chars.peek_next_char != '\0')
	  char_type = type_of(char)
	  line_length = case char_type
			when CharType::PRINTABLE
			  encode_data(char, line_length, has_next, io)
			when CharType::WHITE_SPACE
			  if has_next
			    encode_data(char, line_length, has_next, io)
			  else
			    encode_bytes(char.bytes, line_length, has_next, io)
			  end
			else
			  encode_bytes(char.bytes, line_length, has_next, io)
			end
	  char = chars.next_char
	end
	lines += 1
      end
    end

    private def encode_bytes(bytes : Enumerable(UInt8), line_length, has_next, io)
      byte_size = bytes.size
      bytes.each_with_index do |byte, i|
	line_length = encode_data("=%02X" % byte, line_length, has_next || i + 1 < byte_size, io)
      end
      line_length
    end

    private def encode_data(data : String | Char, line_length, has_next, io)
      byte_size = data.bytesize
      new_length = line_length + byte_size
      if new_length > MAX_LENGTH || (new_length == MAX_LENGTH && has_next)
	io << SOFT_LINE_BREAK
	line_length = 0
      end
      io << data
      line_length += byte_size
    end

    def decode(data : String) : Bytes
      buf = Pointer(UInt8).malloc(decode_size(data))
      appender = buf.appender
      from_quoted_printable(data) { |byte| appender << byte }
      Slice.new(buf, appender.size.to_i32)
    end

    def decode(data : String, io : IO)
      count = 0
      from_quoted_printable(data) do |byte|
	io.write_byte byte
	count += 1
      end
      io.flush
      count
    end

    def decode_string(data : String, encoding : String = "UTF-8", invalid : Symbol? = nil, line_break : String? = nil) : String
      str = String.new(decode(data), encoding, invalid)
      str = str.gsub(/\r\n/, line_break) if line_break
      str
    end

    private def from_quoted_printable(data : String)
      chars = Char::Reader.new(data)
      char = chars.current_char
      i = 0
      until char == '\0'
	char_type = type_of(char)
	case char_type
	when CharType::PRINTABLE, CharType::WHITE_SPACE, CharType::CR, CharType::LF
	  yield char.ord.to_u8
	  i += 1
	when CharType::EQUAL
	  bstr = "#{chars.next_char}#{chars.next_char}"
	  unless bstr == "\r\n"
	    if bstr =~ /\A[0-9A-fa-f]{2}\z/
	      yield bstr.to_u8(16)
	      i += 1
	    else
	      raise InvalidEncodedData.new("=" + bstr)
	    end
	  end
	else
	  raise InvalidEncodedData.new(char)
	end
	char = chars.next_char
      end
    end

    private def valid_encoded_string!(string : String)
      matched = string.scan(/([^!-~ \t\r\n]|\r[^\n]|[^\r]\n)/).map { |m| m[0] } + string.scan(/=.{2}/).map { |m| m[0] }.select { |s| s !~ /=([0-9A-F]{2}|\r\n)/ }
      unless matched.empty?
	raise matched.map { |s| s.inspect.sub(/\A'/, '"').sub(/'\z/, '"') }.join(", ")
      end
      string
    end

    private def decode_size(string : String)
      soft_line_breaks = string.scan(/=\r\n/).size
      encoded_bytes = string.scan(/=[0-9A-F]{2}/).size
      string.bytesize - soft_line_breaks * 3 - encoded_bytes * 2
    end

    private def type_of(char) : CharType
      case char
      when '!'..'<', '>'..'~'
	CharType::PRINTABLE
      when '='
	CharType::EQUAL
      when ' ', '\t'
	CharType::WHITE_SPACE
      when '\r'
	CharType::CR
      when '\n'
	CharType::LF
      else
	CharType::OTHER
      end
    end

  end
end
