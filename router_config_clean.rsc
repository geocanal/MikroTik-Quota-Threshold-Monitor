# 2026-09-27 14:49:15 by RouterOS 7.16.2
# software id = 4ZCK-XLXT
#
# model = RBD52G-5HacD2HnD
# serial number = B4A00A14E174
/interface bridge
add admin-mac=74:4D:28:83:FE:33 auto-mac=no comment=defconf name=bridge
/interface ethernet
set [ find default-name=ether5 ] name=WAN1
set [ find default-name=ether4 ] mtu=1480 name=WAN2
/interface list
add comment=defconf name=WAN
add comment=defconf name=LAN
/ip hotspot profile
set [ find default=yes ] login-by=mac,cookie,http-chap,http-pap,mac-cookie \
    mac-auth-password=000
add dns-name=ahmed.salem.com hotspot-address=192.168.88.1 html-directory=\
    flash/hotspot http-cookie-lifetime=4w2d login-by=\
    mac,cookie,http-chap,http-pap,mac-cookie mac-auth-password=000 name=\
    hsprof1
/ip hotspot user profile
set [ find default=yes ] shared-users=10
add name="NEW USER" on-login=":local a \$user\r\
    \n:local t [/system clock get time ]\r\
    \n:local d [/system clock get date ]\r\
    \n:local m [/ip hotspot active get [find user=\$a] mac-address]\r\
    \n:local i [/ip hotspot active get [find user=\$a] address]\r\
    \n:local n [/ip hotspot user get \$a name]\r\
    \n:if ( [ /ip hotspot user get \$a comment ] = \"\" ) do={\r\
    \n/ip hotspot user remove [find mac-address=\$m];\r\
    \n/ip hotspot user set \$a name=\$m mac-address=\$m password=000 address=\
    \$i comment=\"\$d---\$t---\$n\";\r\
    \n/ip hotspot host remove [find mac-address=\$m]\r\
    \n}\r\
    \n\r\
    \n" rate-limit=128K/512K
add name="1  M" rate-limit=512K/1024K
add name="2  M" rate-limit=1024K/2048K
add name="3  M" rate-limit=1024K/3072K
add name="4  M" rate-limit=2048K/4096K
add name="5  M" rate-limit=2048K/5120K
add name="6  M" rate-limit=2048K/6144K
add name="7  M" rate-limit=2048K/7168K
add name="8  M" rate-limit=2048K/8192K shared-users=50
add name=128K rate-limit=64K/128K
add name=256K rate-limit=128K/256K
add name=512K rate-limit=256K/512K
add name=LIMIT-HIT rate-limit=64K/128K shared-users=50
/ip pool
add name=default-dhcp ranges=192.168.88.100-192.168.88.254
add name=hs-pool ranges=192.168.88.100-192.168.88.254
/ip dhcp-server
add address-pool=default-dhcp interface=bridge name=defconf
/ip hotspot
add address-pool=hs-pool disabled=no interface=bridge name=hotspot1 profile=\
    hsprof1
/queue type
add kind=pcq name=WAN1-UP-PCQ pcq-classifier=src-address pcq-rate=3300k
add kind=pcq name=WAN2-UP-PCQ pcq-classifier=src-address pcq-rate=4200k
/queue simple
add max-limit=3400k/60M name=LAN-SAFE-QOS queue=\
    pcq-upload-default/pcq-download-default target=192.168.88.0/24
/queue tree
add disabled=yes max-limit=3300k name=WAN1-UP parent=WAN1 queue=WAN1-UP-PCQ
add disabled=yes max-limit=4200k name=WAN2-UP parent=WAN2 queue=WAN2-UP-PCQ
/routing table
add fib name=to_WAN1
add fib name=to_WAN2
add comment="PBR Routing Table for WAN1 (Vodafone)" disabled=no fib name=\
    to_wan1
add comment="PBR Routing Table for WAN2 (WE Egypt)" disabled=no fib name=\
    to_wan2
/zerotier
set zt1 comment="ZeroTier Central controller - https://my.zerotier.com/" \
    name=zt1 port=9993
/zerotier interface
add allow-default=no allow-global=no allow-managed=yes disabled=no instance=\
    zt1 name=zerotier1 network=65228D8D6D4C0FEB
/disk settings
set auto-media-interface=bridge auto-media-sharing=yes auto-smb-sharing=yes
/interface bridge port
add bridge=bridge comment=defconf interface=ether3
add bridge=bridge interface=ether1
add bridge=bridge interface=ether2
/ip neighbor discovery-settings
set discover-interface-list=LAN
/ipv6 settings
set disable-ipv6=yes
/interface detect-internet
set detect-interface-list=all
/interface list member
add comment=defconf interface=bridge list=LAN
add comment=defconf interface=WAN1 list=WAN
add comment=defconf interface=WAN2 list=WAN
add interface=zerotier1 list=LAN
/ip address
add address=192.168.88.1/24 comment=defconf interface=bridge network=\
    192.168.88.0
