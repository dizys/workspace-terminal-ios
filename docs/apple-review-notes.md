# Workspace Terminal - App Review Notes

## App Overview

Workspace Terminal is a native iOS terminal client for Coder — the open-source platform for cloud development environments. Connect to your Coder workspaces over the web and get a real, full-featured terminal on your iPhone and iPad.

**Why Workspace Terminal?**
Coder's web terminal works, but it's not built for mobile. Workspace Terminal replaces it with a first-class native experience: fast, responsive, and designed for touch.

## Key Features

**Terminal**
- Real PTY-over-WebSocket terminal with full ANSI color support
- SwiftTerm-powered emulator, the same reliable engine you already love
- JetBrains Mono Nerd Font with powerline glyph support for starship, oh-my-zsh, and p10k
- Pinch-to-zoom font size (8–32pt, persisted)

**Multi-Tab & Session Persistence**
- Multiple terminal tabs per workspace — swipe to switch
- Sessions persist across navigation — go back, come back, pick up where you left off
- Proactive reconnect on app resume — the terminal recovers automatically after a network blip

**Themes**
- 6 built-in themes: System, Tokyo Night, Catppuccin Mocha, Solarized Dark, Dracula, Gruvbox Dark
- Full 16-color ANSI palette per theme
- Dark-first design that matches your terminal workflow

**Workspace Management**
- Discover and manage Coder workspaces — start, stop, restart
- View listening ports on connected agents
- Live session badges show active terminal connections

**Authentication**
- Sign in via GitHub OAuth, OIDC (Okta, Azure AD, Google), or username/password
- Session token stored securely in Keychain
- Self-hosted Coder deployments fully supported

**Port Discovery**
- Automatically discover services running inside your workspace (requires coder server to configure custom proxy admin)
- See port numbers, process names, and common port hints (React, Vite, Django, etc.)
- Open forwarded ports in Safari via Coder's subdomain proxy

## Testing Instructions

### Demo Account

A test environment is available for review:

| Field            | Value                              |
| ---------------- | ---------------------------------- |
| Deployment URL   | `https://coder.memaxlabs.com`      |
| Login Method     | Email & Password                   |
| Email            | `test@memaxlabs.com`               |
| Password         | `xE3&%#mDJTC5`                     |

### Step-by-Step Walkthrough

#### 1. Sign In

1. Launch the app.
2. Enter the deployment URL: `https://coder.memaxlabs.com`
3. Tap **Next**.
4. Select **Email & Password** as the login method.
5. Enter the email and password from the table above.
6. Tap **Sign In**.

#### 2. Browse Workspaces

After signing in, the workspace list appears. Two test workspaces are pre-configured:

- **gold-swordfish-14** — A devcontainer-based workspace with 2 agents.
- **indigo-camel-80** — A Docker container workspace with 1 agent.

Tap a workspace to view its details, including status, agents, and listening ports.

#### 3. Open a Terminal Session

1. From a workspace detail screen, tap on an agent to open a terminal.
2. A terminal tab opens with a live shell session to the remote workspace.
3. Type commands (e.g., `ls`, `whoami`, `uname -a`) to interact with the remote environment.
4. Use the floating modifier key bar at the bottom for special keys (Esc, Ctrl, Tab, arrows).
5. Pinch to zoom the terminal font size.
6. Swipe between terminal tabs if multiple sessions are open.

#### 4. Manage Workspace Lifecycle

From the workspace detail screen:

- Tap **Stop** to stop a running workspace.
- Tap **Start** to start a stopped workspace.
- Observe the real-time build log streaming during workspace transitions.

#### 5. Customize Settings

Tap the user avatar (top-left) to open Settings:

- Change the terminal color theme.
- Adjust the font size.
- View open source licenses.
- Sign out.

## Privacy & Data

Workspace Terminal connects only to your own Coder deployment. No data is collected, no accounts required beyond your Coder login.
- Full privacy policy: https://workspaceterminal.app/privacy
