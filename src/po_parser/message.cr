module PoParser
  class Message
  {% for name in {
    "translator_comment",
    "extracted_comment",
    "reference",
    "flag",
    "obsolete",
    "previous_message_context",
    "previous_message_id_plural",
    "previous_message_id",
    "message_context",
    "message_id_plural",
    "message_id",
    "message"
  } %}
    @{{name.id}} : String?

    def {{name.id}}
      @{{name.id}}.not_nil!.rstrip
    rescue
      nil
    end

    def {{name.id}}?
      @{{name.id}}.not_nil!
      true
    rescue
      false
    end

    def {{name.id}}=(value : String)
      # I so wish there was `.strip!` in Crystal...
      value = value.strip
      old_value = @{{name.id}}.not_nil!

      if value.empty?
        @{{name.id}} = "#{old_value}\n\n"
      elsif !old_value.ends_with? value
        # No reason to add word separator since we already have line separator
        value = " #{value}" unless old_value.ends_with?("\n\n")
        @{{name.id}} = old_value + value
      end
    rescue
      @{{name.id}} = value unless value.empty?
    ensure
      @{{name.id}}
    end
  {% end %}

    @message_plural = [] of String
    getter :message_plural

    def message_plural?
      !@message_plural.empty?
    end

    def empty?
    {% for name in {
      "translator_comment",
      "extracted_comment",
      "reference",
      "flag",
      "obsolete",
      "previous_message_context",
      "previous_message_id_plural",
      "previous_message_id",
      "message_context",
      "message_id_plural",
      "message_id",
      "message"
    } %}
      return false if {{name.id}}?
    {% end %}
      message_plural.empty?
    end
  end
end
