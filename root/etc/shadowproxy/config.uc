import { cursor } from 'uci';
const uci = cursor();
uci.load('shadowproxy');

const main = uci.get_all('shadowproxy', '@main[0]') || uci.get_all('shadowproxy', 'main') || {};

const redir_port = int(main.redir_port || 0);
const dns_port = int(main.dns_port || 0);
const dns_remote_addr = main.dns_remote_addr || "8.8.8.8";
const dns_local_addr = main.dns_local_addr || "223.5.5.5";
const socks_port = int(main.socks_port || 0);
const http_port = int(main.http_port || 0);

const worker_count = int(main.worker_count || 0);

const selected_server_id = main.server || main.global_server || "";

let servers_list = [];
uci.foreach('shadowproxy', 'server', function(s) {
    let is_enabled = false;
    if (selected_server_id != "") {
        if (s['.name'] == selected_server_id) is_enabled = true;
    } else {
        if (s.enabled == '1' || s.enabled == 1 || s.enabled == 'true' || s.enabled == true) {
            is_enabled = true;
        }
    }

    if (is_enabled) {
        push(servers_list, {
            server: s.server,
            server_port: int(s.server_port),
            password: s.password,
            method: s.method
        });
    }
});

let locals = [];

if (socks_port > 0) {
    push(locals, {
        protocol: "socks",
        local_address: "::",
        local_port: socks_port,
        mode: "tcp_and_udp"
    });
}

if (http_port > 0) {
    push(locals, {
        protocol: "http",
        local_address: "::",
        local_port: http_port
    });
}

if (redir_port > 0) {
    push(locals, {
        local_address: "::",
        local_port: redir_port,
        protocol: "redir",
        tcp_redir: "tproxy",
        udp_redir: "tproxy",
        mode: "tcp_and_udp"
    });
}

if (dns_port > 0) {
    push(locals, {
        local_address: "::",
        local_port: dns_port,
        protocol: "dns",
        local_dns_address: dns_local_addr,
        local_dns_port: 53,
        remote_dns_address: dns_remote_addr,
        remote_dns_port: 53,
        acl: "/var/run/shadowproxy/shadowproxy-dns.acl",
        client_cache_size: 0,
        mode: "tcp_and_udp"
    });
}

let config = {
    locals: locals,
    servers: servers_list,
    timeout: 300,
    keep_alive: 60,
    nofile: 524288,
    ipv6_first: true,
    ipv6_only: false,
    outbound_fwmark: 255,
    no_delay: true,
    fast_open: true,
    mptcp: false,
    security: {
        replay_attack: {
            policy: "reject"
        }
    },
    balancer: {
        max_server_rtt: 5,
        check_interval: 10,
        check_best_interval: 5
    },
    log: {
        writers: [
            {
                console: {
                    level: 0,
                    format: {
                        without_time: true
                    }
                }
            },
            {
                file: {
                    level: 0,
                    directory: "/var/log",
                    rotation: "daily",
                    prefix: "shadowproxy",
                    suffix: "log",
                    max_files: 30
                }
            }
        ]
    }
};

if (worker_count == 1) {
    config.runtime = {
        mode: "single_thread"
    };
} else if (worker_count > 1) {
    config.runtime = {
        mode: "multi_thread",
        worker_count: worker_count
    };
}

print(sprintf("%.J\n", config));
