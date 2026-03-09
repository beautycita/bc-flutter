FLUTTER := /home/bc/flutter/bin/flutter

test:
	$(FLUTTER) test --reporter=compact

test-unit:
	$(FLUTTER) test test/models test/services test/repositories test/providers test/config --reporter=compact

test-coverage:
	$(FLUTTER) test --coverage --reporter=compact

test-file:
	$(FLUTTER) test $(FILE) --reporter=expanded
