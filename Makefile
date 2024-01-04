% : test/%.cr
	crystal build --no-color --error-trace $<

.PHONY: tests
tests : colormap_test keymap_test ncurses_test email_test logger_test \
        undo_test update_test tagger_test hook_test config_test \
	contact_test account_test opts_test notmuch_test \
	scroll_mode_test line_cursor_mode_test

# Manager tests
colormap_test : test/colormap_test.cr src/colormap.cr src/supcurses.cr
keymap_test : test/keymap_test.cr src/keymap.cr src/buffer.cr src/mode.cr \
	      src/colormap.cr src/supcurses.cr
ncurses_test : test/ncurses_test.cr src/supcurses.cr
email_test : test/email_test.cr
logger_test : test/logger_test.cr src/logger.cr
undo_test : test/undo_test.cr src/undo.cr
update_test : test/update_test.cr src/update.cr
tagger_test : test/tagger_test.cr src/tagger.cr
hook_test : test/hook_test.cr src/hook.cr
config_test : test/config_test.cr src/config.cr
contact_test : test/contact_test.cr src/contact.cr
account_test : test/account_test.cr src/account.cr
opts_test : test/opts_test.cr src/opts.cr
notmuch_test : test/notmuch_test.cr src/index.cr src/pipe.cr

# Mode tests
scroll_mode_test : test/scroll_mode_test.cr src/modes/scroll_mode.cr src/buffer.cr
line_cursor_mode_test : test/line_cursor_mode_test.cr src/modes/line_cursor_mode.cr src/buffer.cr

test : src/test.cr src/index.cr
	crystal build src/test.cr

csup : src/csup.cr
	crystal build src/csup.cr
