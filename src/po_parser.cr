require "./po_parser/*"

module PoParser
  extend self

  # Parses Po file
  #
  # returns an array of Po messages as hashes
  def parse_file(file_path : String)
    Tokenizer.new(file_path).parse
  end

  # Parses a single message
  #
  # returns a hash of Po message
  def parse_message(message : String)
    Parser.new(message).parse
  end
end