/ip arp
add address=192.168.88.80 interface=bridge
add address=192.168.88.5 interface=bridge mac-address=5C:A6:E6:05:48:6D
/ip dhcp-client
add add-default-route=no comment=defconf interface=WAN1 use-peer-dns=no \
    use-peer-ntp=no
add add-default-route=no interface=WAN2 use-peer-dns=no use-peer-ntp=no
/ip dhcp-server lease
add address=192.168.88.250 client-id=1:54:52:84:d0:ce:6b mac-address=\
    54:52:84:D0:CE:6B server=defconf
add address=192.168.88.49 client-id=1:ac:9e:17:86:5a:ac mac-address=\
    AC:9E:17:86:5A:AC server=defconf
add address=192.168.88.80 comment="Huawei AP" mac-address=54:52:84:D0:CE:6B
/ip dhcp-server network
add address=192.168.88.0/24 comment=defconf dns-server=192.168.88.1 gateway=\
    192.168.88.1 netmask=24
/ip dns
set allow-remote-requests=yes cache-size=4096KiB max-concurrent-queries=200 \
    servers=8.8.8.8,1.1.1.1
/ip dns static
add address=192.168.88.1 comment=defconf name=router.lan type=A
/ip firewall filter
add action=drop chain=forward comment="Drop QUIC Immediately" disabled=yes \
    dst-port=443 protocol=udp
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid disabled=yes
add action=accept chain=input comment="defconf: accept ICMP" protocol=icmp
add action=accept chain=input comment=\
    "defconf: accept to local loopback (for CAPsMAN)" dst-address=127.0.0.1
add action=drop chain=input comment="defconf: drop all not coming from LAN" \
    in-interface-list=!LAN
add action=fasttrack-connection chain=forward comment=FastTrack \
    connection-state=established,related disabled=yes hw-offload=yes
add action=accept chain=forward comment="defconf: accept in ipsec policy" \
    ipsec-policy=in,ipsec
add action=accept chain=forward comment="defconf: accept out ipsec policy" \
    ipsec-policy=out,ipsec
add action=accept chain=forward comment=\
    "defconf: accept established,related, untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" \
    connection-state=invalid disabled=yes
add action=drop chain=forward comment=\
    "defconf: drop all from WAN not DSTNATed" connection-nat-state=!dstnat \
    connection-state=new in-interface-list=WAN
add action=drop chain=input comment="Drop blacklisted SSH" connection-state=\
    new dst-port=22 protocol=tcp src-address-list=ssh_blacklist
add action=add-src-to-address-list address-list=ssh_stage1 \
    address-list-timeout=1m chain=input comment="SSH Stage1" \
    connection-state=new dst-port=22 protocol=tcp
add action=add-src-to-address-list address-list=ssh_stage2 \
    address-list-timeout=1m chain=input comment="SSH Stage2" \
    connection-state=new dst-port=22 protocol=tcp src-address-list=ssh_stage1
add action=add-src-to-address-list address-list=ssh_blacklist \
    address-list-timeout=1d chain=input comment="SSH Blacklist" \
    connection-state=new dst-port=22 protocol=tcp src-address-list=ssh_stage2
add action=accept chain=input comment="Allow DNS UDP from LAN" dst-port=53 \
    protocol=udp src-address=192.168.88.0/24
add action=accept chain=input comment="Allow DNS TCP from LAN" dst-port=53 \
    protocol=tcp src-address=192.168.88.0/24
add action=drop chain=input comment="Drop DNS UDP non-LAN" dst-port=53 \
    protocol=udp
add action=drop chain=input comment="Drop DNS TCP non-LAN" dst-port=53 \
    protocol=tcp
/ip firewall mangle
add action=change-mss chain=forward comment="Fix Social Media MSS" new-mss=\
    1360 passthrough=yes protocol=tcp tcp-flags=syn tcp-mss=1400-65535
add action=change-mss chain=forward comment="Force Low MSS for Testing" \
    new-mss=1280 passthrough=yes protocol=tcp tcp-flags=syn tcp-mss=\
    1281-65535
add action=mark-connection chain=prerouting comment=\
    WCCP-WAN2-ISOLATION-OVERRIDE connection-mark=no-mark connection-state=new \
    dst-address-type=!local hotspot=from-client in-interface=bridge \
    new-connection-mark=cm_wan1 passthrough=yes
