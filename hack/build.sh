#!/usr/bin/env bash
set -euo pipefail

export GO111MODULE=on
export GOFLAGS=-mod=vendor

provider_root=$(git rev-parse --show-toplevel)
release_version=${RELEASE_VERSION:-}

echo "Current working directory is $(pwd)"
echo "PATH is $PATH"
echo "GOPATH is ${GOPATH:-}"

if [[ "$(pwd)" != "${provider_root}" ]]; then
  echo "you are not in the root of the repo" 1>&2
  echo "please cd to ${provider_root} before running this script" 1>&2
  exit 1
fi

if [[ -z "${release_version}" || "${release_version}" != v* ]]; then
  echo "RELEASE_VERSION must be set to a tag beginning with v" 1>&2
  exit 1
fi

read -r -a build_platforms <<< "${PROVIDER_BUILD_PLATFORMS:-linux windows darwin}"
read -r -a build_arches <<< "${PROVIDER_BUILD_ARCHS:-amd64 arm64}"

sha256_file() {
  local file_path=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file_path}" | cut -d ' ' -f 1
    return
  fi

  shasum -a 256 "${file_path}" | cut -d ' ' -f 1
}

# Recreate the exact release file set so stale assets cannot be published.
mkdir -p "${provider_root}/release"
find "${provider_root}/release" -mindepth 1 -maxdepth 1 -type f -delete

for target_os in "${build_platforms[@]}"; do
  for target_arch in "${build_arches[@]}"; do
    binary_name="devpod-provider-azure-${target_os}-${target_arch}"
    if [[ "${target_os}" == "windows" ]]; then
      binary_name="${binary_name}.exe"
    fi

    # darwin 386 is deprecated and shouldn't be used anymore
    if [[ "${target_arch}" == "386" && "${target_os}" == "darwin" ]]; then
        echo "Building for ${target_os}/${target_arch} not supported."
        continue
    fi

    # A Windows arm64 binary is not declared by the provider manifest.
    if [[ "${target_arch}" == "arm64" && "${target_os}" == "windows" ]]; then
        echo "Building for ${target_os}/${target_arch} not supported."
        continue
    fi

    echo "Building for ${target_os}/${target_arch}"
    CGO_ENABLED=0 GOARCH=${target_arch} GOOS=${target_os} go build -trimpath -ldflags "-s -w" \
      -o "${provider_root}/release/${binary_name}" .
    sha256_file "${provider_root}/release/${binary_name}" > "${provider_root}/release/${binary_name}.sha256"
  done
done

# generate provider.yaml
go run -mod=vendor "${provider_root}/hack/provider/main.go" "${release_version}" > "${provider_root}/release/provider.yaml"
