module PoParser
  # Split a PO file into single PO message entities (a message is seperated by two newline)
  class Tokenizer
    @messages = [] of Message
    getter :messages

    @file_path : String
    getter :file_path

    def initialize(path : String)
      raise FileNotExistsError.new(path) unless File.file? path
      @file_path = path
    end

    def parse
      File.read(file_path, "UTF-8").split("\n\n") do |block|
        # Dont parse empty blocks
        messages << Parser.new(block).parse unless block.blank?
      end if messages.empty?

      messages
    end
  end
end
