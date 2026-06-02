#!/bin/bash

# Tenant Apps Manifest Generator
# Adapted from k8s-cluster/generate-manifests.sh for the homelab-apps repo.
# Key difference: No Omni extraManifests bootstrap file generation (tenant apps
# are not part of the Talos bootstrap chain).

ENVIRONMENT="scots-lab"
KUSTOMIZE_SRC="kustomize/overlays/${ENVIRONMENT}"
RESOURCES=$(find ${KUSTOMIZE_SRC}/*/ -mindepth 1 -maxdepth 1 -type d)

while read RESOURCE; do
  APP="${RESOURCE#*$ENVIRONMENT/}"
  HELM_BASE="helm/base/${APP}"
  HELM_OVERLAY="helm/overlays/${ENVIRONMENT}/${APP}"
  KUSTOMIZE_BASE="kustomize/base/${APP}"
  MANIFESTS_DST="manifests/${ENVIRONMENT}/${APP}"

  RESOURCE_PATHS=("$HELM_BASE" "$HELM_OVERLAY" "$KUSTOMIZE_BASE" "$RESOURCE")

  echo -n "Generating manifest files for ${APP}..."

  # check for changes
  if [ "$1" = "--force" ]; then
    CHANGES_LIST="forced"
  else
    if [ "$CI" = "true" ]; then
      # We are in GitHub Actions: Check changes in the latest commit
      CHANGES_LIST=$(git diff --name-only HEAD~1 HEAD -- "${RESOURCE_PATHS[@]}")
    else
      # We are local: Check staged files
      CHANGES_LIST=$(git diff --staged --name-only HEAD -- "${RESOURCE_PATHS[@]}")
    fi
  fi
  if [ ! -z "$CHANGES_LIST" ]; then
    # cleanup existing manifests
    rm -rf "${MANIFESTS_DST}"

    # create output directory if it does not exist
    mkdir -p "$MANIFESTS_DST"

    # build new manifests directly into a single multi-document file to avoid OS filename constraints (like NTFS colons)
    BOOTSTRAP_SINGLE="${MANIFESTS_DST}/_bootstrap.yaml"
    kustomize build "$RESOURCE" --load-restrictor LoadRestrictionsNone --enable-helm --enable-alpha-plugins --enable-exec > "$BOOTSTRAP_SINGLE" 2> "${MANIFESTS_DST}/kustomize_error.log"

    echo "done."

    continue
  fi

  echo "skipping (no changes detected)."
done <<<"$RESOURCES"
