# Home Assistant Plugin Template

A modern, production-ready template for creating Home Assistant custom integrations with both Python backend and Vue.js frontend support.

## ✨ Features

- 🐍 **Python Backend** - Custom integration with sensors, services, and more
- 🎨 **Vue.js Frontend** - Modern Vue 3 + TypeScript Lovelace cards
- 🧪 **Comprehensive Testing** - 30+ example tests for backend and frontend
- 📦 **HACS Ready** - Proper structure for Home Assistant Community Store
- 🔧 **Development Tools** - Linting, formatting, type checking
- 📝 **Well Documented** - Extensive guides and examples
- 🚀 **Easy Initialization** - One script to customize everything

## 🚀 Quick Start

### 1. Clone the Template

```bash
git clone https://github.com/luckydonald/hoass_plugin-template.git my-plugin
cd my-plugin
```

### 2. Initialize Your Plugin

```bash
./scripts/init.sh
```

The script will ask you for:
- Plugin name (e.g., "Weather Dashboard")
- Naming conventions (auto-calculated)
- Whether you need Python backend
- Frontend framework choice (Vue or Plain)

**💡 The script is safe to re-run!** If you run it on an already initialized plugin, it will:
- Only update files that still have template patterns
- Offer to copy new files from template updates
- Never overwrite your code without permission


### 3. Start Developing

```bash
# Install dependencies
make setup

# Run tests
make test

# Start development
make dev  # Frontend hot-reload
```

## 📁 Project Structure

```
hoass_template/
├── custom_components/
│   └── plugin_template/       # Python integration
│       ├── __init__.py       # Integration setup
│       ├── sensor.py         # Sensor platform
│       ├── services.py       # Custom services
│       ├── const.py          # Constants
│       ├── models.py         # Data models
│       └── manifest.json     # Integration metadata
│
├── frontend_vue/              # Vue.js frontend
│   ├── src/
│   │   ├── PluginTemplateCard.vue  # Main component
│   │   ├── main.ts           # Registration
│   │   └── types.ts          # TypeScript types
│   ├── tests/                # Frontend tests
│   └── vite.config.ts        # Build configuration
│
├── tests/                     # Python tests
│   ├── test_init.py
│   ├── test_sensor.py
│   └── ...
│
├── scripts/
│   ├── init.sh               # Initialization script
│   ├── release.sh            # Release automation
│   └── commit.sh             # Commit helper
│
└── Makefile                  # Development commands
```

## 🧪 Testing

The template includes comprehensive test coverage:

- **Backend**: 17 example tests using pytest
- **Frontend**: 16 example tests using Vitest

```bash
# Run all tests
make test

# Run backend tests only
make test-py

# Run frontend tests only
make test-ts

# Run with coverage
make test-coverage
```

See [TESTING.md](TESTING.md) for detailed testing guide.

## 🛠️ Development

### Prerequisites

- Python 3.12+
- Node.js 22+ (for frontend)
- [uv](https://github.com/astral-sh/uv) (Python package manager)

### Setup

```bash
# Install all dependencies
make setup

# Or separately
make setup-py   # Backend only
make setup-ts   # Frontend only
```

### Common Commands

```bash
# Development
make dev              # Start frontend dev server
make lint             # Lint all code
make format           # Format all code
make test             # Run all tests

# Building
make build            # Build frontend

# Release
make release          # Create a new release
```

See `make help` for all available commands.

## 📝 Documentation

- **[TESTING.md](TESTING.md)** - Complete testing guide
- **[scripts/README.md](scripts/README.md)** - Initialization script docs

## 🎯 What's Included

### Python Backend
- ✅ Integration setup boilerplate
- ✅ Example sensor platform
- ✅ Service registration template
- ✅ Constants management
- ✅ Type hints throughout
- ✅ Home Assistant best practices

### Vue Frontend
- ✅ Vue 3 Composition API
- ✅ TypeScript support
- ✅ Vite for fast builds
- ✅ Home Assistant custom card structure
- ✅ Card editor template
- ✅ Proper styling

### Testing
- ✅ Pytest configuration
- ✅ Vitest configuration
- ✅ Example tests for all components
- ✅ Coverage reporting
- ✅ CI/CD ready

### Developer Experience
- ✅ Makefile for common tasks
- ✅ Linting (ruff, dprint)
- ✅ Type checking (mypy, TypeScript)
- ✅ Format on save
- ✅ Hot reload

## 🔄 Initialization Process

The `init.sh` script transforms this template into your custom plugin:

1. Asks for your plugin details
2. Calculates naming conventions
3. Optionally removes Python backend
4. Chooses frontend framework
5. Replaces all template strings
6. Renames files and directories
7. Ready to develop!

## 📦 HACS Installation

After publishing your plugin:

1. Add repository to HACS
2. Users can install via HACS
3. Automatic updates

The template is pre-configured with:
- Proper `hacs.json`
- Correct `manifest.json`
- Release automation

## 🤝 Contributing

This is a template repository. To improve it:

1. Fork the template
2. Make improvements
3. Test thoroughly
4. Submit a PR

## 📄 License

MIT License - see LICENSE file

## 🙏 Credits

Created for the Home Assistant community by [@luckydonald](https://github.com/luckydonald)

## 📚 Resources

- [Home Assistant Developer Docs](https://developers.home-assistant.io/)
- [HACS Documentation](https://hacs.xyz/)
- [Vue.js Documentation](https://vuejs.org/)
- [Vitest Documentation](https://vitest.dev/)

---

**Ready to build your Home Assistant plugin? Run `./scripts/init.sh` to get started! 🚀**

