## 🏗️ Multipass GitLab Runner

This project automates the provisioning of a GitLab Runner inside a lightweight Ubuntu VM using Multipass. It's fast, reproducible, and deployable with a single command.

---

## ✨ Features

- 🔄 One-command GitLab runner deployment with `start.sh`
- 📦 Auto-provisioned runner using cloud-init
- 🐧 Works on Windows, macOS, and Linux
- 🏷️ Supports GitLab runner tags (e.g. `cypress`)
- 🔁 Easily rebuild, restart, or debug your runner VM

---

## ⚙️ Requirements

- Multipass (see install instructions below)
- A GitLab registration token
- Git Bash (for Windows users)

---

## 💻 Installation

### 🪟 Windows

1. Install Chocolatey:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; `
   [System.Net.ServicePointManager]::SecurityProtocol = `
   [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
   iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
   ```

2. Install Multipass:
   ```powershell
   choco install multipass
   ```

3. Run:
   ```bash
   ./start.sh
   ```

> 🧠 Use Git Bash for running scripts on Windows.

---

### 🍏 macOS

1. Install Homebrew:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Install Multipass:
   ```bash
   brew install --cask multipass
   ```

3. Run:
   ```bash
   ./start.sh
   ```

---

### 🐧 Linux

1. Install Snap:
   ```bash
   sudo apt update
   sudo apt install snapd
   ```

2. Install Multipass:
   ```bash
   sudo snap install multipass
   ```

3. Run:
   ```bash
   ./start.sh
   ```

---

## 🧾 Configuration

Copy and configure `.env` using the included example:

📄 See [.env.example](./.env.example) for all options.

---

## 🚀 Usage

Start or rebuild the VM:

```bash
./start.sh     # spin up or resume
./rebuild.sh   # destroy and recreate
```

Get a shell inside the VM:

```bash
multipass shell $VM_NAME
```

---

## 🔧 Use Cases

This repo is especially useful for jobs that need:

- 🧪 **Cypress E2E Testing**
  - Use tag `cypress` in your GitLab CI job
  - Offload Chrome/Electron tests to local VM

Other potential use cases:

- 🐳 Docker-based builds (Node, Python, Go, etc.)
- 🧬 Containerized integration tests
- 📸 Visual regression testing (e.g. Percy, Playwright)
- 📦 Packaging or CI caching in self-contained environments

---

## ❤️ Contributions

Feel free to fork, extend, or open PRs — this project welcomes improvements!