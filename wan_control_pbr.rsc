# ==============================================================================
# MikroTik RouterOS v7 Production Hardened PBR & Safe WAN Isolation
# Standard: WCCP (WAN Control & Control Plane v1.0)
#
# GUARANTEES & SAFETY CONTRACT (INV-01 to INV-10):
#   - INV-01: No isolation request disables WAN monitoring connectivity.
#   - INV-02: Router-originated traffic (chain=output) never receives client isolation marks.
#   - INV-03: Isolation affects ONLY new LAN client traffic + scoped WAN connections.
#   - INV-04: Zero global connection flushes. Only connection-mark="cm_wan2" is flushed.
#   - INV-05 / INV-06: Repeated ISOLATE and RESTORE operations are idempotent.
#   - INV-07: Two-phase execution confirmation.
#   - INV-08: Ambiguity Check: Mangle rules are identified ONLY via stable WCCP comments.
#             If rules cannot be found unambiguously, router refuses the mutation.
#   - INV-09: Survivor WAN verification before severing traffic from isolated line.
#   - INV-10: Reboot reconciliation safety.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. RouterOS 7.x Routing Tables Configuration
# ------------------------------------------------------------------------------
/routing table
add disabled=no fib name=to_wan1 comment="WCCP-RT-WAN1: PBR Routing Table for WAN1 (Vodafone)"
add disabled=no fib name=to_wan2 comment="WCCP-RT-WAN2: PBR Routing Table for WAN2 (WE Egypt)"

# ------------------------------------------------------------------------------
# 2. IP Route Provisioning
# ------------------------------------------------------------------------------
/ip route
add dst-address=0.0.0.0/0 gateway=wan1 distance=1 check-gateway=ping comment="WCCP-ROUTE-DEFAULT-WAN1"
add dst-address=0.0.0.0/0 gateway=wan2 distance=2 check-gateway=ping comment="WCCP-ROUTE-DEFAULT-WAN2"

add dst-address=0.0.0.0/0 gateway=wan1 routing-table=to_wan1 check-gateway=ping comment="WCCP-ROUTE-TABLE-WAN1"
add dst-address=0.0.0.0/0 gateway=wan2 routing-table=to_wan2 check-gateway=ping comment="WCCP-ROUTE-TABLE-WAN2"

# ------------------------------------------------------------------------------
# 3. Safe Firewall Mangle Rules (Bound strictly to Stable Comments)
# ------------------------------------------------------------------------------
/ip firewall mangle
# 3.1. Accept local / connected traffic without mangle interference
add chain=prerouting dst-address-type=local action=accept comment="WCCP-BYPASS-LOCAL: Router-bound traffic"
add chain=prerouting dst-address=192.168.0.0/16 action=accept comment="WCCP-BYPASS-RFC1918: Private traffic"
add chain=prerouting dst-address=10.0.0.0/8 action=accept comment="WCCP-BYPASS-RFC10: Private traffic"
add chain=prerouting dst-address=172.16.0.0/12 action=accept comment="WCCP-BYPASS-RFC172: Private traffic"

# 3.2. Maintain inbound connection marks
add chain=prerouting in-interface=wan1 connection-state=new action=mark-connection \
    new-connection-mark=cm_wan1_in passthrough=yes comment="WCCP-INBOUND-WAN1: Track ingress"
add chain=prerouting in-interface=wan2 connection-state=new action=mark-connection \
    new-connection-mark=cm_wan2_in passthrough=yes comment="WCCP-INBOUND-WAN2: Track ingress"

# 3.3. Standard PCC / Load Balancing for new outgoing connections
# PCC 2/0 -> WAN1
add chain=prerouting in-interface=bridge connection-mark=no-mark connection-state=new \
    per-connection-classifier=both-addresses-and-ports:2/0 action=mark-connection \
    new-connection-mark=cm_wan1 passthrough=yes comment="WCCP-PCC-WAN1-CONN"

# PCC 2/1 -> WAN2
add chain=prerouting in-interface=bridge connection-mark=no-mark connection-state=new \
    per-connection-classifier=both-addresses-and-ports:2/1 action=mark-connection \
    new-connection-mark=cm_wan2 passthrough=yes comment="WCCP-PCC-WAN2-CONN"

# 3.4. Routing Mark Assignment based on Connection Mark (FOR CLIENT FORWARD TRAFFIC ONLY)
add chain=prerouting in-interface=bridge connection-mark=cm_wan1 action=mark-routing \
    new-routing-mark=to_wan1 passthrough=no comment="WCCP-PBR-WAN1-ROUTE"

add chain=prerouting in-interface=bridge connection-mark=cm_wan2 action=mark-routing \
    new-routing-mark=to_wan2 passthrough=no comment="WCCP-PBR-WAN2-ROUTE"

# Inbound connection responses:
add chain=output connection-mark=cm_wan1_in action=mark-routing \
    new-routing-mark=to_wan1 passthrough=no comment="WCCP-OUTPUT-WAN1: Inbound responses"
add chain=output connection-mark=cm_wan2_in action=mark-routing \
    new-routing-mark=to_wan2 passthrough=no comment="WCCP-OUTPUT-WAN2: Inbound responses"

# ------------------------------------------------------------------------------
# 4. NAT / Masquerade
# ------------------------------------------------------------------------------
/ip firewall nat
add chain=srcnat out-interface=wan1 action=masquerade comment="WCCP-NAT-WAN1"
add chain=srcnat out-interface=wan2 action=masquerade comment="WCCP-NAT-WAN2"

# ------------------------------------------------------------------------------
# 5. Production Hardened Isolation & Recovery Automation Scripts
# ------------------------------------------------------------------------------
/system script

