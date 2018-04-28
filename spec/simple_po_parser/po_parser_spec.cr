require "../spec_helper"

describe PoParser do
  it "parses a po file" do
    PoParser.parse_file(PO_FILE).should be_a(Array(PoParser::Message))
  end

  it "parses a non ascii po file" do
    PoParser.parse_file(NON_ASCII_FILE).should be_a(Array(PoParser::Message))
  end

  it "parses a single message" do
    PoParser.parse_message(PO_COMPLEX_MESSAGE).should be_a(PoParser::Message)
  end
end
