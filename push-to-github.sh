#!/usr/bin/env bash
#
# One-command publish of this project to a NEW private GitHub repo `plotline-ios`
# under your account (kaushik-reddy). Run this ONCE on your Mac after unzipping /
# copying the folder. It initializes git, creates the repo, and pushes.
#
#   chmod +x push-to-github.sh
#   ./push-to-github.sh
#
# Requirements: the GitHub CLI (`gh`). If it isn't installed:
#   brew install gh          # (installs Homebrew's gh)
# Then authenticate once:
#   gh auth login            # choose GitHub.com > HTTPS > login with a browser
#
set -euo pipefail

REPO_NAME="plotline-ios"
GH_USER="kaushik-reddy"
BRANCH="main"

cd "$(dirname "$0")"

echo "==> Checking prerequisites..."
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed. Install Xcode command line tools: xcode-select --install"
  exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is not installed."
  echo "       Install it with:  brew install gh"
  echo "       Then run:         gh auth login"
  exit 1
fi

# Make sure we're authenticated.
if ! gh auth status >/dev/null 2>&1; then
  echo "==> You are not logged in to GitHub CLI. Launching login..."
  gh auth login
fi

echo "==> Initializing git repository..."
if [ ! -d .git ]; then
  git init -b "$BRANCH"
else
  git checkout -B "$BRANCH"
fi

# Use your GitHub no-reply identity locally (keeps your email private).
git config user.name  "kaushik-reddy"
git config user.email "30206245+kaushik-reddy@users.noreply.github.com"

git add -A
git commit -m "PlotLine iOS — native SwiftUI app (initial commit)" || echo "==> Nothing to commit."

echo "==> Creating GitHub repo ${GH_USER}/${REPO_NAME} (private) and pushing..."
if gh repo view "${GH_USER}/${REPO_NAME}" >/dev/null 2>&1; then
  echo "==> Repo already exists. Adding remote and pushing."
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/${GH_USER}/${REPO_NAME}.git"
  git push -u origin "$BRANCH"
else
  gh repo create "${GH_USER}/${REPO_NAME}" --private --source=. --remote=origin --push
fi

echo ""
echo "Done. Repo: https://github.com/${GH_USER}/${REPO_NAME}"
echo "Open PlotLine.xcodeproj in Xcode, pick your team under Signing & Capabilities, and Run."
