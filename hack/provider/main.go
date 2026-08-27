package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"
)

const defaultProviderRepository = "loft-sh/devpod-provider-azure"

var providerRepositoryPattern = regexp.MustCompile(`^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`)

var checksumMap = map[string]string{
	"./release/devpod-provider-azure-linux-amd64":       "##CHECKSUM_LINUX_AMD64##",
	"./release/devpod-provider-azure-linux-arm64":       "##CHECKSUM_LINUX_ARM64##",
	"./release/devpod-provider-azure-darwin-amd64":      "##CHECKSUM_DARWIN_AMD64##",
	"./release/devpod-provider-azure-darwin-arm64":      "##CHECKSUM_DARWIN_ARM64##",
	"./release/devpod-provider-azure-windows-amd64.exe": "##CHECKSUM_WINDOWS_AMD64##",
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "Expected version as argument")
		os.Exit(1)
		return
	}

	repo := os.Getenv("PROVIDER_REPO")
	if repo == "" {
		repo = defaultProviderRepository
	}

	content, err := os.ReadFile("./hack/provider/provider.yaml")
	if err != nil {
		panic(err)
	}

	replaced, err := renderProviderTemplate(string(content), os.Args[1], repo)
	if err != nil {
		panic(err)
	}

	for k, v := range checksumMap {
		checksum, err := File(k)
		if err != nil {
			panic(fmt.Errorf("generate checksum for %s: %v", k, err))
		}

		replaced = strings.Replace(replaced, v, checksum, -1)
	}

	fmt.Print(replaced)
}

func renderProviderTemplate(content, version, repo string) (string, error) {
	if version == "" {
		return "", fmt.Errorf("version must not be empty")
	}

	if !providerRepositoryPattern.MatchString(repo) {
		return "", fmt.Errorf("invalid PROVIDER_REPO %q: expected GitHub owner/repository", repo)
	}

	replaced := strings.ReplaceAll(content, "##VERSION##", version)
	replaced = strings.ReplaceAll(replaced, "##REPO##", repo)
	return replaced, nil
}

// File hashes a given file to a sha256 string
func File(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := sha256.New()
	_, err = io.Copy(hash, file)
	if err != nil {
		return "", err
	}

	return strings.ToLower(hex.EncodeToString(hash.Sum(nil))), nil
}
