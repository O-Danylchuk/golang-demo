FROM golang:1.21-alpine AS build

RUN apk add --no-cache postgresql-client

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN ls -al /app

RUN go install github.com/gravityblast/fresh@latest

EXPOSE 8080

CMD ["fresh"]
