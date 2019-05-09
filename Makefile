test : src/test.cr src/index.cr
	crystal src/test.cr

csup : src/csup.cr
	crystal build src/csup.cr
