# ==============================================================================
# MikroTik RouterOS v6 / v7 Hardened Hotspot Telemetry Collector
# File: hotspot_telemetry.rsc
# Frequency: Every 5 minutes (via /system scheduler)
# Architecture:
#   - Chunked Batch Streaming (avoids RouterOS string buffer overflow / memory crashes)
#   - Active-Only Mode Toggle (reduces payload by 90% in large voucher environments)
#   - Special character sanitization & minified JSON output
# ==============================================================================

# --- Configuration Parameters ---
# Set your n8n host IP and port here
:local webhookUrl "http://192.168.88.10:5678/webhook/mikrotik/hotspot-telemetry";
:local webhookTimeout 15;

# Batch size: Number of users per HTTP POST request (Keeps payload under ~4KB safe limit)
:local batchSize 30;

# Filter Mode:
#   true  = Collect ONLY currently connected/active users and their sessions (Recommended for large DBs)
#   false = Collect all registered users regardless of active state
:local activeOnly true;

# --- System Metadata ---
:local routerId [/system identity get name];
:local sysUptime [/system resource get uptime];

# --- Helper: Safe String Sanitizer ---
:local escapeStr do={
    :local str "$1";
    :if ([:typeof $str] = "nil") do={ :return ""; }
    :local clean "";
    :for i from=0 to=([:len $str] - 1) do={
        :local ch [:pick $str $i ($i + 1)];
        :if ($ch = "\\") do={
            :set clean ($clean . "\\\\");
        } else={
            :if ($ch = "\"") do={
                :set clean ($clean . "\\\"");
            } else={
                :if ($ch = "\n") do={
                    :set clean ($clean . "\\n");
                } else={
                    :if ($ch = "\r") do={
                    } else={
                        :set clean ($clean . $ch);
                    }
                }
            }
        }
    }
    :return $clean;
};

# --- 1. Gather Active Sessions Map ---
# Pre-index active sessions for fast matching
:local activeUserList [:toarray ""];
:local activeSessionData [:toarray ""];

:foreach a in=[/ip hotspot active find] do={
    :local aUser [/ip hotspot active get $a user];
    :local aAddress [/ip hotspot active get $a address];
    :local aMac [/ip hotspot active get $a mac-address];
    :local aUptime [/ip hotspot active get $a uptime];
    :if ([:typeof $aUptime] = "nil") do={ :set aUptime "0s"; }
    :local aBytesIn [/ip hotspot active get $a bytes-in];
    :if ([:typeof $aBytesIn] = "nil") do={ :set aBytesIn 0; }
    :local aBytesOut [/ip hotspot active get $a bytes-out];
    :if ([:typeof $aBytesOut] = "nil") do={ :set aBytesOut 0; }

    :set activeUserList ($activeUserList, $aUser);
    
    :local sessJson ("{\"user\":\"" . [$escapeStr $aUser] . "\"," .         "\"ip\":\"" . [:tostr $aAddress] . "\"," .         "\"mac\":\"" . [:tostr $aMac] . "\"," .         "\"uptime\":\"" . $aUptime . "\"," .         "\"rx\":" . $aBytesIn . "," .         "\"tx\":" . $aBytesOut . "}");
    :set activeSessionData ($activeSessionData, $sessJson);
}

# --- 2. Build Filtered User Array ---
:local targetUsers [:toarray ""];

:if ($activeOnly) do={
    # Only iterate unique users who have active connections
    :foreach actUser in=$activeUserList do={
        :local uFind [/ip hotspot user find where name=$actUser];
        :if ([:len $uFind] > 0) do={
            :local uId [:pick $uFind 0];
            # Prevent duplicate user records if multi-session
            :local alreadyAdded false;
            :foreach tu in=$targetUsers do={
                :if ($tu = $uId) do={ :set alreadyAdded true; }
            }
            :if (!$alreadyAdded) do={
                :set targetUsers ($targetUsers, $uId);
            }
        }
    }
} else={
    :set targetUsers [/ip hotspot user find];
}

