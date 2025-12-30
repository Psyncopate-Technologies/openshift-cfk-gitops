#!/bin/bash

# Mirror Confluent images from Docker Hub to ECR
# Usage: ./mirror-images.sh <ECR_REGISTRY_URL> <CP_VERSION> <CFK_VERSION>

set -euo pipefail

ECR_REGISTRY="${1:-}"
CP_VERSION="${2:-8.0.1}"
CFK_VERSION="${3:-2.10.0}"

if [[ -z "$ECR_REGISTRY" ]]; then
    echo "Usage: $0 <ECR_REGISTRY_URL> [CP_VERSION] [CFK_VERSION]"
    echo "Example: $0 123456789.dkr.ecr.us-east-1.amazonaws.com 8.0.1 2.10.0"
    exit 1
fi

SOURCE_REGISTRY="docker.io/confluentinc"

# Images to mirror with their versions
declare -A IMAGES=(
    ["cp-server"]="$CP_VERSION"
    ["cp-schema-registry"]="$CP_VERSION"
    ["cp-kafka-connect"]="$CP_VERSION"
    ["cp-ksqldb-server"]="$CP_VERSION"
    ["cp-control-center"]="$CP_VERSION"
    ["cp-kafka-rest"]="$CP_VERSION"
    ["confluent-init-container"]="$CFK_VERSION"
    ["confluent-operator"]="$CFK_VERSION"
)

echo "=========================================="
echo "Confluent Image Mirror Script"
echo "=========================================="
echo "ECR Registry: $ECR_REGISTRY"
echo "CP Version: $CP_VERSION"
echo "CFK Version: $CFK_VERSION"
echo "=========================================="

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region "${AWS_REGION:-us-east-1}" | \
    docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Mirror each image
for IMAGE in "${!IMAGES[@]}"; do
    VERSION="${IMAGES[$IMAGE]}"
    SOURCE="${SOURCE_REGISTRY}/${IMAGE}:${VERSION}"
    TARGET="${ECR_REGISTRY}/confluent/${IMAGE}:${VERSION}"

    echo ""
    echo "Mirroring: $IMAGE:$VERSION"
    echo "  Source: $SOURCE"
    echo "  Target: $TARGET"

    # Pull from Docker Hub
    echo "  Pulling..."
    docker pull "$SOURCE"

    # Tag for ECR
    echo "  Tagging..."
    docker tag "$SOURCE" "$TARGET"

    # Push to ECR
    echo "  Pushing..."
    docker push "$TARGET"

    echo "  Done!"
done

echo ""
echo "=========================================="
echo "All images mirrored successfully!"
echo "=========================================="
