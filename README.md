# ZeroTier Containerized - Cross-Platform

A production-ready Docker container for ZeroTier One networking virtualization platform with support for both ARM64 and AMD64 architectures.

## 🚀 Features

- **Cross-Platform Support**: Built for both ARM64 (e.g., Raspberry Pi, Apple Silicon) and AMD64 (Intel/AMD) architectures
- **Production-Ready**: Multi-stage Docker build with optimized layers
- **SSL Dependencies**: Complete SSL library support for secure communications
- **Health Checks**: Built-in health monitoring for container orchestration
- **Easy Deployment**: Simple Docker Compose configuration
- **ZeroTier Official**: Uses official ZeroTier installation script

## 📋 Prerequisites

- Docker Engine 20.10+ with Buildx support
- Docker Compose 3.8+
- For cross-platform builds: QEMU user static (optional for emulation)

## 🏗️ Building

### Single Platform Build

Build for your current platform:
```bash
# Build for current architecture
docker build -t zerotier-containerized .

# Test the build
docker run --rm -it zerotier-containerized --version
```

### Cross-Platform Build

Build for both ARM64 and AMD64 simultaneously:

#### Using Build Script (Recommended)
```bash
# Make script executable
chmod +x build.sh

# Build for both platforms
./build.sh

# Build with custom tag
TAG=v1.0.0 ./build.sh

# Build and push to registry
REGISTRY=docker.io/yourusername/ ./build.sh
```

#### Manual Buildx Commands
```bash
# Create multi-platform builder
docker buildx create --name multiarch --use

# Build for multiple platforms
docker buildx build \
  --platform linux/arm64,linux/amd64 \
  --tag your-registry/zerotier-containerized:latest \
  --load \
  .

# Build and push to registry
docker buildx build \
  --platform linux/arm64,linux/amd64 \
  --tag your-registry/zerotier-containerized:latest \
  --push \
  .
```

### Buildx Configuration

The included `buildx-config.yml` provides optimized build settings:
- Driver: `docker-container` for best performance
- Cache: Registry-based caching for faster rebuilds
- Output: Registry support for easy distribution

## 🚢 Running

### Docker Run

```bash
# Basic run
docker run -d \
  --name zerotier-one \
  --restart unless-stopped \
  --network host \
  --privileged \
  -p 9993:9993/udp \
  -v zerotier-data:/var/lib/zerotier-one \
  zerotier-containerized:latest

# With environment variables
docker run -d \
  --name zerotier-one \
  --restart unless-stopped \
  --network host \
  --privileged \
  -p 9993:9993/udp \
  -v zerotier-data:/var/lib/zerotier-one \
  -e ZT_NETWORK=your-network-id \
  zerotier-containerized:latest
```

### Docker Compose (Recommended)

```bash
# Create environment file
cat > .env << EOF
ZT_NETWORK=your-network-id-here
ZT_API_KEY=
ZT_API_URL=https://my.zerotier.com/api
ZT_MEMBER_NAME=
ZT_MEMBER_DESCRIPTION=
ZT_JOIN_TIMEOUT=30
ZT_AUTHORIZE_TIMEOUT=30
ZT_VERBOSE=0
EOF

# Start container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop container
docker-compose down
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ZT_NETWORK` | ZeroTier network ID to join (16 hex chars) | None (REQUIRED) |
| `ZT_API_KEY` | ZeroTier API token used to auto-authorize the device (32 chars) | None |
| `ZT_API_URL` | ZeroTier controller API URL | `https://my.zerotier.com/api` |
| `ZT_MEMBER_NAME` | Member short name (spaces replaced with dashes) | derived (hostname or zerotier id) |
| `ZT_MEMBER_DESCRIPTION` | Member description for controller | empty |
| `ZT_JOIN_TIMEOUT` | Seconds to wait for network join to appear | `30` |
| `ZT_AUTHORIZE_TIMEOUT` | Seconds to wait for authorization to become active | `30` |
| `ZT_VERBOSE` | Enable verbose logging when set to `1` | `0` |

### Network Configuration

The container uses host networking mode for optimal ZeroTier performance:
- Exposes port `9993/udp` for ZeroTier communication
- Requires `--privileged` flag for network interface creation
- Mounts `/var/lib/zerotier-one` for persistent identity storage

### Volumes

| Volume | Description | Path |
|--------|-------------|------|
| `zerotier-data` | ZeroTier identity and configuration | `/var/lib/zerotier-one` |

## 🏗️ Architecture

### Multi-Stage Build

1. **Builder Stage**: 
   - Base: `debian:bookworm-slim`
   - Installs: curl, gnupg, ca-certificates, libssl3, build-essential
   - Downloads and installs ZeroTier from official source
   - Compiles and prepares binaries

2. **Final Stage**:
   - Base: `debian:bookworm-slim` 
   - Runtime: libssl3 for SSL support
   - ZeroTier binaries from builder
   - SSL libraries with architecture-specific paths
   - Health checks and metadata

### Cross-Platform Support

The Dockerfile uses wildcard paths (`/usr/lib/*/`) to automatically handle:
- ARM64: `/usr/lib/aarch64-linux-gnu/`
- AMD64: `/usr/lib/x86_64-linux-gnu/`

## 🧪 Testing

### Local Testing

```bash
# Test local build
docker build -t zerotier-test .
docker run --rm zerotier-test --version

# Test specific architecture
docker buildx build --platform linux/arm64 -t zerotier-arm64 .
docker run --rm zerotier-arm64 --version
```

### Health Check

The container includes a health check that verifies ZeroTier is running:
```bash
# Check container health
docker inspect --format='{{.State.Health.Status}}' zerotier-one
```

## 🐛 Troubleshooting

### Common Issues

1. **Build fails with missing SSL libraries**
   - Ensure `libssl3` is installed in builder stage
   - Check architecture-specific library paths

2. **ZeroTier fails to start**
   - Run with `--privileged` flag
   - Check network mode: must be `host`
   - Verify port 9993 is available

3. **Cross-platform build issues**
   - Install QEMU: `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`
   - Use `--load` for local testing, `--push` for registry

### Logs

```bash
# View container logs
docker logs zerotier-one

# Follow logs
docker-compose logs -f zerotier-one

# Check health status
docker inspect zerotier-one | jq '.State.Health'
```

## 📦 Deployment Examples

### Kubernetes

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: zerotier
spec:
  selector:
    matchLabels:
      app: zerotier
  template:
    metadata:
      labels:
        app: zerotier
    spec:
      hostNetwork: true
      containers:
      - name: zerotier
        image: zerotier-containerized:latest
        securityContext:
          privileged: true
        volumeMounts:
        - name: zerotier-data
          mountPath: /var/lib/zerotier-one
        ports:
        - containerPort: 9993
          protocol: UDP
      volumes:
      - name: zerotier-data
        hostPath:
          path: /var/lib/zerotier-one
```

### Docker Swarm

```yaml
version: '3.8'
services:
  zerotier:
    image: zerotier-containerized:latest
    deploy:
      mode: global
    networks:
      - host
    volumes:
      - zerotier-data:/var/lib/zerotier-one
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    ports:
      - "9993:9993/udp"

networks:
  host:
    external: true

volumes:
  zerotier-data:
```

## 🆘 Support

- [ZeroTier Documentation](https://docs.zerotier.com/)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
---

**Built with ❤️ for the ZeroTier community**
