package main

import (
	"os"
	"strings"
	"testing"
)

func TestRenderProviderTemplateUsesForkRepository(t *testing.T) {
	content, err := os.ReadFile("provider.yaml")
	if err != nil {
		t.Fatalf("read provider template: %v", err)
	}

	got, err := renderProviderTemplate(string(content), "v0.11.1-guru.1", "guru3s/devpod-provider-azure")
	if err != nil {
		t.Fatalf("renderProviderTemplate() unexpected error: %v", err)
	}

	const forkURL = "github.com/guru3s/devpod-provider-azure/releases/download/v0.11.1-guru.1/"
	if count := strings.Count(got, forkURL); count != 7 {
		t.Fatalf("fork release URL count = %d, want 7", count)
	}
	if strings.Contains(got, "github.com/loft-sh/devpod-provider-azure/releases/download/") {
		t.Fatal("rendered provider still points to upstream release binaries")
	}
	if strings.Contains(got, "##REPO##") || strings.Contains(got, "##VERSION##") {
		t.Fatal("rendered provider contains unresolved repository or version placeholder")
	}
}

func TestRenderProviderTemplateRejectsInvalidRepository(t *testing.T) {
	invalidRepositories := []string{
		"guru3s",
		"https://github.com/guru3s/devpod-provider-azure",
		"guru3s/devpod-provider-azure/extra",
		"guru3s/devpod provider azure",
	}

	for _, repo := range invalidRepositories {
		t.Run(repo, func(t *testing.T) {
			if _, err := renderProviderTemplate("##REPO##/##VERSION##", "v0.11.1-guru.1", repo); err == nil {
				t.Fatalf("renderProviderTemplate() accepted invalid repository %q", repo)
			}
		})
	}
}
