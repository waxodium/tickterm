DIR := $(HOME)/.local/bin
NAME := tickterm

all: build

build:
	nimble build -d:release --verbose

install: build
	@echo "$(NAME) ===> $(DIR)"
	@mkdir -p $(DIR)
	@cp tickterm $(DIR)/$(NAME)
	@chmod +x $(DIR)/$(NAME)

clean:
	rm -f $(NAME)
	rm -rf nimcache/
