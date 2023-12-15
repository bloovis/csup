% : test/%.cr
	crystal build --no-color --error-trace $<

.PHONY: tests
tests : colormap_test keymap_test ncurses_test email_test

colormap_test : test/colormap_test.cr src/colormap.cr
keymap_test : test/keymap_test.cr src/keymap.cr
ncurses_test : test/ncurses_test.cr src/supcurses.cr
email_test : test/email_test.cr

test : src/test.cr src/index.cr
	crystal build src/test.cr

csup : src/csup.cr
	crystal build src/csup.cr
