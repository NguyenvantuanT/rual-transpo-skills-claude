### Go

- Lệnh: `go build ./...` · test: `go test ./...` · generate: `go generate ./...`. Hook Stop chạy `gofmt`, `go vet`, `golangci-lint` (nếu có) và `go test` cho package đổi.
- Tự kiểm chứng API: chạy server rồi gọi endpoint bằng curl, đọc log.