add action=mark-connection chain=prerouting comment=\
    WCCP-WAN1-ISOLATION-OVERRIDE connection-mark=no-mark connection-state=new \
    disabled=yes dst-address-type=!local hotspot=from-client in-interface=\
    bridge new-connection-mark=cm_wan2 passthrough=yes
add action=mark-connection chain=prerouting comment=WCCP-CLIENT-PCC-WAN1 \
    connection-mark=no-mark connection-state=new dst-address-type=!local \
    hotspot=from-client in-interface=bridge new-connection-mark=cm_wan1 \
    passthrough=yes per-connection-classifier=both-addresses-and-ports:2/0
add action=mark-connection chain=prerouting comment=WCCP-CLIENT-PCC-WAN2 \
    connection-mark=no-mark connection-state=new dst-address-type=!local \
    hotspot=from-client in-interface=bridge new-connection-mark=cm_wan2 \
    passthrough=yes per-connection-classifier=both-addresses-and-ports:2/1
add action=mark-routing chain=prerouting comment=WCCP-CLIENT-ROUTE-WAN2 \
    connection-mark=cm_wan2 dst-address-type=!local hotspot=from-client \
    in-interface=bridge new-routing-mark=to_WAN2 passthrough=no
add action=mark-routing chain=prerouting comment=WCCP-CLIENT-ROUTE-WAN1 \
    connection-mark=cm_wan1 dst-address-type=!local hotspot=from-client \
    in-interface=bridge new-routing-mark=to_WAN1 passthrough=no
add action=accept chain=prerouting comment="Hotspot authenticated bypass" \
    hotspot=from-client
add action=mark-connection chain=prerouting connection-mark=no-mark disabled=\
    yes in-interface=bridge new-connection-mark=WAN1_conn \
    per-connection-classifier=both-addresses-and-ports:2/0
add action=mark-connection chain=prerouting connection-mark=no-mark disabled=\
    yes in-interface=bridge new-connection-mark=WAN2_conn \
    per-connection-classifier=both-addresses-and-ports:2/1
add action=mark-routing chain=prerouting connection-mark=WAN1_conn disabled=\
    yes new-routing-mark=*404 passthrough=no
add action=mark-routing chain=prerouting connection-mark=WAN2_conn disabled=\
    yes new-routing-mark=*405 passthrough=no
add action=mark-routing chain=output connection-mark=WAN1_conn disabled=yes \
    new-routing-mark=*404
add action=mark-routing chain=output connection-mark=WAN2_conn disabled=yes \
    new-routing-mark=*405
add action=mark-routing chain=output comment="Force DoH through WAN1" \
    disabled=yes dst-port=443 new-routing-mark=*404 passthrough=no protocol=\
    udp
add action=accept chain=prerouting comment=\
    "RULE-01: Bypass router-bound traffic" dst-address-type=local
add action=accept chain=prerouting comment=\
    "RULE-02: Bypass RFC1918 private traffic" dst-address=192.168.0.0/16
add action=mark-connection chain=prerouting comment=\
    "RULE-09: PCC Balancer 2/0 -> WAN1" connection-mark=no-mark \
    connection-state=new in-interface=bridge new-connection-mark=cm_wan1 \
    passthrough=yes per-connection-classifier=both-addresses-and-ports:2/0
add action=mark-connection chain=prerouting comment=\
    "RULE-10: PCC Balancer 2/1 -> WAN2" connection-mark=no-mark \
    connection-state=new disabled=yes in-interface=bridge \
    new-connection-mark=cm_wan2 passthrough=yes per-connection-classifier=\
    both-addresses-and-ports:2/1
add action=mark-routing chain=prerouting comment=\
    "RULE-11: Route LAN client traffic to WAN1 table" connection-mark=cm_wan1 \
    in-interface=bridge new-routing-mark=to_wan1 passthrough=no
add action=mark-routing chain=prerouting comment=\
    "RULE-12: Route LAN client traffic to WAN2 table" connection-mark=cm_wan2 \
    disabled=yes in-interface=bridge new-routing-mark=to_wan2 passthrough=no
/ip firewall nat
add action=masquerade chain=srcnat comment="Masquerade WAN2" out-interface=\
    WAN2
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
add action=masquerade chain=srcnat out-interface=WAN1
add action=masquerade chain=srcnat out-interface=WAN2
/ip hotspot ip-binding
add comment="My Phone Bypass" mac-address=9C:73:B1:6F:8C:7B type=bypassed
add comment="4G Router" mac-address=54:52:84:D0:CE:6B type=bypassed
/ip hotspot user
add name=admin
add limit-bytes-in=150323855360 limit-bytes-out=150323855360 \
    limit-bytes-total=150323855360 name=b311 profile="8  M"
