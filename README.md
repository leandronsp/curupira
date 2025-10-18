# Curupira

A modern personal blog platform built with **Phoenix LiveView** and **Elixir**. Import articles from dev.to and deploy as a dynamic web app or static site.

## TL;DR
This project is a WIP. More to come soon.

## Features

### Dynamic Blog Platform
- 📝 **Article Management** - Create, edit, and manage blog posts with markdown support and real-time preview
- 🔄 **dev.to Integration** - Import all dev.to articles given a username with one command
- 🎨 **Dark/Light Theme** - Beautiful theme toggle with persistent preference
- 📱 **Responsive Design** - Newspaper-style layout that works on all devices
- 👤 **Blog Profile** - Customizable bio, avatar, and social links

### Static Site Generation
- 🚀 **Zero-Server Deployment** - Generate static HTML/CSS/JS for any deploy environment
- 📊 **SEO Optimized** - Open Graph, JSON-LD schema, sitemap.xml
- 🎯 **Optimized Assets** - Minified CSS/JS, purged Tailwind, lazy-loaded analytics (GTM)
- 🔧 **GitHub Actions** - Automated deployment workflow included

### Tech Stack
- **Phoenix 1.8** + **LiveView 1.1** - Modern Elixir web framework
- **PostgreSQL** - Reliable database
- **Tailwind CSS (with Daisy UI)** - Utility-first styling
- **MDEx** - Fast markdown parsing
- **Docker** - Containerized development and deployment

## Quick Start

### Docker please

```bash
# Clone the repository
git clone https://github.com/yourusername/curupira.git
cd curupira

# Create .env file
cat > .env <<EOF
DATABASE_URL=postgresql://postgres:postgres@db:5432/curupira_dev
MIX_ENV=dev
DEVTO_USERNAME=your_devto_username
EOF

# Start development environment
make dev-up

# Import your dev.to articles
docker-compose exec web mix devto.import --all

# Or providing a username
docker-compose exec web mix devto.import --all --username <your_username>

# Visit http://localhost:4000
```

> DEVTO_USERNAME is optional. 
> You can start writing articles on your own instead of importing them from DEVTO

## Deploy the Static Site

First test locally:

```bash
# Build static site and test locally on http://localhost:8000
make static-build
```

Then deploy. Perfect for GitHub Pages, Netlify, Vercel, Cloudflare Pages etc:

```bash
# Option 1: Manual - Copy static_output/ to your host
scp static_output/ your_host:/var/www

# Option 2: Automatic - Push to GitHub, enable Pages with GitHub Actions
```

See [STATIC_DEPLOY.md](STATIC_DEPLOY.md) for detailed instructions.

## Development

### Available Commands

```bash
# Development
mix phx.server          # Start development server
mix test                # Run tests
mix precommit           # Format, compile with warnings, test
iex -S mix phx.server   # Start with IEx console

# Database
mix ecto.migrate        # Run migrations
mix ecto.reset          # Reset database (drop, create, migrate, seed)

# Assets
mix assets.build        # Build CSS and JS
mix assets.deploy       # Build and minify for production

# Import from dev.to
mix devto.import                         # Import latest articles
mix devto.import --all                   # Import ALL articles
mix devto.import --username leandronsp   # Import specific user

# Static site
./build_static.sh       # Generate static site
make static-build       # Build in Docker
make static-test        # Build and serve locally
```

### Docker Commands

```bash
make dev-up             # Start development environment
make dev-down           # Stop development
make dev-logs           # View logs
make dev-shell          # Access IEx shell
make dev-reset          # Reset database

make prod-build         # Build production image
make prod-up            # Start production (port 4001)
make prod-down          # Stop production

make static-build       # Build static site in container
make static-serve       # Serve static site on port 8000

make help               # Show all available commands
```

## Environment Variables

Create a `.env` file in the project root:

```bash
# Required
DATABASE_URL=postgresql://postgres:postgres@db:5432/curupira_dev
MIX_ENV=dev
DEVTO_USERNAME=your_devto_username
```

For production deployment, also set:
```bash
SECRET_KEY_BASE=your_secret_key_base
PHX_SERVER=true
PHX_HOST=yourdomain.com
PORT=4000
POOL_SIZE=10
```

## Testing

```bash
# Run all tests
mix test

# Run specific test file
mix test test/curupira/blog_test.exs

# Run failed tests only
mix test --failed

# Run with coverage
mix test --cover
```

LiveView tests use `Phoenix.LiveViewTest` and `LazyHTML` for assertions.

## Contributing

We welcome contributions! By contributing, you agree to our [Contributor License Agreement](CONTRIBUTING.md).

**Quick start:**

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Run tests and formatting (`mix precommit`)
5. Commit your changes (`git commit -m 'add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

All contributions will be licensed under AGPL-3.0.

## License

**GNU Affero General Public License v3.0 (AGPL-3.0)**

Curupira is free and open source software licensed under AGPL-3.0.

**Permissions:**
- Commercial use, modification, distribution, and private use
- Run as a service (including commercial SaaS)

**Conditions:**
- Disclose source code of modifications
- Include original license and copyright
- State changes made to the code
- If you run modified code as a network service, you must make the complete source code available to users

**Attribution:**
- All deployments must maintain "Powered by Curupira" attribution with link to this repository

See [LICENSE](LICENSE) for complete terms.

## Acknowledgments

- Built with [Phoenix Framework](https://www.phoenixframework.org/)
- Markdown parsing by [MDEx](https://github.com/leandrocp/mdex)
- Styled with [Tailwind CSS](https://tailwindcss.com/)
- Inspired by the dev.to community
- Claude Code 🤖

## Support

- 📖 [Documentation](CLAUDE.md) - Architecture and development guide
- 🚀 [Static Deployment Guide](STATIC_DEPLOY.md) - Deploy to GitHub Pages
- 🐛 [Issues](https://github.com/yourusername/curupira/issues) - Report bugs or request features
- 💬 Questions? Open an issue or discussion

---

Made with ❤️ using Elixir and Phoenix LiveView
