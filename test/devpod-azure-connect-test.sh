#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/devpod-azure-connect"
fixture_bin="$repo_root/test/fixtures/bin"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -F -- "$expected" "$file" >/dev/null || fail "expected $file to contain: $expected"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -F -- "$unexpected" "$file" >/dev/null; then
    fail "expected $file not to contain: $unexpected"
  fi
}

run_success_case() {
  local name="$1"
  shift
  local case_dir="$test_root/$name"
  mkdir -p "$case_dir"
  : >"$case_dir/log"
  printf '%s\n' \
    '# DevPod Start vision-india.devpod' \
    'Host vision-india.devpod' \
    '  ForwardAgent yes' \
    '  ProxyCommand /usr/local/bin/devpod ssh --stdio --context default --user devcontainer vision-india' \
    '# DevPod End vision-india.devpod' >"$case_dir/ssh-config"

  if ! PATH="$fixture_bin:$PATH" \
    MOCK_LOG="$case_dir/log" \
    DEVPOD_SSH_CONFIG="$case_dir/ssh-config" \
    DEVPOD_AZURE_PUBLIC_IP="198.51.100.24" \
    "$@" >"$case_dir/stdout" 2>"$case_dir/stderr"; then
    sed -n '1,120p' "$case_dir/stderr" >&2
    fail "$name case returned a non-zero status"
  fi

  success_case_dir="$case_dir"
}

run_success_case create "$script" india vision-india --ide cursor --source .
case_dir="$success_case_dir"
assert_contains "$case_dir/log" 'devpod <provider> <set-options> <azure-india> <--option> <AZURE_SSH_SOURCE_CIDR=198.51.100.24/32>'
assert_contains "$case_dir/log" "devpod <up> <.> <--id> <vision-india> <--provider> <azure-india> <--ide> <cursor> <--configure-ssh> <--ssh-config> <$case_dir/ssh-config> <--open-ide=false>"
assert_contains "$case_dir/log" "devpod <up> <vision-india> <--provider> <azure-india> <--ide> <cursor> <--configure-ssh=false> <--ssh-config> <$case_dir/ssh-config> <--open-ide=true>"
assert_contains "$case_dir/ssh-config" '  ForwardAgent no'

case_dir="$test_root/existing"
mkdir -p "$case_dir"
: >"$case_dir/log"
printf '%s\n' \
  '# DevPod Start vision-india.devpod' \
  'Host vision-india.devpod' \
  '  ForwardAgent yes' \
  '# DevPod End vision-india.devpod' >"$case_dir/ssh-config"
PATH="$fixture_bin:$PATH" \
  MOCK_LOG="$case_dir/log" \
  DEVPOD_SSH_CONFIG="$case_dir/ssh-config" \
  MOCK_NSG_LIST='[{"name":"india-nsg","tags":{"app":"devpod","owner":"guru","region_profile":"india"}}]' \
  MOCK_WORKSPACES='[{"id":"vision-india","provider":{"name":"azure-india"}}]' \
  DEVPOD_AZURE_PUBLIC_IP="198.51.100.24" \
  "$script" india vision-india --ide none >"$case_dir/stdout" 2>"$case_dir/stderr"
assert_contains "$case_dir/log" 'az <network> <nsg> <rule> <update>'
assert_contains "$case_dir/log" "devpod <up> <vision-india> <--provider> <azure-india> <--ide> <none> <--configure-ssh> <--ssh-config> <$case_dir/ssh-config> <--open-ide=false>"

case_dir="$test_root/invalid-ip"
mkdir -p "$case_dir"
: >"$case_dir/log"
printf '%s\n' \
  '# DevPod Start vision-india.devpod' \
  'Host vision-india.devpod' \
  '  ForwardAgent yes' \
  '# DevPod End vision-india.devpod' >"$case_dir/ssh-config"
if PATH="$fixture_bin:$PATH" MOCK_LOG="$case_dir/log" DEVPOD_AZURE_PUBLIC_IP="999.1.1.1" \
  DEVPOD_SSH_CONFIG="$case_dir/ssh-config" \
  "$script" india vision-india --source . >"$case_dir/stdout" 2>"$case_dir/stderr"; then
  fail "invalid IP was accepted"
fi
assert_contains "$case_dir/stderr" 'could not discover and validate'

case_dir="$test_root/multiple-nsgs"
mkdir -p "$case_dir"
: >"$case_dir/log"
printf '%s\n' \
  '# DevPod Start vision-india.devpod' \
  'Host vision-india.devpod' \
  '  ForwardAgent yes' \
  '# DevPod End vision-india.devpod' >"$case_dir/ssh-config"
if PATH="$fixture_bin:$PATH" \
  MOCK_LOG="$case_dir/log" \
  DEVPOD_SSH_CONFIG="$case_dir/ssh-config" \
  MOCK_NSG_LIST='[{"name":"a","tags":{"app":"devpod","owner":"guru","region_profile":"india"}},{"name":"b","tags":{"app":"devpod","owner":"guru","region_profile":"india"}}]' \
  DEVPOD_AZURE_PUBLIC_IP="198.51.100.24" \
  "$script" india vision-india --source . >"$case_dir/stdout" 2>"$case_dir/stderr"; then
  fail "multiple NSGs were accepted"
