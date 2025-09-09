# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Dependencies and Environment
```bash
# Install dependencies
uv sync --frozen --all-extras --dev

# Set up pre-commit hooks
pre-commit install

# Activate virtual environment (if needed)
source .venv/bin/activate  # macOS/Linux
.venv\Scripts\activate.ps1  # Windows
```

### Testing
```bash
# Run all tests
uv run pytest

# Run tests with coverage
uv run pytest --cov=mcp_atlassian

# Run specific test file
uv run pytest tests/unit/jira/test_issues.py

# Run integration tests (requires real Atlassian credentials)
uv run pytest tests/integration/
```

### Code Quality
```bash
# Run all code quality checks (ruff + pyright + prettier)
pre-commit run --all-files

# Format code only
uv run ruff format

# Lint code only
uv run ruff check --fix
```

### Running the Server
```bash
# Start MCP server (stdio transport - default for IDE integration)
uv run mcp-atlassian

# Start with verbose logging
uv run mcp-atlassian -v

# Start with debug logging
uv run mcp-atlassian -vv

# OAuth setup wizard
uv run mcp-atlassian --oauth-setup

# HTTP transport for testing
uv run mcp-atlassian --transport sse --port 9000
uv run mcp-atlassian --transport streamable-http --port 9000
```

## Architecture Overview

### Core Structure
- **`src/mcp_atlassian/`** - Main library source code
  - **`jira/`** - Jira client with mixins for different operations (issues, search, boards, etc.)
  - **`confluence/`** - Confluence client with mixins for pages, search, comments, etc.
  - **`models/`** - Pydantic data models for API responses, organized by service
  - **`servers/`** - FastMCP server implementations and MCP tool registration
  - **`utils/`** - Shared utilities (authentication, logging, environment handling)

### Authentication Architecture
The system supports multiple authentication methods with auto-detection:
1. **API Token** (Cloud) - username + API token
2. **Personal Access Token** (Server/DC) - PAT only
3. **OAuth 2.0** (Cloud) - with setup wizard and token refresh
4. **Basic Auth** (Server/DC) - username + password

### MCP Tool Pattern
- Tools follow naming convention: `{service}_{action}` (e.g., `jira_create_issue`)
- All tools are categorized with tags: `["jira"|"confluence", "read"|"write"]`
- Read-only mode filtering based on tags
- Service-specific tool filtering based on configuration availability

### Client Architecture
- **Base clients** handle authentication and HTTP requests
- **Mixins** provide focused functionality (e.g., `IssuesMixin`, `SearchMixin`)
- **Fetcher classes** combine base client with relevant mixins
- All data models extend `ApiModel` base class with common functionality

## Development Standards

### Code Requirements
- **Python ≥ 3.10** required
- **Type hints mandatory** for all functions and methods
- **Line length: 88 characters maximum**
- **Google-style docstrings** for all public APIs
- **Absolute imports** only, sorted by ruff

### Testing Requirements
- New features require unit tests
- Bug fixes require regression tests
- Integration tests for end-to-end scenarios
- Mock external API calls in unit tests using provided fixtures

### Package Management
- **ONLY use `uv`** - never use `pip` directly
- Dependencies managed in `pyproject.toml`
- Use `uv sync` to install dependencies

### Git Workflow
- **Never work on `main`** - always create feature branches
- Branch naming: `feature/description` or `fix/issue-description`
- Pre-commit hooks must pass before committing
- Use conventional commit messages with proper attribution

### Environment Configuration
- Copy `.env.example` to `.env` for local development
- Never commit sensitive credentials
- Use environment variables for all configuration
- Support multiple authentication methods per the precedence in `.env.example`

## Common Development Tasks

### Adding New Jira Tools
1. Create mixin in `src/mcp_atlassian/jira/` with the functionality
2. Add mixin to `JiraFetcher` in `src/mcp_atlassian/jira/client.py`
3. Register tool in `src/mcp_atlassian/servers/jira.py`
4. Add appropriate tags: `["jira", "read"]` or `["jira", "write"]`
5. Write unit tests in `tests/unit/jira/`

### Adding New Confluence Tools
1. Create mixin in `src/mcp_atlassian/confluence/` with the functionality
2. Add mixin to `ConfluenceFetcher` in `src/mcp_atlassian/confluence/client.py`
3. Register tool in `src/mcp_atlassian/servers/confluence.py`
4. Add appropriate tags: `["confluence", "read"]` or `["confluence", "write"]`
5. Write unit tests in `tests/unit/confluence/`

### Running Single Tests
```bash
# Run specific test class
uv run pytest tests/unit/jira/test_issues.py::TestJiraIssues

# Run specific test method
uv run pytest tests/unit/jira/test_issues.py::TestJiraIssues::test_create_issue

# Run with specific markers
uv run pytest -m "not integration"
```

### Debugging Authentication Issues
```bash
# Enable verbose logging to see auth details
uv run mcp-atlassian -vv

# Test OAuth setup
uv run mcp-atlassian --oauth-setup -v

# Check environment configuration
uv run python -c "from mcp_atlassian.utils.environment import get_available_services; print(get_available_services())"
```

## Key Files to Understand

- **`src/mcp_atlassian/__init__.py`** - Main entry point and CLI interface
- **`src/mcp_atlassian/servers/main.py`** - FastMCP server setup and tool filtering
- **Configuration files**: `src/mcp_atlassian/{jira,confluence}/config.py`
- **Client implementations**: `src/mcp_atlassian/{jira,confluence}/client.py`
- **Test fixtures**: `tests/fixtures/{jira,confluence}_mocks.py`