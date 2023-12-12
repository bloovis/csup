% : test/%.cr
	crystal build $<

keymap_test : test/keymap_test.cr
ncurses_test : test/ncurses_test.cr

test : src/test.cr src/index.cr
	crystal build src/test.cr

csup : src/csup.cr
	crystal build src/csup.cr
