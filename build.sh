#!/bin/bash

# Cross-platform build script for ZeroTier container
# Supports building for ARM64 and AMD64 architectures

set -e

# Configuration
IMAGE_NAME="${IMAGE_NAME:-zerotier-containerized}"
TAG="${TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/arm64,linux/amd64}"
REGISTRY="${REGISTRY:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building ZeroTier cross-platform container${NC}"
echo "Platforms: $PLATFORMS"
echo "Image: $IMAGE_NAME:$TAG"

# Check if buildx is available
if ! command -v docker buildx &> /dev/null; then
    echo -e "${RED}Error: docker buildx is not available${NC}"
    echo "Please install Docker Desktop or enable buildx functionality"
    exit 1
fi

# Create buildx builder if it doesn't exist
BUILDER_NAME="multiarch"
if ! docker buildx inspect $BUILDER_NAME &> /dev/null; then
    echo -e "${YELLOW}Creating buildx builder: $BUILDER_NAME${NC}"
    docker buildx create --name $BUILDER_NAME --use
else
    echo -e "${YELLOW}Using existing buildx builder: $BUILDER_NAME${NC}"
    docker buildx use $BUILDER_NAME
fi

# Build for multiple platforms
FULL_IMAGE_NAME="${REGISTRY}${IMAGE_NAME}:${TAG}"

echo -e "${GREEN}Building for platforms: $PLATFORMS${NC}"
docker buildx build \
    --platform $PLATFORMS \
    --tag $FULL_IMAGE_NAME \
    --load \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Build completed successfully!${NC}"
    echo "Image: $FULL_IMAGE_NAME"
    echo ""
    echo "To build and push to registry, use:"
    echo "  docker buildx build --platform $PLATFORMS --tag $FULL_IMAGE_NAME --push ."
    echo ""
    echo "To build for local testing (single platform):"
    echo "  docker build -t $FULL_IMAGE_NAME ."
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi