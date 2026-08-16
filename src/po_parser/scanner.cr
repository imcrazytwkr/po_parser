require "string_scanner"

module PoParser
  # Extending native StringScanner to add some methods that were not implemented in Crystal
  # for some reason
  class Scanner < StringScanner
    # Returns true if the scan pointer is at the beginning of the line.
    def bol?
      offset == 0 || @str[offset - 1] == '\n'
    end

    # Scans one character and returns it. This method is multibyte character sensitive.
    def get_char
      return nil if eos?

      position = offset
      char = @str[position]
      # Instead of calling `self.offset=`, variable assignment takes place; have to use self
      # explicilty to overcome it
      self.offset = position + 1
      char
    end
  end
end
