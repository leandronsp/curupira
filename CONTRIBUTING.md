# Contributing to Curupira

Thank you for considering contributing to Curupira.

## Code of Conduct

Be respectful, constructive, and professional.

## How to Contribute

### Reporting Bugs

Check existing issues before creating new ones. Include:

- Clear title and description
- Steps to reproduce
- Expected vs actual behavior
- Environment details (Elixir version, OS, browser)

### Suggesting Features

Provide:

- Clear use case
- Proposed solution
- Alternatives considered

### Pull Requests

1. Fork the repo and create your branch from `master`
2. Add tests for new code
3. Ensure test suite passes (`mix test`)
4. Run formatting (`mix format`)
5. Run precommit checks (`mix precommit`)
6. Write clear commit messages

## License

By contributing, you agree that your contributions will be licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

All contributions must comply with AGPL-3.0 terms. This means:

- Your contributions become part of the open source codebase
- Anyone using Curupira (including as a service) must make source code available
- Commercial use is permitted as long as source code is disclosed

## Development Setup

### Prerequisites

- Elixir 1.15+
- PostgreSQL 15+
- Node.js 20+
- Docker (optional)

### Getting Started

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/curupira.git
cd curupira

# Using Docker
make dev-up
docker-compose exec web mix devto.import --all --username YOUR_USERNAME

# Or native
mix setup
export DEVTO_USERNAME=your_username
mix devto.import --all
mix phx.server
```

Visit http://localhost:4000

### Running Tests

```bash
mix test                    # All tests
mix test path/to/test.exs   # Specific test
mix test --cover            # With coverage
mix precommit               # Format, compile, test
```

### Code Style

- Run `mix format` before committing
- Follow Elixir community conventions
- Write clear, descriptive function names
- Document public functions
- Keep functions small and focused

### Commit Messages

```
add language filter to article listing

- implement PT/BR and EN filter buttons
- update search to include language filtering
- add tests for language filter behavior
```

Use imperative mood, lowercase, no period at end.

## Project Structure

```
lib/
├── curupira/
│   ├── blog.ex              # Blog context
│   ├── blog/
│   │   ├── article.ex       # Article schema
│   │   ├── profile.ex       # Profile schema
│   │   └── dev_to_importer.ex  # dev.to integration
│   └── markdown/
│       └── parser.ex        # Markdown to HTML
├── curupira_web/
│   ├── live/
│   │   └── article_live/    # LiveView modules
│   └── components/          # Reusable components
└── mix/tasks/
    ├── devto.import.ex      # Import CLI
    └── build_static.ex      # Static generator
```

## Testing

- Test public APIs, not private functions
- Use `Phoenix.LiveViewTest` for LiveView testing
- Prefer `has_element?/2` over raw HTML matching
- Mock external APIs (dev.to) in tests
- Keep tests fast and focused

## Questions

- Check [CLAUDE.md](CLAUDE.md) for architecture details
- See [STATIC_DEPLOY.md](STATIC_DEPLOY.md) for deployment
- Open an issue for questions

## Recognition

Contributors will be recognized in:
- GitHub contributors page
- Release notes
- Project documentation (for significant contributions)
