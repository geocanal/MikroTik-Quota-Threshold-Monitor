# ==============================================================================
# MikroTik RouterOS v7 Production Hardened WCCP Isolation & Recovery Controller
# File: wccp_control.rsc
# Standard: WCCP (WAN Control & Control Plane v1.1 - Validated Override Architecture)
#
# GUARANTEES & SAFETY CONTRACT (INV-01 to INV-10):
#   - INV-01: No isolation request disables WAN interface or router monitoring.
#   - INV-02: Router-originated traffic (chain=output) never receives client isolation marks.
#   - INV-03: Isolation affects ONLY new LAN client traffic via WCCP-WAN2-ISOLATION-OVERRIDE.
#   - INV-04: Existing TCP connections are NOT forcibly flushed by default.
#             They drain naturally while new connections steer 100% to WAN1.
#   - INV-05 / INV-06: Repeated ISOLATE and RESTORE operations are strictly idempotent.
#   - INV-07: Verified state confirmation: Checks rule disabled status before reporting OK.
#   - INV-08: Ambiguity Check: Finds rule strictly via "WCCP-WAN2-ISOLATION-OVERRIDE".
#             If rule is missing or ambiguous, router refuses mutation.
#   - INV-09: Survivor WAN verification before enabling isolation override.
#   - INV-10: Preserves legacy RULE-10 / RULE-12 untouched.
# ==============================================================================

/system script

# ------------------------------------------------------------------------------
# Script: ISOLATE_WAN2
# Transition: NORMAL -> ISOLATED
# Action: Enable WCCP-WAN2-ISOLATION-OVERRIDE
# ------------------------------------------------------------------------------
add name="ISOLATE_WAN2" policy=read,write,test comment="WCCP: Enable WAN2 Isolation Override" source={
    :log warning "[WCCP-Controller] Request: ISOLATE_WAN2 received. Validating preconditions...";
    
    # 1. INV-08: Ambiguity Check on Control Rule
    :local ruleOverride [/ip firewall mangle find comment="WCCP-WAN2-ISOLATION-OVERRIDE"];
    
    :if ([:len $ruleOverride] != 1) do={
        :log error "[WCCP-Controller] ABORT: Target rule 'WCCP-WAN2-ISOLATION-OVERRIDE' is missing or duplicated! Found: $[:len $ruleOverride]";
        :error "ABORT_AMBIGUOUS_RULES";
    }
    
    # 2. INV-05: Idempotency Check (Check if already enabled / isolated)
    :local isAlreadyDisabled [/ip firewall mangle get $ruleOverride disabled];
    :if (!$isAlreadyDisabled) do={
        :log info "[WCCP-Controller] NO-OP: 'WCCP-WAN2-ISOLATION-OVERRIDE' is already enabled (ISOLATED). Zero mutation applied.";
        :return "ALREADY_ISOLATED";
    }
    
    # 3. INV-09: Verify WAN1 Survivor Line before severing client traffic from WAN2
    :local wan1Ping [/ping address=8.8.8.8 count=2 routing-table=to_WAN1 as-value];
    :local wan1Healthy false;
    :foreach p in=$wan1Ping do={
        :if (([:typeof ($p->"status")] = "nil") and (($p->"time") > 0)) do={ :set wan1Healthy true; }
    }
    :if (!$wan1Healthy) do={
        :log error "[WCCP-Controller] ABORT: Survivor line WAN1 is unreachable via to_WAN1! Refusing isolation.";
        :error "ABORT_SURVIVOR_DOWN";
    }
    
    # 4. Mutation: Enable WCCP-WAN2-ISOLATION-OVERRIDE
    /ip firewall mangle set $ruleOverride disabled=no;
    
    # 5. INV-07: Post-Mutation State Verification
    :local confirmedState [/ip firewall mangle get $ruleOverride disabled];
    :if ($confirmedState) do={
        :log error "[WCCP-Controller] FAILURE: Attempted to enable override but rule remains disabled!";
        :error "MUTATION_VERIFICATION_FAILED";
    }
    
    # 6. Contract Compliance: Do NOT flush global connections.
    # Existing TCP connections drain naturally, while 100% of new connections steer to cm_wan1.
    :log info "[WCCP-Controller] CONFIRMED: ISOLATE_WAN2 successful. WCCP-WAN2-ISOLATION-OVERRIDE is enabled. New client traffic steered to WAN1.";
    :return "ISOLATED_OK";
}

# ------------------------------------------------------------------------------
# Script: RESTORE_WAN2
# Transition: ISOLATED -> NORMAL
# Action: Disable WCCP-WAN2-ISOLATION-OVERRIDE
# ------------------------------------------------------------------------------
add name="RESTORE_WAN2" policy=read,write,test comment="WCCP: Disable WAN2 Isolation Override" source={
    :log info "[WCCP-Controller] Request: RESTORE_WAN2 received. Validating preconditions...";
    
    # 1. INV-08: Ambiguity Check on Control Rule
    :local ruleOverride [/ip firewall mangle find comment="WCCP-WAN2-ISOLATION-OVERRIDE"];
    
    :if ([:len $ruleOverride] != 1) do={
        :log error "[WCCP-Controller] ABORT: Target rule 'WCCP-WAN2-ISOLATION-OVERRIDE' is missing or duplicated! Found: $[:len $ruleOverride]";
        :error "ABORT_AMBIGUOUS_RULES";
    }
    
    # 2. INV-06: Idempotency Check (Check if already disabled / normal)
    :local isAlreadyDisabled [/ip firewall mangle get $ruleOverride disabled];
    :if ($isAlreadyDisabled) do={
        :log info "[WCCP-Controller] NO-OP: 'WCCP-WAN2-ISOLATION-OVERRIDE' is already disabled (NORMAL). Zero mutation applied.";
        :return "ALREADY_NORMAL";
    }
    
    # 3. Mutation: Disable WCCP-WAN2-ISOLATION-OVERRIDE
    /ip firewall mangle set $ruleOverride disabled=yes;
    
    # 4. INV-07: Post-Mutation State Verification
    :local confirmedState [/ip firewall mangle get $ruleOverride disabled];
    :if (!$confirmedState) do={
        :log error "[WCCP-Controller] FAILURE: Attempted to disable override but rule remains enabled!";
        :error "MUTATION_VERIFICATION_FAILED";
    }
    
    :log info "[WCCP-Controller] CONFIRMED: RESTORE_WAN2 successful. WCCP-WAN2-ISOLATION-OVERRIDE is disabled. Normal PCC 50/50 restored.";
    :return "RESTORED_OK";
}
