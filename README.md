# Shadowproxy for OpenWrt

A lightweight, experimental Shadowsocks transparent proxy solution tailored for the OpenWrt fw4 (nftables) environment.

As OpenWrt transitions entirely to `nftables`, traditional `iptables`-based redirection can feel a bit heavy and cumbersome to maintain. Shadowproxy is a modest attempt to build a routing scheme that natively utilizes `nftables` `tproxy` features. By relying on the `ucode` engine for dynamic configuration rendering and integrating with the system's `procd` init daemon, it aims to provide a cleaner and relatively stable proxy experience. It was originally built for personal use, but hopefully, it can be of some value to the community.

## ✨ Features

* **Native nftables Integration**: Hooks directly into the OpenWrt fw4 firewall framework, utilizing `nft sets` for bypass and proxy lists to help maintain efficient lookup speeds.
* **Atomic Rule Updates**: Attempts to use atomic transactions for firewall rule reloads, reducing the chance of temporary traffic leaks or network drops during rule swapping.
* **TCP & UDP Tproxy Support**: Leverages `tproxy` and `socket` kernel modules to handle both TCP and UDP traffic transparently.
* **ucode-driven Configuration**: Uses OpenWrt's native `ucode` engine to compile UCI configurations directly into a JSON format readable by `sslocal`, avoiding messy shell string concatenations.
* **Standard procd Integration**: Hooks natively into the system's service lifecycle, supporting configuration hash comparisons, auto-respawn, and network interface triggers.

## 📦 Dependencies

Before installing or compiling, please ensure your system has the following packages:

* **Kernel Modules**:
* `kmod-nft-tproxy`
* `kmod-nft-socket`


* **System Utilities**:
* `ucode` (for AST-based configuration generation)



## 🚀 Binary Installation (Important)

To keep the package footprint as small as possible and leave the architecture choices entirely up to you, **this repository does not bundle the `sslocal` executable** (typically provided by `shadowsocks-rust`).

You will need to provide the core binary using one of the following methods:

### Method 1: Inject before compiling (For ROM Builders)

Before compiling your OpenWrt firmware or building the `.ipk`, rename your downloaded binary to `ssservice` and place it in the `bin/` directory of this source tree:

```bash
shadowproxy/bin/ssservice

```

The build system will automatically pick it up and install it to the correct path on the target device.

### Method 2: Manual deployment (For General Users)

If you have already installed the Shadowproxy `.ipk`, simply download the appropriate `sslocal` (or `ssservice`) binary for your router's architecture, upload it via SSH to the `/usr/bin/` directory, and grant it execution permissions:

```bash
# Assuming you have uploaded the file to /tmp/sslocal
mv /tmp/sslocal /usr/bin/sslocal
chmod +x /usr/bin/sslocal

```

## ⚙️ Directory Structure

Shadowproxy relies on the following directory layout to keep things organized:

* **`/etc/config/shadowproxy`**: The main UCI configuration source (used by LuCI or CLI).
* **`/etc/shadowproxy/`**: Persistent data and rules directory.
* `shadowproxy.nft`: Core firewall logic definitions.
* `config.uc`: The ucode template file.
* `bypass_ipset.acl`: Custom direct-connection IP/CIDR lists.
* `proxy_domains.acl`: Domains forced to route through the proxy.


* **`/var/run/shadowproxy/`**: Runtime directory in RAM Disk. Stores the generated `config.json` and temporary `atomic.nft`. Clearing on reboot helps reduce flash memory wear.

## 🛠️ Service Management

Thanks to the standard `procd` integration, you can manage the service using typical OpenWrt commands:

```bash
# Start the service
/etc/init.d/shadowproxy start

# Stop the service
/etc/init.d/shadowproxy stop

# Reload configuration (Use after UCI changes or ACL updates)
/etc/init.d/shadowproxy reload

# Check service status
/etc/init.d/shadowproxy status

```