add name=user1
add name=user2
add comment="S23 ultra" mac-address=9C:73:B1:6F:8C:7B name=9C:73:B1:6F:8C:7B
add comment="Iphone 13" mac-address=AA:0C:79:93:E2:9A name=AA:0C:79:93:E2:9A
add comment="Home Router" mac-address=80:2D:1A:64:24:22 name=\
    80:2D:1A:64:24:22
/ip hotspot walled-garden
add comment="place hotspot rules here" disabled=yes
add dst-host=*connectivitycheck* path=""
add dst-host=*gstatic.com*
add dst-host=*apple.com*
add dst-host=*msftconnecttest.com*
/ip hotspot walled-garden ip
add action=accept comment="Bypass Hotspot DNS UDP" disabled=no dst-port=53 \
    protocol=udp
add action=accept comment="Bypass Hotspot DNS TCP" disabled=no dst-port=53 \
    protocol=tcp
/ip route
add check-gateway=ping comment="WAN1 Vodafone" distance=1 dst-address=\
    0.0.0.0/0 gateway=192.168.1.1
add check-gateway=ping comment="WAN2 WE" distance=1 dst-address=0.0.0.0/0 \
    gateway=192.168.2.1
add check-gateway=ping comment="to_WAN1 table" dst-address=0.0.0.0/0 gateway=\
    192.168.1.1 routing-table=*404
add check-gateway=ping comment="to_WAN2 table" dst-address=0.0.0.0/0 gateway=\
    192.168.2.1 routing-table=*405
add comment=WCCP-PBR-WAN1 distance=1 dst-address=0.0.0.0/0 gateway=\
    192.168.1.1%WAN1 routing-table=to_WAN1
add comment=WCCP-PBR-WAN2 distance=1 dst-address=0.0.0.0/0 gateway=\
    192.168.2.1%WAN2 routing-table=to_WAN2
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh address=192.168.88.0/24,192.168.195.0/24
set api disabled=yes
set winbox address=192.168.88.0/24,192.168.195.0/24
set api-ssl disabled=yes
/ipv6 firewall address-list
add address=::/128 comment="defconf: unspecified address" list=bad_ipv6
add address=::1/128 comment="defconf: lo" list=bad_ipv6
add address=fec0::/10 comment="defconf: site-local" list=bad_ipv6
add address=::ffff:0.0.0.0/96 comment="defconf: ipv4-mapped" list=bad_ipv6
add address=::/96 comment="defconf: ipv4 compat" list=bad_ipv6
add address=100::/64 comment="defconf: discard only " list=bad_ipv6
add address=2001:db8::/32 comment="defconf: documentation" list=bad_ipv6
add address=2001:10::/28 comment="defconf: ORCHID" list=bad_ipv6
add address=3ffe::/16 comment="defconf: 6bone" list=bad_ipv6
/ipv6 firewall filter
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid
add action=accept chain=input comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=input comment="defconf: accept UDP traceroute" \
    dst-port=33434-33534 protocol=udp
add action=accept chain=input comment=\
    "defconf: accept DHCPv6-Client prefix delegation." dst-port=546 protocol=\
    udp src-address=fe80::/10
add action=accept chain=input comment="defconf: accept IKE" dst-port=500,4500 \
    protocol=udp
add action=accept chain=input comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=input comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=input comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=input comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN
add action=accept chain=forward comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" \
    connection-state=invalid
add action=drop chain=forward comment=\
    "defconf: drop packets with bad src ipv6" src-address-list=bad_ipv6
add action=drop chain=forward comment=\
    "defconf: drop packets with bad dst ipv6" dst-address-list=bad_ipv6
add action=drop chain=forward comment="defconf: rfc4890 drop hop-limit=1" \
    hop-limit=equal:1 protocol=icmpv6
add action=accept chain=forward comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=forward comment="defconf: accept HIP" protocol=139
add action=accept chain=forward comment="defconf: accept IKE" dst-port=\
    500,4500 protocol=udp
add action=accept chain=forward comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=forward comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=forward comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=forward comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid
add action=accept chain=input comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=input comment="defconf: accept UDP traceroute" \
    dst-port=33434-33534 protocol=udp
add action=accept chain=input comment=\
    "defconf: accept DHCPv6-Client prefix delegation." dst-port=546 protocol=\
    udp src-address=fe80::/10
add action=accept chain=input comment="defconf: accept IKE" dst-port=500,4500 \
    protocol=udp
add action=accept chain=input comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=input comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=input comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=input comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN
add action=accept chain=forward comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" \
    connection-state=invalid
add action=drop chain=forward comment=\
    "defconf: drop packets with bad src ipv6" src-address-list=bad_ipv6
add action=drop chain=forward comment=\
    "defconf: drop packets with bad dst ipv6" dst-address-list=bad_ipv6
