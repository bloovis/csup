# encoding: UTF-8

require "./shellwords"
require "./message"

## Here we define all the "chunks" that a message is parsed
## into. Chunks are used by ThreadViewMode to render a message. Chunks
## are used for both MIME stuff like attachments, for Sup's parsing of
## the message body into text, quote, and signature regions, and for
## notices like "this message was decrypted" or "this message contains
## a valid signature"---basically, anything we want to differentiate
## at display time.
##
## A chunk can be inlineable, expandable, or viewable. If it's
## inlineable, #color and #lines are called and the output is treated
## as part of the message text. This is how Text and one-line Quotes
## and Signatures work.
##
## If it's not inlineable but is expandable, #patina_color and
## #patina_text are called to generate a "patina" (a one-line widget,
## basically), and the user can press enter to toggle the display of
## the chunk content, which is generated from #color and #lines as
## above. This is how Quote, Signature, and most widgets
## work. Exandable chunks can additionally define #initial_state to be
## :open if they want to start expanded (default is to start collapsed).
##
## If it's not expandable but is viewable, a patina is displayed using
## #patina_color and #patina_text, but no toggling is allowed. Instead,
## if #view! is defined, pressing enter on the widget calls view! and
## (if that returns false) #to_s. Otherwise, enter does nothing. This
##  is how non-inlineable attachments work.
##
## Independent of all that, a chunk can be quotable, in which case it's
## included as quoted text during a reply. Text, Quotes, and mime-parsed
## attachments are quotable; Signatures are not.

module Redwood

# Base class for Chunks.  Should never be instantiated directly.
class Chunk
  # Initialized by the constructor.
  property type : Symbol

  # Properties initialized by subclasses.
  property lines = [] of String
  property initial_state = :closed
  property color = :text_color
  # patina color and text are used only if expandable? is true
  property patina_color = :text_color
  property patina_text = "Chunk"
  property quotable = false

  # Boolean methods to be overridden by subclasses
  def inlineable?; false end
  def quotable?; @quotable end
  def expandable?; false end
  def viewable?; false end

  def initialize(@type)
  end
end

class AttachmentChunk < Chunk
  property part : Message::Part
  property message : Message

  def initialize(@part : Message::Part, @message : Message)
    super(:attachment)

    @color = :text_color
    @patina_color = :attachment_color
    @patina_text = "Attachment: #{part.filename} (#{part.content_type}) ; #{part.content.size.to_human_size})"
    @initial_state = :open

    text = ""
    success = HookManager.run("mime-decode") do |pipe|
      pipe.send do |f|
	f.puts(@part.content_type)
	f << @part.content
      end
      pipe.receive do |f|
	text = f.gets_to_end
      end
    end
    if !success || text.size == 0
      text = "mime-decode hook not implemented for part #{@part.id}, #{@part.content_type}.\n"
    end

    if text && text.size > 0
      @lines = text.gsub("\r\n", "\n").gsub(/\t/, "        ").gsub(/\r/, "").split("\n")
      @quotable = true
    else
      @lines = [] of String
    end
  end

  ## an attachment is expandable if we've managed to decode it into
  ## something we can display inline. otherwise, it's viewable.
  def inlineable?; false end
  def viewable?; lines.size > 0 end
  def expandable?; !viewable? end

  def filename
    @part.filename
  end

  def safe_filename
    Shellwords.escape(filename).gsub("/", "_")
  end

  ## an attachment is expandable if we've managed to decode it into
  ## something we can display inline. otherwise, it's viewable.
  def view!
    Notmuch.view_part(@message.id, @part.id, @part.content_type)
  end

  def save(filename : String)
    Notmuch.save_part(@message.id, @part.id, filename)
  end

  ## used when viewing the attachment as text
  def to_s
    # What should we use for raw_content?  Does it make sense to use part.content
    # when that could be binary data like JPEG?
    @lines # || @raw_content
  end
end

class TextChunk < Chunk
  def initialize(@lines)
    super(:text)
    ## trim off all empty lines except one
    while @lines.length > 1 && @lines[-1] =~ /^\s*$/ && @lines[-2] =~ /^\s*$/
      @lines.pop
    end

    @color = :text_color
  end

  def inlineable?; true end
  def quotable?; true end
  def expandable?; false end
  def indexable?; true end
  def viewable?; false end
end

class QuoteChunk < Chunk
  def initialize(@lines)
    super(:quote)
    @patina_color = :quote_patina_color
    @patina_text = "(#{@lines.size} quoted lines)"
    @color = :quote_color
  end

  def inlineable?; @lines.length == 1 end
  def quotable?; true end
  def expandable?; !inlineable? end
  def viewable?; false end
end

class SignatureChunk < Chunk
  def initialize(@lines)
    super(:sig)
    @patina_color = :sig_patina_color
    @patina_text = "(#{lines.size}-line signature)"
    @color = :sig_color
  end

  def inlineable?; @lines.length == 1 end
  def quotable?; false end
  def expandable?; !inlineable? end
  def viewable?; false end
end

end	# Redwood
