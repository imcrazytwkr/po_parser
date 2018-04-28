module PoParser
  # Fast parser directly using Crystal's powerful StringScanner
  #
  # Important notes about `StringScanner.scan`:
  # * Scan will return nil if there is no match. Using the regex * (zero or more) quantifier
  #   will let scan return an empty string if there is "no match" as the empty string
  #   qualifies as a match of the regex (zero times). We make use of this "trick".
  # * The start of line anchor ^ is obsolete as scan will only match start of line.
  # * Ruby's (and by extension, Crystal's) regex is in single-line mode by default, therefore
  #   scan will only match until the next newline is hit unless multi-line mode is explicitly
  #   enabled.
  class Parser
    @scanner : Scanner
    private getter :scanner

    @result : Message
    private getter :result

    # Single message parser class.
    #
    # @param message [String] a single PO message in String format without leading or trailing
    #                         whitespace
    def initialize(message : String)
      @scanner = Scanner.new message.strip
      @result = Message.new
    end

    # Parses the message of the PO format.
    #
    # @return [Hash(Symbol, String|Hash(UInt32, String))] PO message parsed into Hash format
    def parse
      # Returning cached response to avoid parsing the same message multiple times
      return result unless result.empty?
      lines
      result
    rescue err : ParserError
      message  = "SimplePoParser::ParserError #{err.message.to_s.strip}\n"
      message += "Parsing result before error: '#{result.to_s}'\n"
      message += "SimplePoParser backtrace: SimplePoParser::ParserError"
      raise ParserError.new(message, err)
    end

    #########################################
    ###            branching              ###
    #########################################

    # Arbitary line of a PO message. Can be either a comment or a message.
    # Message parsing is always started with checking for msgctxt as content is expected in
    # `msgctxt -> msgid -> msgid_plural -> msgstr` order.
    private def lines
      scanner.scan(/#/) ? comment : msgctxt
    rescue err : PoSyntaxError
      # Throw a normal ParserError to break the recursion
      raise ParserError.new("Syntax error in lines\n#{err.message}", err)
    end

    # Match a comment line. Called on lines starting with '#'.
    # Recalls line when the comment line was parsed.
    private def comment
      case scanner.get_char
      when ' '
        skip_whitespace
        result.translator_comment = comment_text
        lines
      when '.'
        skip_whitespace
        result.extracted_comment = comment_text
        lines
      when ':'
        skip_whitespace
        result.reference = comment_text
        lines
      when ','
        skip_whitespace
        result.flag = comment_text
        lines
      when '|'
        skip_whitespace
        previous_comments
        lines
      when '\n'
        skip_whitespace
        # Empty comment line
        lines
      when '~'
        previous = result_has_previous?
        if previous
          message  = "Previous comment entries need to be marked obsolete too in obsolete "
          message += "message entries. But already got #{previous}"
          raise PoSyntaxError.new(message)
        end

        scanner.offset = scanner.offset - 2
        result.obsolete = obsoletes
      else
        scanner.offset = scanner.offset - 2
        raise PoSyntaxError.new("Unknown comment type #{scanner.peek(10).inspect}")
      end
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in comment\n#{err.message}", err)
    end

    # Matches the msgctxt line and will continue to check for msgid afterwards
    #
    # msgctxt is optional
    private def msgctxt
      if scanner.scan(/msgctxt/)
        skip_whitespace
        text = message_line
        result.message_context = text.empty? ? message_multiline : text
      end

      msgid
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in msgctxt\n#{err.message}", err)
    end

    # matches the msgid line. Will check for optional msgid_plural.
    # Will advance to msgstr or msgstr_plural based on msgid_plural
    #
    # msgid is required
    private def msgid
      if scanner.scan(/msgid/)
        skip_whitespace
        text = message_line
        result.message_id = text.empty? ? message_multiline : text
        return msgid_plural? ? msgstr_plural : msgstr
      end

      message  = "Message without msgid is not allowed. "
      message += "The Line started unexpectedly with #{scanner.peek(10).inspect}."
      raise PoSyntaxError.new(message)
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in msgid\n#{err.message}", err)
    end

    # matches the msgid_plural line.
    #
    # msgid_plural is optional
    #
    # @return [boolean] true if msgid_plural is present, false otherwise
    private def msgid_plural?
      return false unless scanner.scan(/msgid_plural/)

      skip_whitespace
      text = message_line
      result.message_id_plural = text.empty? ? message_multiline : text
      true
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in msgid\n#{err.message}", err)
    end

    # parses the msgstr singular line
    #
    # msgstr is required in singular translations
    private def msgstr
      if scanner.scan(/msgstr/)
        skip_whitespace
        text = message_line
        result.message = text.empty? ? message_multiline : text

        skip_whitespace
        unless scanner.eos?
          message  = "Unexpected content after expected message end "
          message += scanner.peek(10).inspect
          raise PoSyntaxError.new(message)
        end

        return nil
      else
        message  = "Singular message without msgstr is not allowed. Line started "
        message += "unexpectedly with ##{scanner.peek(10).inspect}"
        raise PoSyntaxError.new(message)
      end
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in msgstr\n#{err.message}", err)
    end

    # parses the msgstr plural lines
    #
    # msgstr plural lines are used when there is msgid_plural.
    # They have the format msgstr[N] where N is incremental number starting from zero
    # representing the plural number as specified in the headers "Plural-Forms" entry.
    # Most languages, like English, only have two plural forms (singular and plural),
    # but there are languages with more plurals
    private def msgstr_plural
      msg_length = result.message_plural.size
      # Matching 'msgstr[0]' to 'msgstr[255]':
      if scanner.scan(/msgstr\[(\d{1,2}|1\d{2}|2[0-5]{2})\]/)
        msgstr_num = scanner[1].to_u8

        unless msgstr_num == msg_length
          if msgstr_num > msg_length
            # msgstr plurals must come in 0-based index in strict order
            message  = "Received text for message \##{msgstr_num} before text for message \#"
            message += msg_length.to_s
            raise MessageIndexError.new(message)
          end

          raise PoSyntaxError.new("Bad 'msgstr[index]' index: #{msgstr_num}")
        end

        skip_whitespace
        text = message_line
        result.message_plural << (text.empty? ? message_multiline : text)
        msgstr_plural
      elsif msg_length == 0 # and no `msgstr_key` was found
        message  = "Plural message without msgstr[0] is not allowed. Line started "
        message += "unexpectedly with #{scanner.peek(10).inspect}"
        raise PoSyntaxError.new(message)
      elsif !scanner.eos?
        message  = "End of message was expected, but line started unexpectedly with "
        scanner.offset = scanner.offset - 10
        message += scanner.peek(20).inspect
        raise PoSyntaxError.new(message)
      end
    rescue err : MessageIndexError
      raise PoSyntaxError.new("Message Index error in msgstr_plural\n#{err.message}", err)
    rescue err
      raise PoSyntaxError.new("Syntax error in msgstr_plural\n#{err.message}", err)
    end

    # parses previous comments, which provide additional information on fuzzy matching
    #
    # previous comments are:
    # * #| msgctxt
    # * #| msgid
    # * #| msgid_plural
    private def previous_comments
      unless scanner.scan(/msg/)
        # Тext part must be msgctxt, msgid or msgid_plural
        message  = "Previous comments must start with '#| msg'; "
        message += "#{scanner.peek(10).inspect} unknown"
        raise PoSyntaxError.new(message)
      end

      key = case
      when scanner.scan(/id/)
        scanner.scan(/_plural/) ? :previous_msgid_plural : :previous_msgid
      when scanner.scan(/ctxt/)
        :previous_msgctxt
      else
        message = "Previous comment type #{("msg" + scanner.peek(10)).inspect} unknown."
        raise PoSyntaxError.new(message)
      end

      skip_whitespace
      text = message_line
      text = previous_multiline if text.empty?

      case key
      when :previous_msgid
        result.previous_message_id = text
      when :previous_msgid_plural
        result.previous_message_id_plural = text
      when :previous_msgctxt
        result.previous_message_context = text
      end
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in previous_comments\n#{err.message}", err)
    end

    # Parses the multiline messages of the previous comment lines
    private def previous_multiline(contents = "")
      # Scan multilines until no further multiline is hit. `/#\|\p{Blank}"/` needs to catch
      # the double quote to ensure it hits a previous multiline and not another line type.
      if scanner.scan(/#\|[ \t]*"/)
        # Go one character back, so we can reuse the "message line" method
        scanner.offset = scanner.offset - 1
        # Go on until we no longer hit a multiline line
        return previous_multiline(contents += message_line)
      end

      return contents
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in previous_multiline\n#{err.message}", err)
    end

    # parses a multiline message
    #
    # multiline messages are indicated by an empty content as first line and the next line
    # starting with the double quote character
    private def message_multiline(message = "")
      skip_whitespace
      scanner.check(/"/) ? message_multiline(message += message_line) : message
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in message_multiline\n#{err.message}", err)
    end

    # Identifies a message line and returns it's text or raises an error
    #
    # @return [String] message_text
    private def message_line
      unless scanner.get_char == '"'
        scanner.offset = scanner.offset - 1
        message  = "A message text needs to start with the double quote character '\"', "
        message += "but this was found: #{scanner.peek(10).inspect}"
        raise PoSyntaxError.new(message)
      end

      text = message_text
      unless scanner.get_char == '"'
        message  = "The message text '#{text}' must be finished with the double quote "
        message += "character '\"'"
        raise PoSyntaxError.new(message)
      end

      skip_whitespace
      unless end_of_line
        message  = "There should be only whitespace until the end of line "
        message += "after the double quote character of a message text. #{scanner.peek(10)}"
        raise PoSyntaxError.new(message)
      end

      # Necessary to return empty string instead of nil to avoid breaking the return type
      text.to_s
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in message_line\n#{err.message}", err)
    end

    # Parses all obsolete lines
    # An obsolete message may only contain obsolete lines
    private def obsoletes(contents = "")
      if scanner.scan(/#~/)
        skip_whitespace
        return obsoletes(contents + comment_text)
      end

      return contents if scanner.eos?

      message  = "All lines must be obsolete after the first obsolete line, but got: "
      message += scanner.peek(10).inspect
      raise PoSyntaxError.new(message)
    end

    #########################################
    ###             scanning              ###
    #########################################

    # Returns the text of a comment
    #
    # @return [String] text
    private def comment_text
      # Everything until newline
      text = scanner.scan(/.*/).not_nil!
      return text.rstrip if end_of_line

      raise PoSyntaxError.new("Comment text should advance to next line or stop at eos")
      text
    rescue err : PoSyntaxError
      raise PoSyntaxError.new("Syntax error in commtent_text\n${err.message}", err)
    end

    # Returns the text of a message line
    #
    # @return [String] text
    private def message_text
      # Parses anything until an unescaped quote is hit
      scanner.scan_until(/(\\(\\|")|[^"])*/)
    end

    # Advances the scanner until the next non whitespace position
    # Does not match newlines
    private def skip_whitespace
      scanner.skip(/\s+/)
    end

    # returns true if the scanner is at beginning of next line or end of string
    #
    # @return [Boolean] true if scanner at beginning of line or eos
    private def end_of_line
      scanner.scan(/\n/)
      scanner.eos? || scanner.bol?
    end

    # Checks whether key(s) had already been set
    private def result_has_previous?
      case result
        when .previous_message_context? then "previous message context"
        when .previous_message_id_plural? then "previous message id plural"
        when .previous_message_id? then "previous message id"
        else false
      end
    end
  end
end
