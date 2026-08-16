require "../spec_helper"

describe PoParser::Parser do
  it "parses the PO header" do
    result = PoParser::Parser.new(PO_HEADER).parse

    # Actual tests
    result.should be_a(PoParser::Message)

    result.translator_comment?.should be_true
    result.translator_comment.should eq("PO Header entry")

    result.flag?.should be_true
    result.flag.should eq("fuzzy")

    # Empty ID must not be set!
    result.message_id?.should be_false

    result.message?.should be_true
    result.message.should eq({
      "Project-Id-Version: simple_po_parser 1\\n",
      "Report-Msgid-Bugs-To: me\\n"
    }.join)
  end

  it "parses the simple entry as expected" do
    result = PoParser::Parser.new(PO_SIMPLE_MESSAGE).parse

    # Actual tests
    result.should be_a(PoParser::Message)

    result.translator_comment?.should be_true
    result.translator_comment.should eq("translator-comment")

    result.extracted_comment?.should be_true
    result.extracted_comment.should eq("extract")

    result.reference?.should be_true
    result.reference.should eq("reference1")

    result.message_context?.should be_true
    result.message_context.should eq("Context")

    result.message_id?.should be_true
    result.message_id.should eq("msgid")

    result.message?.should be_true
    result.message.should eq("translated")
  end

  it "parses the complex entry as expected" do
    result = PoParser::Parser.new(PO_COMPLEX_MESSAGE).parse

    # Actual tests
    result.should be_a(PoParser::Message)

    result.translator_comment?.should be_true
    # Message#{{parameter}} method returns rstripped string value so empty line is discarded
    result.translator_comment.should eq("translator-comment")

    result.extracted_comment?.should be_true
    result.extracted_comment.should eq("extract")

    result.reference?.should be_true
    # Multiline entries are treated Markdown style, meaning you have to add an empty line in
    # the entry for it to work as a line separator
    result.reference.should eq("reference1 reference2")

    result.flag?.should be_true
    result.flag.should eq("flag")

    result.previous_message_context?.should be_true
    result.previous_message_context.should eq("previous context")

    result.previous_message_id?.should be_true
    result.previous_message_id.should eq({
      "multiline\\n",
      "previous messageid"
    }.join)

    result.previous_message_id_plural?.should be_true
    result.previous_message_id_plural.should eq("previous msgid_plural")

    result.message_context?.should be_true
    result.message_context.should eq("Context")

    result.message_id?.should be_true
    result.message_id.should eq("msgid")

    result.message_id_plural?.should be_true
    result.message_id_plural.should eq("multiline msgid_plural\\n")

    result.message_plural?.should be_true
    result.message_plural[0].should eq("msgstr 0")
    result.message_plural[1].should eq({
      "msgstr 1 multiline 1\\n",
      "msgstr 1 line 2\\n"
    }.join)
    result.message_plural[2].should eq("msgstr 2")
  end

  context "Errors" do
    it "cascade to ParseError" do
      expect_raises(PoParser::ParserError) do
        PoParser::Parser.new("invalid message").parse
      end
    end

    it "are raised if there is no msgid" do
      err = /Message without msgid is not allowed/
      message = "# comment\nmsgctxt \"ctxt\"\nmsgstr \"translation\""
      expect_raises(PoParser::ParserError, err) do
        PoParser::Parser.new(message).parse
      end
    end

    it "are raised if there is no msgstr in singular message" do
      err = /Singular message without msgstr is not allowed/
      message = "# comment\nmsgctxt \"ctxt\"\nmsgid \"msg\""
      expect_raises(PoParser::ParserError, err) do
        PoParser::Parser.new(message).parse
      end
    end

    it "are raised if there is no msgstr[0] in plural message" do
      err = /Plural message without msgstr\[0\] is not allowed/
      message = "# comment\nmsgid \"id\"\nmsgid_plural \"msg plural\""
      expect_raises(PoParser::ParserError, err) do
        PoParser::Parser.new(message).parse
      end

      # MessageIndex Error proxying
      err = /Received text for message #1 before text for message #0/
      message =  "# comment\nmsgid \"id\"\nmsgid_plural \"msg plural\"\nmsgstr[1] \"plural "
      message += "trans\""
      expect_raises(PoParser::ParserError, err) do
        PoParser::Parser.new(message).parse
      end
    end

    context "comments" do
      it "are raised on unknown comment types" do
        err = /Unknown comment type/
        message = "#- no such comment type"
        expect_raises(PoParser::ParserError, err) do
          PoParser::Parser.new(message).parse
        end
      end

      it "are raised on unknown previous comment types" do
        err = /Previous comment type .*? unknown/
        message = "#| msgstr \"no such comment type\""
        expect_raises(PoParser::ParserError, err) do
          PoParser::Parser.new(message).parse
        end

        err = /Previous comments must start with '#| msg'/
        message = "#| bla "
        expect_raises(PoParser::ParserError, err) do
          PoParser::Parser.new(message).parse
        end
      end

      it "are raised when lines are not marked obsolete after the first obsolete line" do
        err = /All lines must be obsolete after the first obsolete line, but got/
        message = "# comment\n#~msgid \"hi\"\nmsgstr \"should be obsolete\""
        expect_raises(PoParser::ParserError, err) do
          PoParser::Parser.new(message).parse
        end
      end

      it "are raised if previous comments are not marked as obsolete in obsolete entries" do
        err = /Previous comment entries need to be marked obsolete too in obsolete message/
        message  = "# comment\n#| msgid \"hi\"\n#~msgid \"hi\"\n#~msgstr \"should be "
        message += "obsolete\""
        expect_raises(PoParser::ParserError, err) do
          PoParser::Parser.new(message).parse
        end

        message  = "# comment\n#| msgctxt \"hi\"\n#~msgid \"hi\"\n#~msgstr \"should be "
        message += "obsolete\""
        expect_raises(PoParser::ParserError, err) do
          PoParser::Parser.new(message).parse
        end
      end
    end

    context "message_line" do
      it "are raised if a message_line does not start with a double quote" do
        err = /A message text needs to start with the double quote character/
        message = "msgid No starting double quote\""
        expect_raises(PoParser::ParserError, err) do
          PoParser::Parser.new(message).parse
        end
      end

      it "are raised if a message_line does not end with a double quote" do
        err = /The message text .*? must be finished with the double quote character/
        message = "msgid \"No ending double quote"
        expect_raises(PoParser::ParserError, err) do
          PoParser::Parser.new(message).parse
        end
      end

      it "are raised if there is anything but whitespace after the ending double quote" do
        err = /There should be only whitespace until the end of line after the double quote/
        message = "msgid \"text\"        this shouldn't be here"
        expect_raises(PoParser::ParserError, err) do
          PoParser::Parser.new(message).parse
        end
      end
    end
  end
end
