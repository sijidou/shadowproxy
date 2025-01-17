ShadowProxy - OpenWrt LuCI for Shadowsocks-Rust
===

Introduction
---

It supports to configure shadowsocks-rust tproxy(redir) and dns acl on openwrt, with LuCI interface.

Wish it helps.

Install
---

1. download the last ipk release file.
2. `System(系统)` -> `Software Package(软件包)` -> `Upload(上传安装)` 

Or `scp` and `opkg install shadowproxy_xxx.ipk`

Configuration
---

In main setting, it is better to set your local dns server, which could be found in `/tmp/resolve.conf.ppp` or `/tmp/resolv.conf.d/resolv.conf.auto`.

![main settings](main-setting.png)

Add your shadowsocks servers in the server section. It's better to configure both ipv4 and ipv6 for one same server together. It will check which ip route is better to reach the server. 

![server](server.png)

Click `Save&Apply`

Dependency
---

1. `sslocal`, the executable shadowsocks-rust binary file is extracted from shadowsocks-rust releases. For convenient and security, the repo contains a `sslocal` file, which contains updated features for better network connection. If you have any security concerns, please compile from the source code with features `local-dns,local-redir,security-replay-attack-detect`.
2. `nftables` and `iptables`, now it supports only `nftables`, which requires less coding work. 

Configuration
---

All configuration files are under `/etc/shadowproxy`. A `config-template.json` file is updated by the `/etc/init.d/shadowproxy` with uci configuration from `/etc/config/shadowproxy`.

Q&A
---

1. Installed but not appears in browser
    - `rm -rf /tmp/luci-*`
    - In Chrome `Developer Tools -> Network -> Disable Cache`

2. How to install without `ipk`
    - Copy sslocal to `/usr/bin/sslocal`
    - Copy `htdocs/*` to `/www/`
    - Copy `root/*` to `/`
    - `/etc/init.d/shadowproxy enable`

3. First time configuration (bug to fix)
    - The `/etc/init.d/shadowproxy` will config `dnsmasq` server automatically. If you did not set the correct server, you may not be able to reach network, because no dns server available. Configure your server and save apply.
4. Supported Devices
   - aarch64-musl (armv8)
   - x86_64-musl
   - x86_64-gnu
5. Why plugins are not suggested?
   - the plugins support in shadowsocks-rust, it starts another child process to auto proxy packets. which consumes hardware resources. And in such case, it is recommended that using v2ray or clash directly. 
6. What is `err_cert_common_name_invalid`
   - restart the browser or clear all caches. 
7. How to support openwrt-21
   - Check the [openwrt nftables doc](https://openwrt.org/docs/guide-user/firewall/misc/nftables)
   - opkg update && opkg install nftables kmod-nft-tproxy
8. How to set up shadowsocks-rust server
   - the x86-64 gnu file `ssserver` is also supplied.  
9. How to support other countries?
   - Change the ip set in `chnip4.ips` and `chnip6.ips`, by default, no update is required for `shadowproxy-dns-base.acl`, and redir will proxy all data. Any PR is welcome
10. How to use both IPV4 and IPV6?
   - If your local network enabled IPV6, then you'd better configure an IPV6 server. Or you could not connect, for some domains are resolved with ipv6 addresses.
   - If you only have IPV4 locally, you can use an IPV4 server only. For some VPS servers, only IPV4 available.
11. How does DNS resolved?
   - dnsmasq is still the main dns server. But dnsmasq will reroute packets to upstream, which is our local dns server. the local dns server would reroute the packets to remote overseas public dns server based on the acl table.  