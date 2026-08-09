# 🛡️ System Security Manager (Telemetry & DNS Tool)

A lightweight, portable, and open-source PowerShell tool designed to enhance your system's privacy and security. It allows you to easily switch DNS providers and block Windows telemetry and trackers system-wide using the Hosts file without freezing your system.

[![Download Latest Release](https://img.shields.io/badge/Download-Latest_Release-2ea44f?style=for-the-badge&logo=github&logoColor=white)](https://github.com/osmanonurkoc/Telemetry-DNS-Manager/releases/latest)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-0078D4.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-v5.1%2B-5391FE.svg)
![Downloads](https://img.shields.io/github/downloads/osmanonurkoc/Telemetry-DNS-Manager/total)
![Release](https://img.shields.io/github/v/release/osmanonurkoc/Telemetry-DNS-Manager)

## 📸 Screenshots

![Application Interface](images/screenshot1.png) ![Application Interface](images/screenshot2.png) ![Application Interface](images/screenshot3.png) ![Application Interface](images/screenshot4.png)
*The modern, dark/light-themed UI allowing quick DNS toggling and host file updates.*

## ✨ Features

- **🌐 DNS Manager:** 
  - Quickly switch between popular DNS providers (Google, Cloudflare, Quad9, AdGuard, OpenDNS).
  - Easily revert to Default (DHCP) with a single click.
- **🚫 Telemetry Blocker via Hosts:** 
  - Blocks Windows telemetry, data collection, and tracker domains by modifying the Windows `hosts` file.
  - Uses the highly trusted and lightweight [WindowsSpyBlocker](https://github.com/crazy-max/WindowsSpyBlocker) list to prevent Windows `Dnscache` crashes and network drops.
- **⚡ Zero UI Freezing:** 
  - Utilizes pure native `.NET File I/O` methods instead of standard PowerShell pipelines for instant, lag-free file operations.
- **🧠 Smart Merge Logic:** 
  - **Preserves your data:** If you have custom entries in your hosts file (e.g., for local development), this tool *will not* delete them. It only manages its own blocklist section.
- **🎨 Modern UI:** 
  - Clean WPF-based Graphical User Interface.
  - **Auto-Theme:** Automatically adapts to your Windows Light or Dark mode settings.
- **📦 Portable:** 
  - Single `.ps1` file. No installation required.

## 🚀 Getting Started

### Prerequisites
- **OS:** Windows 10 or Windows 11 (64-bit required).
- **Permissions:** Must be run as **Administrator** (required to modify Network settings and System files).

### Installation & Usage

#### Option 1: Using the Executable (Recommended)
1. Download the latest `.exe` from the **[Releases Page](https://github.com/osmanonurkoc/Telemetry-DNS-Manager/releases/latest)**.
2. Double-click the executable to run.

#### Option 2: Running the Script (For Developers)
1. Download the source code.
2. Right-click the `.ps1` file and select **Run with PowerShell**.
   * *Note:* If you encounter an Execution Policy error, run this command in PowerShell once:
     ```powershell
     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
     ```
     
### ⚠️ Antivirus Warnings (False Positives)

You may notice that some antivirus engines (such as Windows Defender, SentinelOne, or CrowdStrike) flag the `.exe` release of this tool as suspicious (e.g., `Trojan:Win32/Wacatac`, `MachineLearning/Anomalous`, or `Generic.Malware`).

**This is a known False Positive.**

#### Why is this happening?

This application is originally a **PowerShell script** converted into an executable (`.exe`) to make it easier to run. Modern antivirus "AI" and "Heuristic" engines often aggressively block _any_ unsigned program that executes PowerShell commands internally, classifying them as "droppers" or "loaders" by default, even if the code itself is completely safe.

#### I don't trust the EXE. What should I do?

Since this project is open-source, **you do not have to use the EXE file.**

If your antivirus blocks the executable or if you prefer full transparency, you can run the source script directly:

1.  Download the `.ps1` file from this repository.
2.  Right-click the file and select **Run with PowerShell**.
3.  _(Note: You may need to enable script execution by running `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` in PowerShell once)._

We provide the compiled `.exe` solely for convenience (icon support, double-click execution). The code logic is identical to the `.ps1` script.
     
## 🛠️ How It Works

1. **DNS Changer:** Uses native PowerShell commands (`Set-DnsClientServerAddress`) to change the DNS servers of your active network adapter.
2. **Hosts Blocker:** 
   - Downloads a raw text list of telemetry and tracking servers.
   - Parses and formats them into a Windows-compatible format instantly using pure .NET logic.
   - Appends them to `C:\Windows\System32\drivers\etc\hosts` inside a tagged block.
   - Creates a backup (`hosts.bak`) automatically before the first run.

## ⚠️ Disclaimer
This tool modifies system files (`hosts`) and network settings. While it includes safety features (backups and smart merging), **use it at your own risk**. 
- Always ensure you have a system restore point if you are unsure.
- VPNs or other security software might conflict with DNS settings.

## 📄 License
This project is licensed under the [MIT License](LICENSE).

---
*Created by [@osmanonurkoc](https://github.com/osmanonurkoc)*
