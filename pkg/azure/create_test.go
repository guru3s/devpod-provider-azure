package azure

import (
	"testing"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/to"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/network/armnetwork"
)

func TestNewPublicIPAddressParametersUsesStandardRegionalStatic(t *testing.T) {
	tags := map[string]*string{"app": to.Ptr("devpod")}
	got := newPublicIPAddressParameters("southindia", tags)

	if got.Location == nil || *got.Location != "southindia" {
		t.Fatalf("Location = %v, want southindia", got.Location)
	}
	if got.SKU == nil || got.SKU.Name == nil || *got.SKU.Name != armnetwork.PublicIPAddressSKUNameStandard {
		t.Fatalf("SKU.Name = %v, want Standard", got.SKU)
	}
	if got.SKU.Tier == nil || *got.SKU.Tier != armnetwork.PublicIPAddressSKUTierRegional {
		t.Fatalf("SKU.Tier = %v, want Regional", got.SKU.Tier)
	}
	if got.Properties == nil || got.Properties.PublicIPAllocationMethod == nil ||
		*got.Properties.PublicIPAllocationMethod != armnetwork.IPAllocationMethodStatic {
		t.Fatalf("PublicIPAllocationMethod = %v, want Static", got.Properties)
	}
	if got.Tags["app"] == nil || *got.Tags["app"] != "devpod" {
		t.Fatalf("Tags = %v, want app=devpod", got.Tags)
	}
}

func TestNewNetworkSecurityGroupParametersRestrictsInboundSSH(t *testing.T) {
	const sourceCIDR = "203.0.113.42/32"
	got := newNetworkSecurityGroupParameters("southindia", nil, sourceCIDR)

	if got.Location == nil || *got.Location != "southindia" {
		t.Fatalf("Location = %v, want southindia", got.Location)
	}
	if got.Properties == nil {
		t.Fatal("Properties is nil")
	}

	var inboundSSH *armnetwork.SecurityRule
	for _, rule := range got.Properties.SecurityRules {
		if rule.Properties != nil && rule.Properties.Direction != nil &&
			*rule.Properties.Direction == armnetwork.SecurityRuleDirectionInbound {
			inboundSSH = rule
			break
		}
	}
	if inboundSSH == nil {
		t.Fatal("inbound SSH rule not found")
	}

	properties := inboundSSH.Properties
	if properties.SourceAddressPrefix == nil || *properties.SourceAddressPrefix != sourceCIDR {
		t.Fatalf("SourceAddressPrefix = %v, want %s", properties.SourceAddressPrefix, sourceCIDR)
	}
	if properties.DestinationPortRange == nil || *properties.DestinationPortRange != "22" {
		t.Fatalf("DestinationPortRange = %v, want 22", properties.DestinationPortRange)
	}
	if properties.Protocol == nil || *properties.Protocol != armnetwork.SecurityRuleProtocolTCP {
		t.Fatalf("Protocol = %v, want TCP", properties.Protocol)
	}
	if properties.Access == nil || *properties.Access != armnetwork.SecurityRuleAccessAllow {
		t.Fatalf("Access = %v, want Allow", properties.Access)
	}
}