add action=drop chain=forward comment="defconf: rfc4890 drop hop-limit=1" \
    hop-limit=equal:1 protocol=icmpv6
add action=accept chain=forward comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=forward comment="defconf: accept HIP" protocol=139
add action=accept chain=forward comment="defconf: accept IKE" dst-port=\
    500,4500 protocol=udp
add action=accept chain=forward comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=forward comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=forward comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=forward comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid
add action=accept chain=input comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=input comment="defconf: accept UDP traceroute" \
    dst-port=33434-33534 protocol=udp
add action=accept chain=input comment=\
    "defconf: accept DHCPv6-Client prefix delegation." dst-port=546 protocol=\
    udp src-address=fe80::/10
add action=accept chain=input comment="defconf: accept IKE" dst-port=500,4500 \
    protocol=udp
add action=accept chain=input comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=input comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
/ipv6 nd
set [ find default=yes ] advertise-dns=no disabled=yes
/system clock
set time-zone-name=Africa/Cairo
/system note
set show-at-login=no
/system ntp client
set enabled=yes
/system ntp client servers
add address=194.164.251.100
add address=time.google.com
add address=pool.ntp.org
/system scheduler
add disabled=yes interval=1d name=reset-b311-quota on-event=":if ([:pick [/sys\
    tem clock get date] 8 10] = \"23\") do={ /ip hotspot user set [find name=b\
    311] limit-bytes-total=150323855360 limit-bytes-in=150323855360 limit-byte\
    s-out=150323855360 }" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=2025-01-23 start-time=00:00:00
add interval=5m name=check-b311-quota on-event=":local in [/ip hotspot user ge\
    t [find name=b311] bytes-in]; :local out [/ip hotspot user get [find name=\
    b311] bytes-out]; :local used (\$in + \$out); :local limit 150323855360; :\
    if (\$used >= \$limit) do={ /ip hotspot user set [find name=b311] profile=\
    LIMIT-HIT } else={ /ip hotspot user set [find name=b311] profile=\"8  M\" \
    }" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=2025-01-23 start-time=00:00:00
add interval=1d name=daily-wan-report on-event=email-wan-report policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=2026-05-16 start-time=08:00:00
add interval=1w name=weekly-auto-backup on-event=weekly-backup policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=2026-05-16 start-time=03:00:00
add interval=5m name=schedule-wan-telemetry on-event=send-wan-telemetry \
    policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup
/system script
add dont-require-permissions=no name=daily-wan-usage owner=admin policy=\
    read,write,test source=":local wan1rx [/interface get WAN1 rx-byte]; :loca\
    l wan1tx [/interface get WAN1 tx-byte]; :local wan2rx [/interface get WAN2\
    \_rx-byte]; :local wan2tx [/interface get WAN2 tx-byte]; :local wan1total \
    (\$wan1rx + \$wan1tx); :local wan2total (\$wan2rx + \$wan2tx); :local tota\
    l (\$wan1total + \$wan2total); :local div 1073741824; :local wan1gb (\$wan\
    1total / \$div); :local wan2gb (\$wan2total / \$div); :local totalgb (\$to\
    tal / \$div); :local wan1pct 0; :local wan2pct 0; :if (\$total > 0) do={ :\
    set wan1pct ((\$wan1total * 100) / \$total); :set wan2pct ((\$wan2total * \
    100) / \$total); }; :log info (\"WAN-USAGE | WAN1=\" . \$wan1gb . \"GB (\"\
    \_. \$wan1pct . \"%) | WAN2=\" . \$wan2gb . \"GB (\" . \$wan2pct . \"%) | \
    TOTAL=\" . \$totalgb . \"GB\")"
