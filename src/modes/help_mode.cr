require "./text_mode"

module Redwood

class HelpMode < TextMode
  def initialize(mode : Mode, global_keymap : Keymap)
    title = "Help for #{mode.name}"
    super <<-EOS
#{title}
#{"=" * title.length}

#{mode.help_text}
Global keybindings
------------------
#{global_keymap.help_text}
EOS
  end
end

end

