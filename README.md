# LilyIV

LilyIV is an intelligent multi-component AI system featuring voice interaction, Discord integration, web scouting, and an admin management interface.

## Modules

| Module | Description |
|--------|-------------|
| [Echo](./Echo/README.md) | Speech-to-text and text-to-speech service |
| [Lily-Core](./Lily-Core/README.md) | Core AI agent loop and chat processing engine |
| [Lily-Discord-Adapter](./Lily-Discord-Adapter/README.md) | Discord bot integration and messaging |
| [Lily-Admin-UI](./Lily-Admin-UI/client/README.md) | Admin dashboard for system monitoring |
| [Lily-UI](./Lily-UI/README.md) | Voice interaction UI |
| [Sentinel](./Sentinel/README.md) | JWT authentication & authorization service |
| [TTS-Provider](./TTS-Provider/README.md) | Text-to-speech provider service |
| [Web-Scout](./Web-Scout/README.md) | Web research and information gathering |

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Git (with submodule support)

### Setup

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/UpperMoon0/LilyIV.git
cd LilyIV

# Initialize/update submodules
git submodule update --init --recursive

# Copy environment templates and configure
cp .env.template .env
find . -name ".env.template" -exec cp {} {}.template \;

# Start all services
docker compose up -d
```

See individual module READMEs for detailed development setup.

## Features

- **Voice Chat**: Real-time speech processing via Echo service
- **Discord Integration**: Bot with commands, music, and conversations
- **Web Scouting**: Intelligent web research capabilities
- **Admin Dashboard**: Real-time system monitoring and configuration

See [docs/features](./docs/features/) for detailed documentation.

## License

MIT License