add dont-require-permissions=no name=email-wan-report owner=admin policy=\
    read,write,test source=":local wan1rx [/interface get WAN1 rx-byte]; :loca\
    l wan1tx [/interface get WAN1 tx-byte]; :local wan2rx [/interface get WAN2\
    \_rx-byte]; :local wan2tx [/interface get WAN2 tx-byte]; :local wan1total \
    (\$wan1rx + \$wan1tx); :local wan2total (\$wan2rx + \$wan2tx); :local tota\
    l (\$wan1total + \$wan2total); :local div 1073741824; :local wan1gb (\$wan\
    1total / \$div); :local wan2gb (\$wan2total / \$div); :local totalgb (\$to\
    tal / \$div); :local wan1pct 0; :local wan2pct 0; :if (\$total > 0) do={ :\
    set wan1pct ((\$wan1total * 100) / \$total); :set wan2pct ((\$wan2total * \
    100) / \$total); }; :local adminTotal (([/ip hotspot user get admin bytes-\
    in] + [/ip hotspot user get admin bytes-out]) / \$div); :local b311Total (\
    ([/ip hotspot user get b311 bytes-in] + [/ip hotspot user get b311 bytes-o\
    ut]) / \$div); :local uptime [/system resource get uptime]; :local date [/\
    system clock get date]; :local time [/system clock get time]; :local body \
    (\"MikroTik Daily Report\r\
    \n\r\
    \nDate: \" . \$date . \" \" . \$time . \"\r\
    \n\r\
    \nWAN Status:\r\
    \nWAN1 Gateway 192.168.1.1: UP\r\
    \nWAN2 Gateway 192.168.2.1: UP\r\
    \nInternet 1.1.1.1: UP\r\
    \n\r\
    \nWAN Usage:\r\
    \nWAN1 Usage: \" . \$wan1gb . \" GB (\" . \$wan1pct . \"%)\r\
    \nWAN2 Usage: \" . \$wan2gb . \" GB (\" . \$wan2pct . \"%)\r\
    \nTotal WAN Usage: \" . \$totalgb . \" GB\r\
    \n\r\
    \nHotspot Usage:\r\
    \nadmin Total: \" . \$adminTotal . \" GB\r\
    \nb311 Total: \" . \$b311Total . \" GB\r\
    \n\r\
    \nRouter Uptime: \" . \$uptime); /tool e-mail send to=admin@example.com subject=(\"MikroTik Daily Report - \" . \$date) body=\$body"
add dont-require-permissions=no name=telegram-send owner=admin policy=\
    read,write,test source=":local msg \$1; /tool fetch url=(\"https://api.tel\
    egram.org/botNEW_TOKEN/sendMessage\?chat_id=YOUR_TELEGRAM_CHAT_ID&text=\" . \$msg) kee\
    p-result=no"
add dont-require-permissions=no name=weekly-backup owner=admin policy=\
    read,write,test,password,sensitive source=":local d [/system clock get dat\
    e]; :local fname (\"backup-\" . \$d); /system backup save name=\$fname; /e\
    xport hide-sensitive file=\$fname; :log info (\"Weekly backup created: \" \
    . \$fname); /tool fetch url=\"https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/sendMessage\?chat_id=YOUR_TELEGRAM_CHAT_ID&text=Weekly%\
    20Backup%20Created:%20\$fname\" keep-result=no"
add dont-require-permissions=no name=send-wan-telemetry owner=admin policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source=":\
    local wan1Rx [/interface get [find name=\"WAN1\"] rx-byte]\
    \n:local wan1Tx [/interface get [find name=\"WAN1\"] tx-byte]\
    \n\
    \n:local wan2Rx [/interface get [find name=\"WAN2\"] rx-byte]\
    \n:local wan2Tx [/interface get [find name=\"WAN2\"] tx-byte]\
    \n\
    \n:local uptime [/system resource get uptime]\
    \n\
    \n:local payload (\"{\\\"router_id\\\":\\\"home-router-01\\\",\\\"uptime\\\
    \":\\\"\" . \$uptime . \"\\\",\\\"wan1\\\":{\\\"rx\\\":\" . \$wan1Rx . \",\
    \\\"tx\\\":\" . \$wan1Tx . \"},\\\"wan2\\\":{\\\"rx\\\":\" . \$wan2Rx . \"\
    ,\\\"tx\\\":\" . \$wan2Tx . \"}}\")\
    \n\
    \n/tool fetch \\\
    \n    url=\"https://n8n.example.com/webhook/mikrotik/wan-usage\" \\\
    \n    http-method=post \\\
    \n    http-header-field=\"Content-Type: application/json\" \\\
    \n    http-data=\$payload \\\
    \n    output=none"
add comment="Safely isolate WAN2 on quota depletion" \
    dont-require-permissions=no name=isolate_wan2 owner=admin policy=\
    read,write,test source="\
    \n    :log warning \"[WAN-Isolation] Initiating safe client isolation for \
    WAN2...\";\
    \n    /ip firewall mangle set [find comment=\"RULE-10: PCC Balancer 2/1 ->\
    \_WAN2\"] disabled=yes;\
    \n    /ip firewall mangle set [find comment=\"RULE-12: Route LAN client tr\
    affic to WAN2 table\"] disabled=yes;\
    \n    :local flushedCount 0;\
    \n    :foreach c in=[/ip firewall connection find where connection-mark=\"\
    cm_wan2\"] do={\
    \n        /ip firewall connection remove \$c;\
    \n        :set flushedCount (\$flushedCount + 1);\
    \n    }\
    \n    :log info (\"[WAN-Isolation] WAN2 safely isolated. Client traffic st\
    eered to WAN1. Flushed \" . [:tostr \$flushedCount] . \" WAN2 connections.\
    \");\
    \n"
