test:
	./bin/kat fek.txt
dev:
	go run ./cmd/main.go
build:
	go build -o ./bin/kat ./cmd/main.go