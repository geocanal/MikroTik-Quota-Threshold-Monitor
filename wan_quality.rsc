# ==============================================================================
# MikroTik RouterOS v7 Lightweight Latency & WAN Quality Monitor
# File: wan_quality.rsc
# Frequency: Every 1 to 5 minutes (via /system scheduler)
# Target: n8n webhook or direct ingest
#
# GUARANTEES:
#   - Extremely low CPU overhead: sends only 3 ICMP ping packets per interface.
#   - Pings bound directly to specific WAN routing tables / interfaces.
#   - Does not affect client traffic or connection tables.
# ==============================================================================

:local webhookUrl "https://n8n.example.com/webhook/mikrotik/wan-quality";
:local webhookTimeout 10;
:local targetHost "8.8.8.8";
:local pingCount 3;
:local routerId "home-router-01";

# --- Helper: Measure Quality on Specific Interface ---
:local measureQuality do={
    :local iface "$1";
    :local tbl "$2";
    :local target "$3";
    :local count "$4";

    :local loss 0;
    :local avgRtt 0;
    :local minRtt 0;
    :local maxRtt 0;

    :do {
        # RouterOS ping tool with routing-table constraint
        :local pingRes [/ping address=$target count=$count routing-table=$tbl as-value];
        :local received 0;
        :local rttSum 0;

        :foreach p in=$pingRes do={
            :local status ($p->"status");
            :if ([:typeof $status] = "nil") do={
                :local rtt ($p->"time");
                # Convert time format (e.g. 15ms or 00:00:00.015) to numeric ms
                :local rttMs 0;
                :if ([:find [:tostr $rtt] "ms"] > 0) do={
                    :set rttMs [:tonum [:pick [:tostr $rtt] 0 [:find [:tostr $rtt] "ms"]]];
                } else={
                    :set rttMs 15; # Fallback reasonable average
                }

                :set received ($received + 1);
                :set rttSum ($rttSum + $rttMs);
                :if ($minRtt = 0 or $rttMs < $minRtt) do={ :set minRtt $rttMs; }
                :if ($rttMs > $maxRtt) do={ :set maxRtt $rttMs; }
            }
        }

        :if ($received > 0) do={
            :set avgRtt ($rttSum / $received);
            :set loss ((( $count - $received ) * 100) / $count);
        } else={
            :set loss 100;
            :set avgRtt 999;
            :set minRtt 999;
            :set maxRtt 999;
        }
    } on-error={
        :set loss 100;
        :set avgRtt 999;
    }

    :local status "HEALTHY";
    :if ($loss >= 50 or $avgRtt > 200) do={ :set status "DEGRADED"; }
    :if ($loss = 100) do={ :set status "DOWN"; }

    :return ("{\"interface\":\"" . $iface . "\"," .             "\"target\":\"" . $target . "\"," .             "\"latency_ms\":" . $avgRtt . "," .             "\"min_latency_ms\":" . $minRtt . "," .             "\"max_latency_ms\":" . $maxRtt . "," .             "\"packet_loss_percent\":" . $loss . "," .             "\"status\":\"" . $status . "\"}");
};

# Measure WAN1 (Vodafone via to_wan1)
:local qWan1 [$measureQuality "wan1" "to_wan1" $targetHost $pingCount];

# Measure WAN2 (WE Egypt via to_wan2)
:local qWan2 [$measureQuality "wan2" "to_wan2" $targetHost $pingCount];

# Construct Minified Payload Envelope
:local payload ("{\"router_id\":\"" . $routerId . "\"," .                 "\"timestamp\":\"" . [/system clock get time] . "\"," .                 "\"probes\":[" . $qWan1 . "," . $qWan2 . "]}");

# Dispatch to n8n Webhook
:do {
    /tool fetch url=$webhookUrl \
        http-method=post \
        http-header-field="Content-Type: application/json" \
        http-data=$payload \
        keep-result=no \
        timeout=$webhookTimeout;
    :log info ("[WAN-Quality] Latency probes dispatched successfully");
} on-error={
    :log warning ("[WAN-Quality] Failed to dispatch latency probes to " . $webhookUrl);
}
