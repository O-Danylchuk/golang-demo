FROM golang:1.21-alpine AS build

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN go install github.com/gravityblast/fresh@latest

EXPOSE 8080

CMD ["fresh"]
