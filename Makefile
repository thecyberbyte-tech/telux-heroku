APP_NAME := telux-heroku
APP_DESCRIPTION := $$(awk 'NR == 11, NR == 13' README.md)
APP_URL := https://github.com/thecyberbyte/$(APP_NAME)
APP_MAINTAINER := $$(git show HEAD | awk '$$1 == "Author:" {print $$2 " " $$3 " " $$4}')
GIT_TAG := $$(git describe --tags --abbrev=0)

run:
	go run . $${TB_ROOT:+-root-users=$$TB_ROOT} \
        -add-exit \
        -log-commands \
        -persistent-users \
        /date:desc="Get current date" date \
        /:plain_text:desc="Numbers via cat -n" 'cat -n' \
        /alarm:vars=SLEEP,MSG 'sleep $$SLEEP; echo Hello $$S2T_USERNAME, $$MSG'

build:
	go build

test:
	go test -race -cover -v ./...

lint:
	golint ./...
	go vet ./...
	errcheck ./...

update-from-github:
	go get -u github.com/thecyberbyte/$(APP_NAME)

build-docker-image:
	docker run --rm -v $$PWD:/go/src/$(APP_NAME) -w /go/src/$(APP_NAME) golang:alpine sh -c "apk add --no-cache git && go get ./... && go build -ldflags='-w -s' -o $(APP_NAME)"
	docker build -t msoap/$(APP_NAME):latest .
	rm -f $(APP_NAME)

gometalinter:
	gometalinter --vendor --cyclo-over=25 --line-length=150 --dupl-threshold=150 --min-occurrences=3 --enable=misspell --deadline=10m --exclude=SA1022

generate-manpage:
	cat README.md | grep -v "^\[" | perl -pe 's/\<img.+\>//' > $(APP_NAME).md
	docker run --rm -v $$PWD:/app -w /app msoap/ruby-ronn ronn $(APP_NAME).md
	mv ./$(APP_NAME) ./$(APP_NAME).1
	rm ./$(APP_NAME).{md,html}

create-debian-amd64-package:
	GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o $(APP_NAME)
	docker run --rm -v $$PWD:/app -w /app msoap/ruby-fpm \
		fpm -s dir -t deb --force --name $(APP_NAME) -v $(GIT_TAG) \
			--license="$$(head -1 LICENSE)" \
			--url=$(APP_URL) \
			--description="$(APP_DESCRIPTION)" \
			--maintainer="$(APP_MAINTAINER)" \
			--category=network \
			./$(APP_NAME)=/usr/bin/ \
			./$(APP_NAME).1=/usr/share/man/man1/ \
			LICENSE=/usr/share/doc/$(APP_NAME)/copyright \
			README.md=/usr/share/doc/$(APP_NAME)/
	rm $(APP_NAME)