add comment="Restore WAN2 into active load balancing" \
    dont-require-permissions=no name=restore_wan2 owner=admin policy=\
    read,write,test source="```routeros\
    \n:log info \"[WAN-Isolation] Restoring WAN2 into active service...\";\
    \n\
    \n/ip firewall mangle disable [find comment=\"WCCP-WAN2-ISOLATION-OVERRIDE\
    \"];\
    \n\
    \n:log info \"[WAN-Isolation] WAN2 isolation override disabled.\";\
    \n:log info \"[WAN-Isolation] New Hotspot client connections will use norm\
    al PCC 50/50 balancing.\";\
    \n```\
    \n"
add comment="WCCP: Disable WAN2 Isolation Override" dont-require-permissions=\
    no name=RESTORE_WAN2 owner=admin policy=read,write,test source="\
    \n    :log info \"[WCCP-Controller] Request: RESTORE_WAN2 received...\";\
    \n    :local ruleOverride [/ip firewall mangle find comment=\"WCCP-WAN2-IS\
    OLATION-OVERRIDE\"];\
    \n    :if ([:len \$ruleOverride] != 1) do={\
    \n        :log error \"[WCCP-Controller] ABORT: Target rule missing or amb\
    iguous!\";\
    \n        :error \"ABORT_AMBIGUOUS_RULES\";\
    \n    }\
    \n    :local isAlreadyDisabled [/ip firewall mangle get \$ruleOverride dis\
    abled];\
    \n    :if (\$isAlreadyDisabled) do={\
    \n        :log info \"[WCCP-Controller] NO-OP: Override is already disable\
    d (NORMAL).\";\
    \n        :return \"ALREADY_NORMAL\";\
    \n    }\
    \n    /ip firewall mangle set \$ruleOverride disabled=yes;\
    \n    :log info \"[WCCP-Controller] CONFIRMED: RESTORE_WAN2 successful. No\
    rmal PCC 50/50 restored.\";\
    \n    :return \"RESTORED_OK\";\
    \n"
add comment="WCCP: Enable WAN2 Isolation Override" dont-require-permissions=\
    no name=ISOLATE_WAN2 owner=admin policy=read,write,test source="\
    \n    :log warning \"[WCCP-Controller] Request: ISOLATE_WAN2 received...\"\
    ;\
    \n    :local ruleOverride [/ip firewall mangle find comment=\"WCCP-WAN2-IS\
    OLATION-OVERRIDE\"];\
    \n    :if ([:len \$ruleOverride] != 1) do={\
    \n        :log error \"[WCCP-Controller] ABORT: Target rule missing or amb\
    iguous!\";\
    \n        :error \"ABORT_AMBIGUOUS_RULES\";\
    \n    }\
    \n    :local isAlreadyDisabled [/ip firewall mangle get \$ruleOverride dis\
    abled];\
    \n    :if (!\$isAlreadyDisabled) do={\
    \n        :log info \"[WCCP-Controller] NO-OP: Override is already enabled\
    \_(ISOLATED).\";\
    \n        :return \"ALREADY_ISOLATED\";\
    \n    }\
    \n    /ip firewall mangle set \$ruleOverride disabled=no;\
    \n    :log info \"[WCCP-Controller] CONFIRMED: ISOLATE_WAN2 successful. 10\
    0% client traffic steered to WAN1.\";\
    \n    :return \"ISOLATED_OK\";\
    \n"
add comment="WCCP: Enable WAN1 Isolation Override" dont-require-permissions=\
    no name=ISOLATE_WAN1 owner=admin policy=read,write,test source="\
    \n    :log warning \"[WCCP-Controller] Request: ISOLATE_WAN1 received...\"\
    ;\
    \n    :local ruleOverride [/ip firewall mangle find comment=\"WCCP-WAN1-IS\
    OLATION-OVERRIDE\"];\
    \n    :if ([:len \$ruleOverride] != 1) do={\
    \n        :log error \"[WCCP-Controller] ABORT: Target rule missing or amb\
    iguous!\";\
    \n        :error \"ABORT_AMBIGUOUS_RULES\";\
    \n    }\
    \n    :local isAlreadyDisabled [/ip firewall mangle get \$ruleOverride dis\
    abled];\
    \n    :if (!\$isAlreadyDisabled) do={\
    \n        :log info \"[WCCP-Controller] NO-OP: Override is already enabled\
    \_(ISOLATED).\";\
    \n        :return \"ALREADY_ISOLATED\";\
    \n    }\
    \n    /ip firewall mangle set \$ruleOverride disabled=no;\
    \n    :log info \"[WCCP-Controller] CONFIRMED: ISOLATE_WAN1 successful. 10\
    0% client traffic steered to WAN2.\";\
    \n    :return \"ISOLATED_OK\";\
    \n"
