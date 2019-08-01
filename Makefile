.PHONY: serve
serve: 
	gitbook serve . ./_book

.PHONY: build
build:
	gitbook build . ./_book
