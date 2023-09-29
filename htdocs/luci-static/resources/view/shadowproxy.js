'use strict';
'require view';
'require form';
'require fs';

var methods = [
    "none",
    "table",
    "rc4",
    "rc4-md5",
    "aes-128-cfb",
    "aes-192-cfb",
    "aes-256-cfb",
    "aes-128-ctr",
    "aes-192-ctr",
    "aes-256-ctr",
    "aes-128-gcm",
    "aes-192-gcm",
    "aes-256-gcm",
    "camellia-128-cfb",
    "camellia-192-cfb",
    "camellia-256-cfb",
    "bf-cfb",
    "salsa20",
    "chacha20",
    "chacha20-ietf",
    "chacha20-ietf-poly1305",
    "xchacha20-ietf-poly1305",
]

var page = view.extend({
    render: function () {
        var m, s, o;

        m = new form.Map('shadowproxy', _('ShadowProxy'),
            _('ShadowProxy Configuration for tproxy redir and dns'));

        s = m.section(form.TypedSection, 'main', _('Main Settings'));
        s.anonymous = true;
        o = s.option(form.Value, 'redir_port', _('Redir Port'),
            _('redir local listening port'));
        o.datatype = 'port'
        o.rmempty = false;

        o = s.option(form.Value, 'dns_port', _('DNS Port'),
            _('dns local listening port'));
        o.datatype = 'port'
        o.rmempty = false;

        o = s.option(form.Value, 'dns_remote_addr', _('DNS Remote Server'),
            _('dns remote proxy server ip address'))
        o.datatype = 'ipaddr';
        o.rmempty = false;

        o = s.option(form.Value, 'dns_local_addr', _('DNS Local Server'),
            _('dns local server ip address'))
        o.datatype = 'ipaddr';
        o.rmempty = false;

        o = s.option(form.Value, 'worker_count', _('Worker Count'),
            _('thread worker count for processing connections'))
        o.datatype = 'range(3,128)';
        o.rmempty = false;

        s = m.section(form.GridSection, 'server', _('Servers'));
        s.anonymous = true;
        s.addremove = true;

        o = s.option(form.Flag, 'enabled', _('Enable'));
        o.editable = true;

        o = s.option(form.Value, 'server', _('Server'));
        o.datatype = 'host';

        o = s.option(form.Value, 'server_port', _('Port'));
        o.datatype = 'port';

        o = s.option(form.ListValue, 'method', _('Method'));
        methods.forEach(m => o.value(m));

        o = s.option(form.Value, 'password', _('Password'));
        o.password = true;
        o.modalonly = true;

        o = s.option(form.Value, 'plugin', _('Plugin'));
        o.modalonly = true;

        o = s.option(form.Value, 'plugin_opts', _('Plugin Options'));
        o.modalonly = true;

        s = m.section(form.TypedSection, 'acl', _('ACL Settings'),
            _('set acl rules for proxy domains and white ip list'));
        s.anonymous = true;
        s.tab('domain', _('Proxy Domain'));
        s.tab('bypass_ipset', _('Bypass Ipset'));

        var proxy_domain_file = '/etc/shadowproxy/shadowproxy-dns.acl'
        o = s.taboption("domain", form.TextValue, 'proxy_domain_list', "",
            _("proxy the target domains"));
        o.rows = 24;
        o.monospace = true;
        o.cfgvalue = function (section_id) {
            return fs.trimmed(proxy_domain_file);
        };
        o.write = function (section_id, formvalue) {
            return this.cfgvalue(section_id).then(function (value) {
                if (value == formvalue) {
                    return
                }
                return fs.write(proxy_domain_file, formvalue.trim().replace(/\r\n/g, '\n') + '\n');
            });
        };

        var bypass_ipset_file = '/etc/shadowproxy/bypass_ipset.acl';
        o = s.taboption("bypass_ipset", form.TextValue, 'bypass_ipset_list', "",
            _('bypass the ipv4 and ipv6 address'));
        o.rows = 24;
        o.monospace = true;
        o.cfgvalue = function (section_id) {
            return fs.trimmed(bypass_ipset_file);
        };
        o.write = function (section_id, formvalue) {
            return this.cfgvalue(section_id).then(function (value) {
                if (value == formvalue) {
                    return
                }
                return fs.write(bypass_ipset_file, formvalue.trim().replace(/\r\n/g, '\n') + '\n');
            });
        };

        return m.render();
    }
});

return page;

