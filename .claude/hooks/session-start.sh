#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "Installing remotion-dev skills..."
if ! npx -y skills@latest add remotion-dev/skills -g -y 2>&1; then
  echo "Warning: remotion-dev skills install failed (retrying with SSH)..."
  npx -y skills@latest add git@github.com:remotion-dev/skills.git -g -y 2>&1 \
    || echo "Warning: skills installation skipped (no GitHub auth available)"
fi

VENV_DIR="${CLAUDE_PROJECT_DIR}/.venv"
echo "Setting up Python virtual environment..."
python3 -m venv "${VENV_DIR}"
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "Installing Python backend dependencies..."
# langdetect has no binary wheel; --no-build-isolation works around the Debian setuptools incompatibility
pip install langdetect==1.0.9 --no-build-isolation --quiet
pip install -r "${CLAUDE_PROJECT_DIR}/backend/requirements.txt" --prefer-binary --quiet

# Persist venv activation and test env vars for the session
echo "export PATH=\"${VENV_DIR}/bin:\$PATH\"" >> "${CLAUDE_ENV_FILE:-/dev/null}"
echo "export VIRTUAL_ENV=\"${VENV_DIR}\"" >> "${CLAUDE_ENV_FILE:-/dev/null}"
echo "export PYTHONPATH=\"${CLAUDE_PROJECT_DIR}\"" >> "${CLAUDE_ENV_FILE:-/dev/null}"
echo "export DEV_MODE=true" >> "${CLAUDE_ENV_FILE:-/dev/null}"

echo "Session start complete."
