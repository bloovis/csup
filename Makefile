.PHONY: guide guideview tests

% : test/%.cr
	crystal build --no-color --error-trace -D TEST $<

csup : $(wildcard src/*.cr) $(wildcard src/modes/*.cr)
	crystal build --no-color --error-trace -D MAIN src/csup.cr


guide :
	(cd guide && hugo)

guideview :
	(cd guide && hugo server)

.PHONY: tests
tests : colormap_test keymap_test ncurses_test email_test logger_test \
        undo_test update_test tagger_test hook_test config_test \
	contact_test account_test opts_test notmuch_test message_test \
	search_test time_test string_test label_test person_test \
	notmuch_save_part notmuch_view_part notmuch_write_part \
	scroll_mode_test line_cursor_mode_test thread_index_mode_test \
	inbox_mode_test

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
notmuch_test : test/notmuch_test.cr src/notmuch.cr src/pipe.cr
message_test : test/message_test.cr src/notmuch.cr src/pipe.cr src/message.cr
search_test : test/search_test.cr src/search.cr
time_test : test/time_test.cr src/time.cr
string_test : test/string_test.cr src/unicode.cr src/util.cr
label_test : test/label_test.cr src/label.cr
person_test : test/person_test.cr src/person.cr

notmuch_save_part : test/notmuch_save_part.cr src/notmuch.cr
notmuch_view_part : test/notmuch_view_part.cr src/notmuch.cr
notmuch_write_part : test/notmuch_write_part.cr src/notmuch.cr

# Mode tests
scroll_mode_test : test/scroll_mode_test.cr src/modes/scroll_mode.cr src/buffer.cr
line_cursor_mode_test : test/line_cursor_mode_test.cr src/modes/line_cursor_mode.cr src/buffer.cr
thread_index_mode_test : test/thread_index_mode_test.cr src/modes/thread_index_mode.cr src/buffer.cr \
			 src/modes/thread_view_mode.cr
inbox_mode_test : test/inbox_mode_test.cr src/modes/thread_index_mode.cr src/buffer.cr \
			 src/modes/thread_view_mode.cr src/modes/inbox_mode.cr
hs_test : test/hs_test.cr src/horizontal_selector.cr src/modes/scroll_mode.cr

test : src/test.cr src/notmuch.cr
	crystal build --no-color --error-trace src/test.cr
