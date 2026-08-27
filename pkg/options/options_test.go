package options

import (
	"strings"
	"testing"
)

func TestParseSSHSourceCIDR(t *testing.T) {
	tests := []struct {
		name    string
		value   string
		want    string
		wantErr string
	}{
		{
			name:  "single public IPv4",
			value: "203.0.113.42/32",
			want:  "203.0.113.42/32",
		},
		{
			name:  "canonical IPv4 network",
			value: "198.51.100.0/24",
			want:  "198.51.100.0/24",
		},
		{
			name:    "missing prefix",
			value:   "203.0.113.42",
			wantErr: "expected an IPv4 CIDR",
		},
		{
			name:    "IPv6",
			value:   "2001:db8::/64",
			wantErr: "IPv6 CIDRs are not supported",
		},
		{
			name:    "worldwide access",
			value:   "0.0.0.0/0",
			wantErr: "worldwide SSH access is not allowed",
		},
		{
			name:    "host bits set",
			value:   "198.51.100.42/24",
			wantErr: "host bits must be zero (use 198.51.100.0/24)",
		},
		{
			name:    "surrounding whitespace",
			value:   " 203.0.113.42/32 ",
			wantErr: "expected an IPv4 CIDR",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseSSHSourceCIDR(tt.value)
			if tt.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
					t.Fatalf("parseSSHSourceCIDR() error = %v, want error containing %q", err, tt.wantErr)
				}
				return
			}

			if err != nil {
				t.Fatalf("parseSSHSourceCIDR() unexpected error: %v", err)
			}
			if got != tt.want {
				t.Fatalf("parseSSHSourceCIDR() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestFromEnvRequiresAndStoresSSHSourceCIDR(t *testing.T) {
	setBaseEnvironment(t)
	t.Setenv(AZURE_SSH_SOURCE_CIDR, "203.0.113.42/32")

	got, err := FromEnv(true)
	if err != nil {
		t.Fatalf("FromEnv(true) unexpected error: %v", err)
	}
	if got.SSHSourceCIDR != "203.0.113.42/32" {
		t.Fatalf("SSHSourceCIDR = %q, want %q", got.SSHSourceCIDR, "203.0.113.42/32")
	}
}

func TestFromEnvRejectsMissingSSHSourceCIDR(t *testing.T) {
	setBaseEnvironment(t)
	t.Setenv(AZURE_SSH_SOURCE_CIDR, "")

	_, err := FromEnv(true)
	if err == nil || !strings.Contains(err.Error(), AZURE_SSH_SOURCE_CIDR) {
		t.Fatalf("FromEnv(true) error = %v, want missing %s error", err, AZURE_SSH_SOURCE_CIDR)
	}
}

func setBaseEnvironment(t *testing.T) {
	t.Helper()
	t.Setenv(AZURE_RESOURCE_GROUP, "devpod-test")
	t.Setenv(AZURE_INSTANCE_SIZE, "Standard_D4as_v5")
	t.Setenv(AZURE_IMAGE, "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest")
	t.Setenv(AZURE_DISK_SIZE, "128")
	t.Setenv(AZURE_DISK_TYPE, "StandardSSD_LRS")
	t.Setenv(AZURE_CUSTOM_DATA, "")
	t.Setenv(AZURE_REGION, "southindia")
	t.Setenv(AZURE_SUBSCRIPTION_ID, "00000000-0000-0000-0000-000000000000")
	t.Setenv(AZURE_TAGS, "")
}
