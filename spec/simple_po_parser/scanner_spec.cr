require "../spec_helper"

describe PoParser::Scanner do
  describe "#beginning_of_line?" do
    it "is true at the start of input that is not empty" do
      scanner = PoParser::Scanner.new("ab")
      scanner.beginning_of_line?.should be_true
    end

    it "is true after a newline when more text remains" do
      scanner = PoParser::Scanner.new("a\nb")
      scanner.scan('a')
      scanner.scan('\n')
      scanner.beginning_of_line?.should be_true
      scanner.current_char?.should eq('b')
    end

    it "is false at end of string" do
      scanner = PoParser::Scanner.new("a\n")
      scanner.scan('a')
      scanner.scan('\n')
      scanner.eos?.should be_true
      scanner.beginning_of_line?.should be_false
    end
  end

  describe "#current_char" do
    it "peeks without advancing" do
      scanner = PoParser::Scanner.new("ab")
      scanner.current_char?.should eq('a')
      scanner.current_char.should eq('a')
      scanner.offset.should eq(0)
    end

    it "returns nil and raises at end of string" do
      scanner = PoParser::Scanner.new("")
      scanner.current_char?.should be_nil
      expect_raises(IndexError) { scanner.current_char }
    end
  end

  describe "#rewind" do
    it "moves the offset back by the given number of characters" do
      scanner = PoParser::Scanner.new("abc")
      scanner.scan(2)
      scanner.rewind(1)
      scanner.offset.should eq(1)
      scanner.current_char?.should eq('b')
    end

    it "raises when rewinding past the start" do
      scanner = PoParser::Scanner.new("ab")
      expect_raises(IndexError) { scanner.rewind(1) }
    end
  end

  describe "#scan(Int)" do
    it "returns an empty string for a zero length scan" do
      scanner = PoParser::Scanner.new("ab")
      scanner.scan(0).should eq("")
      scanner.offset.should eq(0)
    end

    it "does not advance when not enough characters remain" do
      scanner = PoParser::Scanner.new("ab")
      scanner.scan(3).should be_nil
      scanner.offset.should eq(0)
    end

    it "advances by character, including multibyte characters" do
      scanner = PoParser::Scanner.new("あいう")
      scanner.scan(2).should eq("あい")
      scanner.offset.should eq(2)
    end
  end

  describe "#skip(Int)" do
    it "skips the given number of characters" do
      scanner = PoParser::Scanner.new("abc")
      scanner.skip(2).should eq(2)
      scanner.current_char?.should eq('c')
    end

    it "returns nil when not enough characters remain" do
      scanner = PoParser::Scanner.new("a")
      scanner.skip(2).should be_nil
      scanner.offset.should eq(0)
    end
  end

  describe "Char patterns" do
    it "scans a matching character" do
      scanner = PoParser::Scanner.new("ab")
      scanner.scan('a').should eq("a")
      scanner.offset.should eq(1)
    end

    it "does not advance on a mismatched scan" do
      scanner = PoParser::Scanner.new("ab")
      scanner.scan('x').should be_nil
      scanner.offset.should eq(0)
    end

    it "checks without advancing" do
      scanner = PoParser::Scanner.new("ab")
      scanner.check('a').should eq("a")
      scanner.check('x').should be_nil
      scanner.offset.should eq(0)
    end

    it "skips a matching character" do
      scanner = PoParser::Scanner.new("ab")
      scanner.skip('a').should eq(1)
      scanner.skip('x').should be_nil
      scanner.offset.should eq(1)
    end
  end
end
