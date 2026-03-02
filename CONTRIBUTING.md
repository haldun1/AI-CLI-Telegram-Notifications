# Contributing to AI-CLI-Telegram-Notifications

First off, thank you for considering contributing to `AI-CLI-Telegram-Notifications`! It's people like you that make tools like this better for everyone.

## Where we need help:
We are especially interested in Pull Requests that add:
- **macOS / Linux bash equivalents** for existing scripts.
- **Support for other CLI tools** with hook systems.
- **Support for other notification platforms** (Slack, Discord, Signal, etc.).

## Submitting Pull Requests

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally and create a new branch for your feature or bug fix:
   ```bash
   git checkout -b your-feature-name
   ```
3. **Write your script**: If adding support for a new CLI or OS, please keep the script formatting as close to the existing scripts as possible. Make sure you use environment variables (e.g., `$env:TELEGRAM_BOT_TOKEN`, `$BOT_TOKEN`) and never hardcode secrets.
4. **Update automated setup (`setup.ps1`)**: If your change affects hook installation/configuration, update `setup.ps1` so automated setup also supports it (including tool-selection behavior where applicable).
5. **Update the README:** Keep both setup paths current:
   - **Automated setup** (`.\setup.ps1`)
   - **Manual setup** (step-by-step)
   Ensure file references use placeholders properly (e.g. `YOUR_USERNAME`).
6. **Add snippet files:** Create `settings-snippet.json` or `config-snippet.toml` in your tool's folder to make copying the configuration easy for users.
7. **Test your code:** Verify scripts correctly parse hooks/logs and format messages cleanly for the notification API. Ensure truncation logic exists for long messages (e.g., 4000 chars for Telegram).
8. **Validate setup flows:**
   - Run `.\setup.ps1` and confirm selected tool(s) are configured correctly.
   - Confirm the corresponding manual setup steps still work.
9. **Commit** your changes with clear messages.
10. **Push** your branch and open a **Pull Request** against the `main` branch.

## Submitting Issues
If you find a bug or have a suggestion, please check if an issue already exists. If not, open a new issue describing:
- The problem or proposed feature.
- Steps to reproduce (if it's a bug).
- Which CLI tool and OS you are using.

We look forward to reviewing your contributions!
