require "./line_cursor_mode"
require "../contact"
require "./person_search_results_mode"

module Redwood

module CanAliasContacts
  def alias_contact(p : Person)
    aalias = BufferManager.ask(:alias, "Alias for #{p.longname}: ", ContactManager.alias_for(p))
    return if aalias.nil?
    #aalias = nil if aalias.empty? # allow empty aliases

    name = BufferManager.ask(:name, "Name for #{p.longname}: ", p.name)
    return if name.nil? || name.empty? # don't allow empty names
    p.name = name

    ContactManager.update_alias p, aalias
    BufferManager.flash "Contact updated!"
  end
end

class ContactListMode < LineCursorMode
  mode_class load_more, reload, edit_alias, toggle_tagged, apply_to_tagged, search,
	     multi_toggle_tagged, multi_search, select_item, multi_select_item

  LOAD_MORE_CONTACTS_NUM = 100

  register_keymap do |k|
    k.add :load_more, "Load #{LOAD_MORE_CONTACTS_NUM} more contacts", 'M'
    k.add :reload, "Drop contact list and reload", 'D'
    k.add :edit_alias, "Edit alias/or name for contact", 'a', 'i'
    k.add :toggle_tagged, "Tag/untag current line", 't'
    k.add :apply_to_tagged, "Apply next command to all tagged items", '+', '='
    k.add :search, "Search for messages from particular people", 'S'
  end

  @user_contacts = Array(Person).new
  @contacts = Array(Person).new
  @num : Int32 = 0
  @awidth = 0
  @nwidth = 0
  @text = TextLines.new

  def initialize(mode=:regular)
    @mode = mode
    @tags = Tagger(Person).new
    @tags.setmode(self)
    @num = 0
    @text = TextLines.new
    load_in_background
    super()
  end

  include CanAliasContacts
  def edit_alias(*args)
    return unless p = @contacts[curpos]
    alias_contact p
    update
  end

  def lines; @text.size; end
  def [](i); @text[i]; end

  def toggle_tagged(*args)
    return unless p = @contacts[curpos]
    @tags.toggle_tag_for p
    update_text_for_line curpos
    cursor_down
  end

  def multi_toggle_tagged(*args)
    @tags.drop_all_tags
    update
  end

  def apply_to_tagged(*args)
    @tags.apply_to_tagged
  end

  def load_more(*args)
    arg = args[0]?
    if arg && arg.is_a?(Int32)
      num = arg
    else
      num = LOAD_MORE_CONTACTS_NUM
    end
    @num += num
    load
    update
    BufferManager.flash "Added #{num.pluralize "contact"}."
  end

  def do_multi_select(people : Array(Person))
    case @mode
    when :regular
      mode = ComposeMode.new(Opts.new({:to => people.map{|p| p.full_address}}))
      BufferManager.spawn "new message", mode
      mode.default_edit_message
    end
  end

  def multi_select_item(*args)
    do_multi_select(@tags.all)
  end

  def select_item(*args)
    return unless p = @contacts[curpos]
    do_multi_select([p])
  end

  def do_multi_search(people : Array(Person))
    mode = PersonSearchResultsMode.new people
    BufferManager.spawn "search for #{people.map { |p| p.name }.join(", ")}", mode
    #mode.load_threads(Opts.new({:num => mode.buffer.content_height}))
  end

  def multi_search(*args)
    do_multi_search(@tags.all)
  end

  def search(*args)
    return unless p = @contacts[curpos]
    do_multi_search([p])
  end

  def reload(*args)
    @tags.drop_all_tags
    @num = 0
    load
  end

  def load_in_background
    #Redwood::reporting_thread("contact manager load in bg") do
      load
      update
      BufferManager.draw_screen
    #end
  end

  def load
    @num ||= (buffer.content_height * 2)
    @user_contacts = ContactManager.contacts_with_aliases
    #@user_contacts += (HookManager.run("extra-contact-addresses") || []).map { |addr| Person.from_address addr }
    num = [@num - @user_contacts.length, 0].max
    BufferManager.say("Loading #{num} contacts from index...") do
      recentc = Notmuch.load_contacts AccountManager.user_emails, num
      @contacts = (@user_contacts + recentc).sort_by { |p| p.sort_by_me }.uniq
    end
  end

#protected

  def update
    regen_text
    buffer.mark_dirty if buffer
  end

  def update_text_for_line(line)
    @text[line] = text_for_contact @contacts[line]
    buffer.mark_dirty if buffer
  end

  def text_for_contact(p)
    aalias = ContactManager.alias_for(p) || ""
    [{:tagged_color, @tags.tagged?(p) ? ">" : " "},
     {:text_color, sprintf("%-#{@awidth}s %-#{@nwidth}s %s", aalias, p.name, p.email)}]
  end

  def regen_text
    @awidth, @nwidth = 0, 0
    @contacts.each do |p|
      aalias = ContactManager.alias_for(p)
      @awidth = aalias.length if aalias && aalias.length > @awidth
      if name = p.name
	@nwidth = name.length if name.length > @nwidth
      end
    end

    #@text = @contacts.map { |p| text_for_contact p }
    @text = TextLines.new
    @contacts.each do |p|
      @text << text_for_contact p
    end
  end
end

end
