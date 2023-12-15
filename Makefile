% : test/%.cr
	crystal build $<

.PHONY: tests
tests : keymap_test ncurses_test email_test

keymap_test : test/keymap_test.cr
ncurses_test : test/ncurses_test.cr src/supcurses.cr
email_test : test/email_test.cr

test : src/test.cr src/index.cr
	crystal build src/test.cr

csup : src/csup.cr
	crystal build src/csup.cr
