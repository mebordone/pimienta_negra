-- Pimienta Negra: Prosody para chat XMPP en LAN (HTTP + WebSocket, sin MAM).
-- Dominios: pimienta.local (anónimo), accounts.pimienta.local (cuentas + admin), MUC en conference.pimienta.local

pidfile = "/var/run/prosody/prosody.pid";

plugin_paths = { "/usr/lib/prosody/modules/" }

admins = { "admin@accounts.pimienta.local" }

modules_enabled = {
	"disco";
	"roster";
	"saslauth";
	"tls";
	"dialback";
	"private";
	"limits";
	"ping";
	"time";
	"uptime";
	"version";
	"admin_adhoc";
	"admin_shell";
	"http";
	"websocket";
	"bosh";
	"register";
	"blocklist";
}

log = {
	info = "*console";
}

-- Sin mod_mam: chat efímero (sin archivo de mensajes en servidor).
allow_registration = false

-- HTTP interno (nginx hace proxy a /xmpp-websocket)
http_ports = { 5280 }
http_interfaces = { "*", "::" }

-- LAN detrás de nginx sin TLS en el navegador
c2s_require_encryption = false
s2s_require_encryption = false

consider_broken_secure_connection = true
consider_websocket_secure = true

VirtualHost "pimienta.local"
	authentication = "anonymous"
	allow_registration = false
	ssl = {
		certificate = "/etc/prosody/certs/pimienta.local.crt";
		key = "/etc/prosody/certs/pimienta.local.key";
	}

VirtualHost "accounts.pimienta.local"
	authentication = "internal_hashed"
	allow_registration = true
	ssl = {
		certificate = "/etc/prosody/certs/accounts.pimienta.local.crt";
		key = "/etc/prosody/certs/accounts.pimienta.local.key";
	}

Component "conference.pimienta.local" "muc"
	restrict_room_creation = false
	muc_room_default_public = true
	muc_room_default_persistent = false
	muc_room_default_members_only = false
	muc_room_default_allow_member_invites = true
	ssl = {
		certificate = "/etc/prosody/certs/conference.pimienta.local.crt";
		key = "/etc/prosody/certs/conference.pimienta.local.key";
	}

Include "/etc/prosody/conf.d/*.cfg.lua"
