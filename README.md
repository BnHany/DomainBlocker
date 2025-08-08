# Domain Blocker Tool v1.3

> A powerful Bash-based tool to block or unblock domain access on Linux systems using iptables and ip6tables, with automatic IP resolution and scheduled updates.
> 

---

## Features

- Block or  Unblock any domain (IPv4 and IPv6 supported).
- Choose to block **Incoming**, **Outgoing**, or **Both** traffic directions.
- Automatically resolves domains and tracks IP changes.
- Stores all rules in a persistent `blocked_rules.db` file.
- Supports daily **auto-updates** via cron to handle DNS/IP changes.
- User-friendly interactive terminal menu.

---

## Prerequisites

To ensure smooth operation of **Domain Blocker Tool v1.3**, your system must meet the following requirements:

### 1. **Operating System**

- Linux-based system (Debian, Ubuntu, Kali and more )
- Compatible with:
    - `iptables` (for IPv4)
    - `ip6tables` (for IPv6)
    - `cron` (for scheduled tasks)

> Not supported on Windows or macOS (unless running a full Linux environment).
> 

Before running the tool, ensure your system meets these requirements:

- **Root access** (required to modify firewall rules):
    - **Bash shell** (default in most Linux systems)
- **Required packages**:
    - `iptables` and `ip6tables` – for managing IPv4/IPv6 rules
    - `dig` – used to resolve domain names to IPs (comes with `dnsutils`)

### Install & Setup
- Update package lists & install dependencies:
```bash
sudo apt update
sudo apt install -y iptables ip6tables dnsutils cron
```
- Clone the repo and make the script executable:

```bash
git clone https://github.com/BnHany/DomainBlocker.git
cd DomainBlocker
chmod +x DomainBlocker.sh
```
- Run the tool (requires root):
```bash
sudo ./DomainBlocker.sh
```
> Make sure your system supports cron (used for scheduled updates).
> 

---

## File Structure

| File | Description |
| --- | --- |
| `domain_blocker` | Main Bash script |
| `blocked_rules.db` | Database storing blocked domains and IPs Rules  |

---

## Useful Commands for Verification

You can check applied firewall rules using:

```bash
sudo iptables -L -n
sudo ip6tables -L -n
cat blocked_rules.db
```

---
[**📖 Read Full Guide on Medium →**](https://bnhany.medium.com/domain-blocker-tool-v1-3-e056bf3a1d88)  
---

## Author

**BnHany**

© 2025 — Built with ❤️ to empower Linux users with simple domain control.

---

## License

**MIT License**

Feel free to use, modify, and distribute. Please give proper credit and use responsibly.