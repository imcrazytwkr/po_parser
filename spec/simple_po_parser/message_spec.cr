require "../spec_helper"

describe PoParser::Message do
  it "treats unset fields as nil" do
    message = PoParser::Message.new
    message.message_id.should be_nil
    message.message_id?.should be_false
    message.empty?.should be_true
    message.message_plural?.should be_false
  end

  it "skips assigning an empty first value" do
    message = PoParser::Message.new
    message.message_id = ""
    message.message_id?.should be_false
  end

  it "concatenates a later assignment with a space" do
    message = PoParser::Message.new
    message.message_id = "foo"
    message.message_id = "bar"
    message.message_id.should eq("foo bar")
    message.empty?.should be_false
  end

  it "uses a paragraph break for an empty later assignment" do
    message = PoParser::Message.new
    message.message_id = "foo"
    message.message_id = ""
    message.message_id.should eq("foo")
  end

  it "tracks plural messages" do
    message = PoParser::Message.new
    message.message_plural << "one"
    message.message_plural?.should be_true
    message.empty?.should be_false
  end
end
