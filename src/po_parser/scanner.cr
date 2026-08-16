require "string_scanner"

module PoParser
  # Polyfill for 1.21 `StringScanner` methods missing on older Crystal versions
  class Scanner < StringScanner
    def beginning_of_line? : Bool
      return false if eos?

      offset == 0 || string[offset - 1] == '\n'
    end

    def current_char? : Char?
      return nil if eos?

      string[offset]
    end

    def current_char : Char
      current_char? || raise IndexError.new
    end

    def rewind(len : Int) : Nil
      new_offset = offset - len
      raise IndexError.new("Index out of range") if new_offset < 0

      self.offset = new_offset
    end

    def scan(len : Int) : String?
      return "" if len == 0

      remaining = string.size - offset
      return nil if remaining < len

      start = offset
      self.offset = start + len
      string[start, len]
    end

    def skip(len : Int) : Int32?
      scan(len).try(&.size)
    end

    def scan(pattern : Char) : String?
      return nil unless current_char? == pattern

      scan(1)
    end

    def check(pattern : Char) : String?
      current_char? == pattern ? pattern.to_s : nil
    end

    def skip(pattern : Char) : Int32?
      scan(pattern).try(&.size)
    end
  end
end