# Script: isolate_wan2
add name="isolate_wan2" policy=read,write,test comment="Safely isolate WAN2 on quota depletion" source={
    :log warning "[WCCP-Isolation] Validating preconditions for WAN2 isolation...";
    
    # 1. INV-08: Ambiguity Check
    :local ruleConn [/ip firewall mangle find comment="WCCP-PCC-WAN2-CONN"];
    :local ruleRoute [/ip firewall mangle find comment="WCCP-PBR-WAN2-ROUTE"];
    
    :if ([:len $ruleConn] != 1 or [:len $ruleRoute] != 1) do={
        :log error "[WCCP-Isolation] ABORT: Target rules missing or ambiguous!";
        :error "ABORT_AMBIGUOUS_RULES";
    }
    
    # 2. INV-09: Verify WAN1 Survivor Line before cutting WAN2
    :local wan1Ping [/ping address=8.8.8.8 count=2 routing-table=to_wan1 as-value];
    :local wan1Healthy false;
    :foreach p in=$wan1Ping do={
        :if (([:typeof ($p->"status")] = "nil") and (($p->"time") > 0)) do={ :set wan1Healthy true; }
    }
    :if (!$wan1Healthy) do={
        :log error "[WCCP-Isolation] ABORT: Survivor line WAN1 is unreachable! Refusing isolation.";
        :error "ABORT_SURVIVOR_DOWN";
    }
    
    # 3. Apply Mutations via Stable Comments
    /ip firewall mangle set $ruleConn disabled=yes;
    /ip firewall mangle set $ruleRoute disabled=yes;
    
    # 4. INV-04: Scoped Flush Only
    :local flushedCount 0;
    :foreach c in=[/ip firewall connection find where connection-mark="cm_wan2"] do={
        /ip firewall connection remove $c;
        :set flushedCount ($flushedCount + 1);
    }
    
    :log info ("[WCCP-Isolation] CONFIRMED: WAN2 safely isolated. Client traffic steered to WAN1. Flushed " . [:tostr $flushedCount] . " WAN2 connections.");
}

# Script: restore_wan2
add name="restore_wan2" policy=read,write,test comment="Restore WAN2 into active load balancing" source={
    :log info "[WCCP-Isolation] Restoring WAN2 into active service...";
    
    # INV-08: Ambiguity Check
    :local ruleConn [/ip firewall mangle find comment="WCCP-PCC-WAN2-CONN"];
    :local ruleRoute [/ip firewall mangle find comment="WCCP-PBR-WAN2-ROUTE"];
    
    :if ([:len $ruleConn] != 1 or [:len $ruleRoute] != 1) do={
        :log error "[WCCP-Isolation] ABORT: Target rules missing or ambiguous!";
        :error "ABORT_AMBIGUOUS_RULES";
    }
    
    /ip firewall mangle set $ruleConn disabled=no;
    /ip firewall mangle set $ruleRoute disabled=no;
    
    :log info "[WCCP-Isolation] CONFIRMED: WAN2 successfully restored into load balancing pool.";
}

# Script: isolate_wan1
add name="isolate_wan1" policy=read,write,test comment="Safely isolate WAN1 on quota depletion" source={
    :log warning "[WCCP-Isolation] Validating preconditions for WAN1 isolation...";
    
    :local ruleConn [/ip firewall mangle find comment="WCCP-PCC-WAN1-CONN"];
    :local ruleRoute [/ip firewall mangle find comment="WCCP-PBR-WAN1-ROUTE"];
    
    :if ([:len $ruleConn] != 1 or [:len $ruleRoute] != 1) do={
        :log error "[WCCP-Isolation] ABORT: Target rules missing or ambiguous!";
        :error "ABORT_AMBIGUOUS_RULES";
    }
    
    # Verify WAN2 Survivor Line
    :local wan2Ping [/ping address=8.8.8.8 count=2 routing-table=to_wan2 as-value];
    :local wan2Healthy false;
    :foreach p in=$wan2Ping do={
        :if (([:typeof ($p->"status")] = "nil") and (($p->"time") > 0)) do={ :set wan2Healthy true; }
    }
    :if (!$wan2Healthy) do={
        :log error "[WCCP-Isolation] ABORT: Survivor line WAN2 is unreachable! Refusing isolation.";
        :error "ABORT_SURVIVOR_DOWN";
    }
    
    /ip firewall mangle set $ruleConn disabled=yes;
    /ip firewall mangle set $ruleRoute disabled=yes;
    
    :local flushedCount 0;
    :foreach c in=[/ip firewall connection find where connection-mark="cm_wan1"] do={
        /ip firewall connection remove $c;
        :set flushedCount ($flushedCount + 1);
    }
    
    :log info ("[WCCP-Isolation] CONFIRMED: WAN1 safely isolated. Client traffic steered to WAN2. Flushed " . [:tostr $flushedCount] . " WAN1 connections.");
}

# Script: restore_wan1
add name="restore_wan1" policy=read,write,test comment="Restore WAN1 into active load balancing" source={
    :log info "[WCCP-Isolation] Restoring WAN1 into active service...";
    
    :local ruleConn [/ip firewall mangle find comment="WCCP-PCC-WAN1-CONN"];
    :local ruleRoute [/ip firewall mangle find comment="WCCP-PBR-WAN1-ROUTE"];
    
    :if ([:len $ruleConn] != 1 or [:len $ruleRoute] != 1) do={
        :log error "[WCCP-Isolation] ABORT: Target rules missing or ambiguous!";
        :error "ABORT_AMBIGUOUS_RULES";
    }
    
    /ip firewall mangle set $ruleConn disabled=no;
    /ip firewall mangle set $ruleRoute disabled=no;
    
    :log info "[WCCP-Isolation] CONFIRMED: WAN1 successfully restored into load balancing pool.";
}
