# AZURE Provider for DevPod

[![Join us on Slack!](docs/static/media/slack.svg)](https://slack.loft.sh/) [![Open in DevPod!](https://devpod.sh/assets/open-in-devpod.svg)](https://devpod.sh/open#https://github.com/loft-sh/devpod-provider-azure)

## Getting started with this pinned fork

Do not install the upstream `azure` provider for this setup: upstream v0.11.0
still requests a retired Basic public IP. Install this release under separate
profile names and provide a validated current public IPv4 `/32` during setup.

```sh
devpod provider add guru3s/devpod-provider-azure@v0.11.1-guru.1 \
  --name azure-india \
  --single-machine \
  --use \
  --option AZURE_SUBSCRIPTION_ID=<subscription-id> \
  --option AZURE_RESOURCE_GROUP=agentagon-devpod-india \
  --option AZURE_REGION=southindia \
  --option AZURE_DISK_SIZE=128 \
  --option AZURE_DISK_TYPE=StandardSSD_LRS \
  --option AZURE_IMAGE=Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
  --option AZURE_INSTANCE_SIZE=Standard_D4as_v5 \
  --option AZURE_TAGS=app=devpod,owner=guru,region_profile=india \
  --option AZURE_SSH_SOURCE_CIDR=<public-ipv4>/32 \
  --option INACTIVITY_TIMEOUT=30m

devpod provider add guru3s/devpod-provider-azure@v0.11.1-guru.1 \
  --name azure-sf \
  --single-machine \
  --use=false \
  --option AZURE_SUBSCRIPTION_ID=<subscription-id> \
  --option AZURE_RESOURCE_GROUP=agentagon-devpod-sf \
  --option AZURE_REGION=westus \
  --option AZURE_DISK_SIZE=128 \
  --option AZURE_DISK_TYPE=StandardSSD_LRS \
  --option AZURE_IMAGE=Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
  --option AZURE_INSTANCE_SIZE=Standard_D4as_v5 \
  --option AZURE_TAGS=app=devpod,owner=guru,region_profile=sf \
  --option AZURE_SSH_SOURCE_CIDR=<public-ipv4>/32 \
  --option INACTIVITY_TIMEOUT=30m
```

Required provider variables are:

- AZURE_RESOURCE_GROUP
- AZURE_REGION
- AZURE_SSH_SOURCE_CIDR

### Creating your first devpod env with azure

After the initial setup, just use:

```sh
devpod up .
```

You'll need to wait for the machine and environment setup.

Be aware that authentication is obtained using Azure's Default Credential authenticator, this uses
the CLI tool, the ENV or Certificates, take a look
[here](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli)
for more info on how to setup either one of those auth methods.


### Customize the VM Instance

This provides has the seguent options

|    NAME           | REQUIRED |          DESCRIPTION                  |         DEFAULT         |
|-------------------|----------|---------------------------------------|-------------------------|
| AZURE_DISK_SIZE           | false    | The disk size to use.          | 40                                      |
| AZURE_IMAGE               | false    | The disk image to use.         | Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest |
| AZURE_INSTANCE_SIZE       | false    | The machine type to use.       | Standard_D11_v2                         |
| AZURE_REGION              | true     | The azure region to use        |                                         |
| AZURE_RESOURCE_GROUP      | true     | The azure resource group name  |                                         |
| AZURE_SUBSCRIPTION_ID     | true     | The azure subscription id      |                                         |
| AZURE_SSH_SOURCE_CIDR     | true     | IPv4 CIDR allowed to connect to SSH; use the current public IPv4 with `/32` | |

Options can either be set in `env` or using for example:

```sh
devpod provider set-options -o AZURE_IMAGE=Vendor:Item:Version:Tag
```

`AZURE_SSH_SOURCE_CIDR` must be a canonical IPv4 CIDR. IPv6 CIDRs, CIDRs with
host bits set, and `0.0.0.0/0` are rejected so the provider never creates an
SSH rule open to the whole internet.

## Safe connection helper

This fork includes `scripts/devpod-azure-connect` for the two-profile setup
described below. The helper discovers and validates the current public IPv4,
stores its `/32` in the selected provider, updates the existing tagged NSG,
verifies that no worldwide inbound allow rule exists, and only then invokes
`devpod up`.

Install it on macOS or Linux:

```sh
install -d "$HOME/.local/bin"
install -m 0755 scripts/devpod-azure-connect "$HOME/.local/bin/devpod-azure-connect"
```

Use it with an explicit source the first time a workspace is created:

```sh
devpod-azure-connect india project-india --ide cursor --source .
devpod-azure-connect india project-india --ide vscode
devpod-azure-connect india project-india --ide none
```

The supported profile mapping is deliberately fixed:

| Argument | DevPod provider | Azure resource group | Required resource tag |
|---|---|---|---|
| `india` | `azure-india` | `agentagon-devpod-india` | `region_profile=india` |
| `sf` | `azure-sf` | `agentagon-devpod-sf` | `region_profile=sf` |

Both resource groups and all provider-created resources must also be tagged
`app=devpod,owner=guru`. The helper aborts on failed IP discovery, mismatched
resource-group tags, multiple matching NSGs, a failed NSG update, or any
worldwide inbound allow rule. It never substitutes `0.0.0.0/0`. DevPod 0.6.15
generates workspace SSH blocks with agent forwarding enabled, so the helper
first starts and configures the workspace without opening the IDE, atomically
changes only the exact generated `<workspace>.devpod` block to
`ForwardAgent no`, validates its DevPod proxy command, and only then opens
Cursor or VS Code.