add comment="WCCP: Disable WAN1 Isolation Override" dont-require-permissions=\
    no name=RESTORE_WAN1 owner=admin policy=read,write,test source="\
    \n    :log info \"[WCCP-Controller] Request: RESTORE_WAN1 received...\";\
    \n    :local ruleOverride [/ip firewall mangle find comment=\"WCCP-WAN1-IS\
    OLATION-OVERRIDE\"];\
    \n    :if ([:len \$ruleOverride] != 1) do={\
    \n        :log error \"[WCCP-Controller] ABORT: Target rule missing or amb\
    iguous!\";\
    \n        :error \"ABORT_AMBIGUOUS_RULES\";\
    \n    }\
    \n    :local isAlreadyDisabled [/ip firewall mangle get \$ruleOverride dis\
    abled];\
    \n    :if (\$isAlreadyDisabled) do={\
    \n        :log info \"[WCCP-Controller] NO-OP: Override is already disable\
    d (NORMAL).\";\
    \n        :return \"ALREADY_NORMAL\";\
    \n    }\
    \n    /ip firewall mangle set \$ruleOverride disabled=yes;\
    \n    :log info \"[WCCP-Controller] CONFIRMED: RESTORE_WAN1 successful. No\
    rmal PCC 50/50 restored.\";\
    \n    :return \"RESTORED_OK\";\
    \n"
/tool e-mail
set from=admin@example.com port=587 server=smtp.gmail.com tls=starttls \
    user=admin@example.com
/tool netwatch
add comment="WAN1 Monitor" down-script=":log error \"WAN1 DOWN\"; /tool e-mail\
    \_send to=admin@example.com subject=\"WAN1 DOWN\" body=\"WAN1 Gateway\
    \_192.168.1.1 is DOWN on \$[/system clock get date] \$[/system clock get t\
    ime]\"; /tool fetch url=\"https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/sendMessage\?chat_id=YOUR_TELEGRAM_CHAT_ID&text=WAN1%20DOWN\
    \" keep-result=no" host=192.168.1.1 interval=30s timeout=3s type=simple \
    up-script=":log info \"WAN1 UP\"; /tool e-mail send to=admin@example.com subject=\"WAN1 UP\" body=\"WAN1 Gateway 192.168.1.1 is UP on \$[/syste\
    m clock get date] \$[/system clock get time]\"; /tool fetch url=\"https://\
    api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/sendMes\
    sage\?chat_id=YOUR_TELEGRAM_CHAT_ID&text=WAN1%20UP\" keep-result=no"
add comment="WAN2 Monitor" down-script=":log error \"WAN2 DOWN\"; /tool e-mail\
    \_send to=admin@example.com subject=\"WAN2 DOWN\" body=\"WAN2 Gateway\
    \_192.168.2.1 is DOWN on \$[/system clock get date] \$[/system clock get t\
    ime]\"; /tool fetch url=\"https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/sendMessage\?chat_id=YOUR_TELEGRAM_CHAT_ID&text=WAN2%20DOWN\
    \" keep-result=no" host=192.168.2.1 interval=30s timeout=3s type=simple \
    up-script=":log info \"WAN2 UP\"; /tool e-mail send to=admin@example.com subject=\"WAN2 UP\" body=\"WAN2 Gateway 192.168.2.1 is UP on \$[/syste\
    m clock get date] \$[/system clock get time]\"; /tool fetch url=\"https://\
    api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/sendMes\
    sage\?chat_id=YOUR_TELEGRAM_CHAT_ID&text=WAN2%20UP\" keep-result=no"
add comment="Internet Monitor" down-script=":log error \"INTERNET DOWN\"; /too\
    l e-mail send to=admin@example.com subject=\"INTERNET DOWN\" body=\"I\
    nternet connectivity to 1.1.1.1 is DOWN on \$[/system clock get date] \$[/\
    system clock get time]\"; /tool fetch url=\"https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/sendMessage\?chat_id=YOUR_TELEGRAM_CHAT_ID&text=INTERNET%20DOWN%20%281.1.1.1%29\" keep-result=no" host=1.1.1.1 \
    interval=2m timeout=10s type=simple up-script=":log info \"INTERNET UP\"; \
    /tool e-mail send to=admin@example.com subject=\"INTERNET UP\" body=\
    \"Internet connectivity to 1.1.1.1 is UP on \$[/system clock get date] \$[\
    /system clock get time]\"; /tool fetch url=\"https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/sendMessage\?chat_id=YOUR_TELEGRAM_CHAT_ID&text=INTERNET%20UP%20%281.1.1.1%29\" keep-result=no"
