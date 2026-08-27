#!/usr/bin/env bash

set -euo pipefail

provider_root="$(git rev-parse --show-toplevel)"
release_dir="${provider_root}/release"
provider_repo="${PROVIDER_REPO:-guru3s/devpod-provider-azure}"
release_version="${RELEASE_VERSION:-}"
manifest="${release_dir}/provider.yaml"

if [[ -z "$release_version" || "$release_version" != v* ]]; then
  printf 'RELEASE_VERSION must be set to a tag beginning with v\n' >&2
  exit 1
fi

[[ -f "$manifest" ]] || {
  printf 'missing release manifest: %s\n' "$manifest" >&2
  exit 1
}

sha256_file() {
  local file_path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | cut -d ' ' -f 1
    return
  fi

  shasum -a 256 "$file_path" | cut -d ' ' -f 1
}

verify_binary() {
  local binary_name="$1"
  local expected_occurrences="$2"
  local binary_path="${release_dir}/${binary_name}"
  local checksum_path="${binary_path}.sha256"
  local expected_checksum actual_checksum release_url manifest_checksums manifest_count

  [[ -f "$binary_path" ]] || {
    printf 'missing release binary: %s\n' "$binary_path" >&2
    return 1
  }
  [[ -f "$checksum_path" ]] || {
    printf 'missing checksum sidecar: %s\n' "$checksum_path" >&2
    return 1
  }

  expected_checksum="$(cut -d ' ' -f 1 "$checksum_path")"
  actual_checksum="$(sha256_file "$binary_path")"
  [[ "$expected_checksum" == "$actual_checksum" ]] || {
    printf 'checksum mismatch for %s\n' "$binary_name" >&2
    return 1
  }

  release_url="https://github.com/${provider_repo}/releases/download/${release_version}/${binary_name}"
  manifest_checksums="$(awk -v release_url="$release_url" '
    $1 == "path:" {
      matching_path = ($2 == release_url)
      next
    }
    matching_path && $1 == "checksum:" {
      print $2
      matching_path = 0
    }
  ' "$manifest")"
  manifest_count="$(printf '%s\n' "$manifest_checksums" | awk 'NF { count++ } END { print count + 0 }')"
  [[ "$manifest_count" == "$expected_occurrences" ]] || {
    printf 'expected %s manifest entries for %s, found %s\n' \
      "$expected_occurrences" "$binary_name" "$manifest_count" >&2
    return 1
  }

  while IFS= read -r manifest_checksum; do
    [[ -z "$manifest_checksum" || "$manifest_checksum" == "$actual_checksum" ]] || {
      printf 'manifest checksum mismatch for %s\n' "$binary_name" >&2
      return 1
    }
  done <<<"$manifest_checksums"
}

file_count="$(find "$release_dir" -maxdepth 1 -type f | wc -l | tr -d ' ')"
[[ "$file_count" == "11" ]] || {
  printf 'expected exactly 11 release files, found %s\n' "$file_count" >&2
  exit 1
}

url_count="$(awk -v prefix="https://github.com/${provider_repo}/releases/download/${release_version}/" \
  '$1 == "path:" && index($2, prefix) == 1 { count++ } END { print count + 0 }' "$manifest")"
[[ "$url_count" == "7" ]] || {
  printf 'expected exactly 7 fork release URLs, found %s\n' "$url_count" >&2
  exit 1
}

if grep -q 'github.com/loft-sh/devpod-provider-azure/releases/download/' "$manifest"; then
  printf 'manifest still references upstream release binaries\n' >&2
  exit 1
fi

if grep -q '##[A-Z_]*##' "$manifest"; then
  printf 'manifest contains unresolved placeholders\n' >&2
  exit 1
fi

verify_binary devpod-provider-azure-linux-amd64 2
verify_binary devpod-provider-azure-linux-arm64 2
verify_binary devpod-provider-azure-darwin-amd64 1
verify_binary devpod-provider-azure-darwin-arm64 1
verify_binary devpod-provider-azure-windows-amd64.exe 1

printf 'Verified release manifest and checksums for %s.\n' "$release_version"
