require "../spec_helper"

describe PoParser do
  it "parses a po file" do
    messages = PoParser.parse_file(PO_FILE)
    messages.should be_a(Array(PoParser::Message))
    messages.size.should be > 1

    header = messages.first
    header.flag.should eq("fuzzy")
    header.message_id?.should be_false
  end

  it "parses a non ascii po file" do
    messages = PoParser.parse_file(NON_ASCII_FILE)
    messages.should be_a(Array(PoParser::Message))
    messages.any? { |m| m.message.try(&.includes?("آفریقایی")) }.should be_true
  end

  it "parses a crlf encoded po file" do
    messages = PoParser.parse_file(CRLF_FILE)
    messages.should be_a(Array(PoParser::Message))
    messages.size.should be > 0
  end

  it "parses a single message" do
    PoParser.parse_message(PO_COMPLEX_MESSAGE).should be_a(PoParser::Message)
  end

  it "parses a message that uses crlf line endings" do
    result = PoParser.parse_message("msgid \"a\"\r\nmsgstr \"b\"\r\n")
    result.message_id.should eq("a")
    result.message.should eq("b")
  end

  it "raises FileNotExistsError when the path is missing" do
    path = "/tmp/po_parser_missing_#{Process.pid}.po"
    expect_raises(PoParser::FileNotExistsError, /#{Regex.escape(path)}/) do
      PoParser.parse_file(path)
    end
  end
end