fi
assert_contains "$case_dir/stderr" 'refusing to guess'

case_dir="$test_root/worldwide-rule"
mkdir -p "$case_dir"
: >"$case_dir/log"
printf '%s\n' \
  '# DevPod Start vision-india.devpod' \
  'Host vision-india.devpod' \
  '  ForwardAgent yes' \
  '# DevPod End vision-india.devpod' >"$case_dir/ssh-config"
if PATH="$fixture_bin:$PATH" \
  MOCK_LOG="$case_dir/log" \
  DEVPOD_SSH_CONFIG="$case_dir/ssh-config" \
  MOCK_NSG_LIST='[{"name":"india-nsg","tags":{"app":"devpod","owner":"guru","region_profile":"india"}}]' \
  MOCK_NSG_SHOW='{"securityRules":[{"name":"devpod_inbound_22","direction":"Inbound","access":"Allow","protocol":"Tcp","sourceAddressPrefix":"198.51.100.24/32","destinationPortRange":"22"},{"name":"bad","direction":"Inbound","access":"Allow","protocol":"Tcp","sourceAddressPrefix":"0.0.0.0/0","destinationPortRange":"8080"}]}' \
  DEVPOD_AZURE_PUBLIC_IP="198.51.100.24" \
  "$script" india vision-india --source . >"$case_dir/stdout" 2>"$case_dir/stderr"; then
  fail "worldwide inbound rule was accepted"
fi
assert_contains "$case_dir/stderr" 'NSG verification failed'

case_dir="$test_root/forward-agent"
mkdir -p "$case_dir"
: >"$case_dir/log"
printf '%s\n' \
  '# DevPod Start vision-india.devpod' \
  'Host vision-india.devpod' \
  '  ForwardAgent yes' \
  '# DevPod End vision-india.devpod' >"$case_dir/ssh-config"
if PATH="$fixture_bin:$PATH" \
  MOCK_LOG="$case_dir/log" \
  DEVPOD_SSH_CONFIG="$case_dir/ssh-config" \
  MOCK_NSG_LIST='[{"name":"india-nsg","tags":{"app":"devpod","owner":"guru","region_profile":"india"}}]' \
  MOCK_WORKSPACES='[{"id":"vision-india","provider":{"name":"azure-india"}}]' \
  MOCK_FORWARD_AGENT='yes' \
  DEVPOD_AZURE_PUBLIC_IP="198.51.100.24" \
  "$script" india vision-india --ide none >"$case_dir/stdout" 2>"$case_dir/stderr"; then
  fail "SSH agent forwarding was accepted"
fi
assert_contains "$case_dir/stderr" 'SSH alias is missing the DevPod proxy or still forwards the SSH agent'

case_dir="$test_root/stock-provider"
mkdir -p "$case_dir"
: >"$case_dir/log"
if PATH="$fixture_bin:$PATH" \
  MOCK_LOG="$case_dir/log" \
  MOCK_STOCK_PROVIDER='true' \
  DEVPOD_AZURE_PUBLIC_IP="198.51.100.24" \
  DEVPOD_SSH_CONFIG="$case_dir/ssh-config" \
  "$script" india vision-india --source . >"$case_dir/stdout" 2>"$case_dir/stderr"; then
  fail "stock provider was accepted"
fi
assert_contains "$case_dir/stderr" 'is not the pinned, expected Azure profile'
assert_not_contains "$case_dir/log" 'az '

case_dir="$test_root/cidr-not-persisted"
mkdir -p "$case_dir"
: >"$case_dir/log"
if PATH="$fixture_bin:$PATH" \
  MOCK_LOG="$case_dir/log" \
  MOCK_IGNORE_SOURCE_CIDR='true' \
  DEVPOD_AZURE_PUBLIC_IP="198.51.100.24" \
  DEVPOD_SSH_CONFIG="$case_dir/ssh-config" \
  "$script" india vision-india --source . >"$case_dir/stdout" 2>"$case_dir/stderr"; then
  fail "provider that ignored the CIDR option was accepted"
fi
assert_contains "$case_dir/stderr" 'provider did not persist AZURE_SSH_SOURCE_CIDR'
assert_not_contains "$case_dir/log" 'az <network>'

case_dir="$test_root/wrong-workspace-provider"
mkdir -p "$case_dir"
: >"$case_dir/log"
if PATH="$fixture_bin:$PATH" \
  MOCK_LOG="$case_dir/log" \
  MOCK_NSG_LIST='[{"name":"india-nsg","tags":{"app":"devpod","owner":"guru","region_profile":"india"}}]' \
  MOCK_WORKSPACES='[{"id":"vision-india","provider":{"name":"azure-sf"}}]' \
  DEVPOD_AZURE_PUBLIC_IP="198.51.100.24" \
  DEVPOD_SSH_CONFIG="$case_dir/ssh-config" \
  "$script" india vision-india --ide none >"$case_dir/stdout" 2>"$case_dir/stderr"; then
  fail "workspace from the wrong provider was accepted"
fi
assert_contains "$case_dir/stderr" 'belongs to provider azure-sf, not azure-india'

printf 'PASS: devpod-azure-connect tests\n'
