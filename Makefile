% : test/%.cr
	crystal build --no-color --error-trace $<

.PHONY: tests
tests : colormap_test keymap_test ncurses_test email_test logger_test \
        undo_test update_test tagger_test hook_test

colormap_test : test/colormap_test.cr src/colormap.cr src/supcurses.cr
keymap_test : test/keymap_test.cr src/keymap.cr src/buffer.cr src/mode.cr
ncurses_test : test/ncurses_test.cr src/supcurses.cr
email_test : test/email_test.cr
logger_test : test/logger_test.cr src/logger.cr
undo_test : test/undo_test.cr src/undo.cr
update_test : test/update_test.cr src/update.cr
tagger_test : test/tagger_test.cr src/tagger.cr
hook_test : test/hook_test.cr src/hook.cr

test : src/test.cr src/index.cr
	crystal build src/test.cr

csup : src/csup.cr
	crystal build src/csup.cr
