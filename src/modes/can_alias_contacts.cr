require "../contact.cr"

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

end