:local totalUsers [:len $targetUsers];
:if ($totalUsers = 0) do={
    :log info ("[Hotspot-Telemetry] No users to dispatch (ActiveOnly=" . [:tostr $activeOnly] . ")");
    :return false;
}

# --- 3. Stream Users in Safe Batches ---
:local totalBatches (($totalUsers / $batchSize) + 1);
:local currentUserIdx 0;
:local batchNum 1;

:while ($currentUserIdx < $totalUsers) do={
    :local chunkEnd ($currentUserIdx + $batchSize);
    :if ($chunkEnd > $totalUsers) do={ :set chunkEnd $totalUsers; }
    
    :local usersJson "";
    :local isFirstInBatch true;
    :local matchedSessionsJson "";
    :local isFirstSess true;

    :for i from=$currentUserIdx to=($chunkEnd - 1) do={
        :local u ($targetUsers->$i);
        :local uName [/ip hotspot user get $u name];
        :local uProfile [/ip hotspot user get $u profile];
        
        :local bIn [/ip hotspot user get $u bytes-in];
        :if ([:typeof $bIn] = "nil") do={ :set bIn 0; }
        :local bOut [/ip hotspot user get $u bytes-out];
        :if ([:typeof $bOut] = "nil") do={ :set bOut 0; }
        :local limitTotal [/ip hotspot user get $u limit-bytes-total];
        :if ([:typeof $limitTotal] = "nil") do={ :set limitTotal 0; }
        :local uComment [/ip hotspot user get $u comment];
        :if ([:typeof $uComment] = "nil") do={ :set uComment ""; }

        # Minified User Object
        :local uObj ("{\"name\":\"" . [$escapeStr $uName] . "\"," .             "\"profile\":\"" . [$escapeStr $uProfile] . "\"," .             "\"rx\":" . $bIn . "," .             "\"tx\":" . $bOut . "," .             "\"limit\":" . $limitTotal . "," .             "\"comment\":\"" . [$escapeStr $uComment] . "\"}");

        :if ($isFirstInBatch) do={
            :set usersJson $uObj;
            :set isFirstInBatch false;
        } else={
            :set usersJson ($usersJson . "," . $uObj);
        }

        # Pull corresponding active sessions for this batch
        :for sIdx from=0 to=([:len $activeUserList] - 1) do={
            :if (($activeUserList->$sIdx) = $uName) do={
                :local sObj ($activeSessionData->$sIdx);
                :if ($isFirstSess) do={
                    :set matchedSessionsJson $sObj;
                    :set isFirstSess false;
                } else={
                    :set matchedSessionsJson ($matchedSessionsJson . "," . $sObj);
                }
            }
        }
    }

    # Construct Minified Batch Envelope
    :local batchPayload ("{\"router_id\":\"" . [$escapeStr $routerId] . "\"," .         "\"uptime\":\"" . [:tostr $sysUptime] . "\"," .         "\"batch\":" . $batchNum . "," .         "\"total_batches\":" . $totalBatches . "," .         "\"users\":[" . $usersJson . "]," .         "\"sessions\":[" . $matchedSessionsJson . "]}");

    # Dispatch Chunk via /tool fetch
    :do {
        /tool fetch url=$webhookUrl \
            http-method=post \
            http-header-field="Content-Type: application/json" \
            http-data=$batchPayload \
            keep-result=no \
            timeout=$webhookTimeout;
        :log info ("[Hotspot-Telemetry] Pushed batch " . $batchNum . "/" . $totalBatches . " (" . ($chunkEnd - $currentUserIdx) . " users) successfully");
    } on-error={
        :log warning ("[Hotspot-Telemetry] Failed to dispatch batch " . $batchNum . " to " . $webhookUrl);
    }

    :set currentUserIdx $chunkEnd;
    :set batchNum ($batchNum + 1);
}
