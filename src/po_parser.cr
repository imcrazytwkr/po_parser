require "./po_parser/*"

module PoParser
  extend self

  # Parses a PO file.
  #
  # Returns an array of messages.
  def parse_file(file_path : String)
    Tokenizer.new(file_path).parse
  end

  # Parses a single message.
  #
  # Returns a message.
  def parse_message(message : String)
    Parser.new(message).parse
  end
end
