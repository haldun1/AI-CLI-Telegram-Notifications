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
4. **Update the README:** Add a step-by-step section explaining how to integrate your script with the tool, following the format of existing tools. Ensure file references use placeholders properly (e.g. `YOUR_USERNAME`).
5. **Add snippet files:** Create `settings-snippet.json` or `config-snippet.toml` in your tool's folder to make copying the configuration easy for users.
6. **Test your code:** Verify that your scripts correctly parse the hooks/logs and format the message cleanly for the notification API you are targeting. Ensure that truncation logic exists for messages over the standard character limit (e.g., 4000 for Telegram).
7. **Commit** your changes with clear messages.
8. **Push** your branch and open a **Pull Request** against the `main` branch.

## Submitting Issues
If you find a bug or have a suggestion, please check if an issue already exists. If not, open a new issue describing:
- The problem or proposed feature.
- Steps to reproduce (if it's a bug).
- Which CLI tool and OS you are using.

We look forward to reviewing your contributions!
