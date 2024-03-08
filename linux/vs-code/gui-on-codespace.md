# GUI on Codespace

1. Create a Codespace
2. mkdir .devcontainer/ ; touch devcontainer.json
3. echo "features": {"ghcr.io/devcontainers/features/desktop-lite:1": {\}} >> .devcontainer/devcontainer.json
4. Forward port 6080 in vscode port menu
5. Click on globe icon to connect to localhost:6080
6. password vscode by default
7. Any GUI app will launch on NoVNC
