class_name NetUtil
extends RefCounted
## Finds the laptop's LAN IPv4 addresses, best guess (real Wi-Fi) first.

const VIRTUAL_HINTS := ["vethernet", "virtualbox", "vmware", "wsl", "hyper-v", "docker",
	"loopback", "bluetooth", "tailscale", "zerotier", "vpn", "tap", "tun", "hamachi", "npcap",
	"virbr", "veth", "br-"]


static func lan_addresses() -> PackedStringArray:
	var scored: Array = []
	var seen := {}
	for iface in IP.get_local_interfaces():
		var label := (str(iface.get("friendly", "")) + " " + str(iface.get("name", ""))).to_lower()
		for addr in iface.get("addresses", []):
			var ip := str(addr)
			if not ip.is_valid_ip_address() or ip.contains(":") or seen.has(ip):
				continue
			if ip.begins_with("127.") or ip.begins_with("169.254."):
				continue
			seen[ip] = true
			scored.append([_score(ip, label), ip])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var out := PackedStringArray()
	for s in scored:
		out.append(s[1])
	return out


static func _score(ip: String, label: String) -> int:
	var s := 0
	if ip.begins_with("192.168."):
		s += 30
	elif ip.begins_with("10."):
		s += 20
	elif ip.begins_with("172."):
		var second := int(ip.split(".")[1])
		s += 10 if second >= 16 and second <= 31 else 0
	if label.contains("wi-fi") or label.contains("wifi") or label.contains("wlan") or label.contains("wireless"):
		s += 50
	elif label.contains("ethernet") or label.begins_with("en") or label.contains(" en") or label.contains("eth"):
		s += 25
	for h in VIRTUAL_HINTS:
		if label.contains(h):
			s -= 100
			break
	return s
