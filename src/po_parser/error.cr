module PoParser
	class ParserError < Exception
	end

	class PoSyntaxError < ParserError
		def initialize(message : String = "Invalid Po syntax", cause : Exception? = nil)
			super message, cause
		end
	end

  class FileNotExistsError < ParserError
    def initialize(file_name : String)
      super "File '#{file_name}' doesn't exist"
    end
  end

	class MessageIndexError < ParserError
	end
end
