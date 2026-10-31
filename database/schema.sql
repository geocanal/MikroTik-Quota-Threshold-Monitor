-- ==============================================================================
-- MikroTik Quota Threshold Monitor - Database Schema & Disaster Recovery (DDL)
-- Timezone Standard: Africa/Cairo
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Raw Telemetry Readings Table
CREATE TABLE IF NOT EXISTS mikrotik_wan_readings (
    id BIGSERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    uptime VARCHAR(64),
    wan1_rx BIGINT NOT NULL DEFAULT 0,
    wan1_tx BIGINT NOT NULL DEFAULT 0,
    wan2_rx BIGINT NOT NULL DEFAULT 0,
    wan2_tx BIGINT NOT NULL DEFAULT 0,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Calculated Telemetry Byte Usage Table
CREATE TABLE IF NOT EXISTS mikrotik_wan_usage (
    id BIGSERIAL PRIMARY KEY,
    reading_id BIGINT REFERENCES mikrotik_wan_readings(id) ON DELETE CASCADE,
    router_id VARCHAR(64) NOT NULL,
    wan1_rx_bytes BIGINT NOT NULL DEFAULT 0,
    wan1_tx_bytes BIGINT NOT NULL DEFAULT 0,
    wan2_rx_bytes BIGINT NOT NULL DEFAULT 0,
    wan2_tx_bytes BIGINT NOT NULL DEFAULT 0,
    total_bytes BIGINT NOT NULL DEFAULT 0,
    counter_reset BOOLEAN NOT NULL DEFAULT FALSE,
    usage_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. ISP Quota & Billing Cycle Configuration Table
CREATE TABLE IF NOT EXISTS mikrotik_wan_quotas (
    id SERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    interface_name VARCHAR(32) NOT NULL,
    provider_name VARCHAR(64) NOT NULL,
    quota_gb NUMERIC(10, 2) NOT NULL,
    renewal_day INTEGER NOT NULL CHECK (renewal_day BETWEEN 1 AND 31),
    alert_threshold_percent NUMERIC(5, 2) NOT NULL DEFAULT 80.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_router_interface UNIQUE (router_id, interface_name)
);

-- 4. WAN Interface Incident State Tracking Table
CREATE TABLE IF NOT EXISTS wan_incident_state (
    id SERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    interface_name VARCHAR(32) NOT NULL,
    is_down BOOLEAN NOT NULL DEFAULT FALSE,
    consecutive_zero_counts INTEGER NOT NULL DEFAULT 0,
    last_alert_sent_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_wan_incident_router_iface UNIQUE (router_id, interface_name)
);

-- 5. Quota Alert State Table (Per billing cycle deduplication)
CREATE TABLE IF NOT EXISTS quota_alert_state (
    id SERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    interface_name VARCHAR(32) NOT NULL,
    cycle_start DATE NOT NULL,
    alerted_80 BOOLEAN NOT NULL DEFAULT FALSE,
    alerted_95 BOOLEAN NOT NULL DEFAULT FALSE,
    alerted_100 BOOLEAN NOT NULL DEFAULT FALSE,
    last_alert_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_quota_alert_cycle UNIQUE (router_id, interface_name, cycle_start)
);

-- 6. Router Heartbeat / Dead Man's Switch State Tracking Table
CREATE TABLE IF NOT EXISTS router_heartbeat_state (
    id SERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL UNIQUE,
    is_offline BOOLEAN NOT NULL DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ,
    last_alert_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. High Performance Indices
CREATE INDEX IF NOT EXISTS idx_mikrotik_readings_router_received 
    ON mikrotik_wan_readings (router_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_mikrotik_readings_received_at 
    ON mikrotik_wan_readings (received_at DESC);

CREATE INDEX IF NOT EXISTS idx_mikrotik_usage_router_usage_at 
    ON mikrotik_wan_usage (router_id, usage_at DESC);

CREATE INDEX IF NOT EXISTS idx_mikrotik_usage_usage_at 
    ON mikrotik_wan_usage (usage_at DESC);

CREATE INDEX IF NOT EXISTS idx_mikrotik_usage_reading_id 
    ON mikrotik_wan_usage (reading_id);

CREATE INDEX IF NOT EXISTS idx_mikrotik_quotas_active 
    ON mikrotik_wan_quotas (router_id, is_active);

-- ------------------------------------------------------------------------------
-- 7.1. Deterministic Cycle Boundary Function
-- Handles leap years, 28/29/30/31-day months (e.g. renewal_day 31 in Feb -> Feb 28/29, Apr -> Apr 30)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_cycle_boundary_date(target_year int, target_month int, renewal_day int)
RETURNS date AS $$
DECLARE
    first_of_month date;
    last_of_month date;
    last_day_num int;
BEGIN
    first_of_month := make_date(target_year, target_month, 1);
    last_of_month := (first_of_month + INTERVAL '1 month' - INTERVAL '1 day')::date;
    last_day_num := EXTRACT(DAY FROM last_of_month)::int;
    
    IF renewal_day > last_day_num THEN
        RETURN last_of_month;
    ELSE
        RETURN make_date(target_year, target_month, renewal_day);
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ------------------------------------------------------------------------------
-- 7.2. Formal Billing Cycles Table (Auditable & Immutable upon Closure)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS billing_cycles (
    id BIGSERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    interface_name VARCHAR(32) NOT NULL,
    cycle_start DATE NOT NULL,
    cycle_end DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'CLOSED', 'RECONCILED')),
    base_quota_gb NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    CONSTRAINT uq_billing_cycle_router_iface_start UNIQUE (router_id, interface_name, cycle_start),
    CONSTRAINT chk_cycle_end_after_start CHECK (cycle_end > cycle_start)
);

CREATE INDEX IF NOT EXISTS idx_billing_cycles_lookup 
    ON billing_cycles (router_id, interface_name, status);

CREATE INDEX IF NOT EXISTS idx_billing_cycles_dates 
    ON billing_cycles (router_id, interface_name, cycle_start, cycle_end);

-- ------------------------------------------------------------------------------
-- 7.3. Append-Only Quota Allocations Ledger (BASE + ADD-ONs)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS quota_allocations (
    id BIGSERIAL PRIMARY KEY,
    billing_cycle_id BIGINT REFERENCES billing_cycles(id) ON DELETE RESTRICT,
    router_id VARCHAR(64) NOT NULL,
    interface_name VARCHAR(32) NOT NULL,
    type VARCHAR(16) NOT NULL CHECK (type IN ('BASE', 'ADDON')),
    amount_gb NUMERIC(10, 2) NOT NULL CHECK (amount_gb > 0),
    effective_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(64) NOT NULL DEFAULT 'system',
    reference VARCHAR(128),
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_quota_allocations_cycle 
    ON quota_allocations (billing_cycle_id);

CREATE INDEX IF NOT EXISTS idx_quota_allocations_router_iface 
    ON quota_allocations (router_id, interface_name, effective_at);

-- ------------------------------------------------------------------------------
-- 7.3.1. WAN Operational State & State Machine Tracking Table
-- States:
--   - NORMAL: Interface participating normally in PCC / routing pool.
--   - ISOLATED: Client forwarded traffic steered away due to quota exhaustion.
--   - THROTTLED: Provider throttled speed (e.g. 256kbps), traffic restricted.
--   - RECOVERED: Restored to normal operation after renewal/add-on.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wan_operational_state (
    id SERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    interface_name VARCHAR(32) NOT NULL,
    current_state VARCHAR(24) NOT NULL DEFAULT 'NORMAL' 
        CHECK (current_state IN ('NORMAL', 'ISOLATION_REQUESTED', 'ISOLATED', 'ISOLATION_FAILED', 'RESTORATION_REQUESTED', 'THROTTLED', 'RECOVERED')),
    previous_state VARCHAR(24),
    reason TEXT,
    state_changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb,
    CONSTRAINT uq_wan_operational_state UNIQUE (router_id, interface_name)
);

CREATE INDEX IF NOT EXISTS idx_wan_operational_state_lookup 
    ON wan_operational_state (router_id, interface_name, current_state);

-- ------------------------------------------------------------------------------
-- 7.3.2. Idempotent Control Actions Ledger
-- Tracks every control signal dispatched or requested (e.g. from n8n / Telegram / Scheduler)
-- Ensures no duplicate commands are executed and prevents command storms.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wan_control_actions (
    id BIGSERIAL PRIMARY KEY,
    idempotency_key VARCHAR(128) NOT NULL UNIQUE,
    router_id VARCHAR(64) NOT NULL,
    interface_name VARCHAR(32) NOT NULL,
    action_type VARCHAR(32) NOT NULL 
        CHECK (action_type IN ('ISOLATE', 'RESTORE', 'THROTTLE', 'UNTHROTTLE')),
    target_state VARCHAR(24) NOT NULL,
    status VARCHAR(24) NOT NULL DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'EXECUTED', 'SKIPPED', 'FAILED')),
    requested_by VARCHAR(64) NOT NULL DEFAULT 'system',
    reason TEXT,
    execution_result JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    executed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_wan_control_actions_router 
    ON wan_control_actions (router_id, interface_name, status);

CREATE INDEX IF NOT EXISTS idx_wan_control_actions_created 
    ON wan_control_actions (created_at DESC);

-- ------------------------------------------------------------------------------
-- 7.3.3. Deterministic State Transition Function (Idempotent)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION transition_wan_state(
    p_idempotency_key VARCHAR,
    p_router_id VARCHAR,
    p_interface_name VARCHAR,
    p_action_type VARCHAR,
    p_requested_by VARCHAR,
    p_reason TEXT,
    p_force BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
    curr_state VARCHAR(24);
    desired_state VARCHAR(24);
    existing_action RECORD;
    result JSONB;
BEGIN
    -- Determine target state based on action type
    CASE p_action_type
        WHEN 'ISOLATE' THEN desired_state := 'ISOLATED';
        WHEN 'RESTORE' THEN desired_state := 'NORMAL';
        WHEN 'THROTTLE' THEN desired_state := 'THROTTLED';
        WHEN 'UNTHROTTLE' THEN desired_state := 'NORMAL';
        ELSE
            RAISE EXCEPTION 'Invalid action_type: %', p_action_type;
    END CASE;

    -- Check if idempotency_key was already processed
    SELECT * INTO existing_action 
    FROM wan_control_actions 
    WHERE idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', TRUE,
            'idempotency_key', p_idempotency_key,
            'status', existing_action.status,
            'action_id', existing_action.id,
            'message', 'Action already recorded with status: ' || existing_action.status,
            'state_changed', FALSE
        );
    END IF;

    -- Fetch current state or initialize if not present
    SELECT current_state INTO curr_state
    FROM wan_operational_state
    WHERE router_id = p_router_id AND LOWER(interface_name) = LOWER(p_interface_name);

    IF NOT FOUND THEN
        INSERT INTO wan_operational_state (router_id, interface_name, current_state, updated_at)
        VALUES (p_router_id, p_interface_name, 'NORMAL', NOW())
        RETURNING current_state INTO curr_state;
    END IF;

    -- Check if transition is a no-op (already in desired state) and not forced
    IF curr_state = desired_state AND NOT p_force THEN
        INSERT INTO wan_control_actions (
            idempotency_key, router_id, interface_name, action_type, 
            target_state, status, requested_by, reason, executed_at
        ) VALUES (
            p_idempotency_key, p_router_id, p_interface_name, p_action_type, 
            desired_state, 'SKIPPED', p_requested_by, 'Already in state ' || curr_state || ': ' || COALESCE(p_reason, ''), NOW()
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'idempotency_key', p_idempotency_key,
            'status', 'SKIPPED',
            'current_state', curr_state,
            'target_state', desired_state,
            'state_changed', FALSE,
            'message', 'No state transition required; interface is already ' || curr_state
        );
    END IF;

    -- Perform state transition
    UPDATE wan_operational_state
    SET 
        previous_state = current_state,
        current_state = desired_state,
        reason = p_reason,
        state_changed_at = NOW(),
        updated_at = NOW()
    WHERE router_id = p_router_id AND LOWER(interface_name) = LOWER(p_interface_name);

    -- Record executed action in audit ledger
    INSERT INTO wan_control_actions (
        idempotency_key, router_id, interface_name, action_type, 
        target_state, status, requested_by, reason, executed_at
    ) VALUES (
        p_idempotency_key, p_router_id, p_interface_name, p_action_type, 
        desired_state, 'EXECUTED', p_requested_by, p_reason, NOW()
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'idempotency_key', p_idempotency_key,
        'status', 'EXECUTED',
        'previous_state', curr_state,
        'current_state', desired_state,
        'state_changed', TRUE,
        'message', 'State successfully transitioned from ' || curr_state || ' to ' || desired_state
    );
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------
-- 7.3.4. Two-Phase Router Confirmation Function (INV-07)
-- Confirms router execution or marks failure. State only becomes ISOLATED/NORMAL
-- when MikroTik confirms successful application of WCCP-WAN2-ISOLATION-OVERRIDE.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION confirm_router_execution(
    p_idempotency_key VARCHAR,
    p_router_id VARCHAR,
    p_interface_name VARCHAR,
    p_execution_status VARCHAR, -- 'CONFIRMED' | 'FAILED'
    p_receipt JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB AS $$
DECLARE
    action_rec RECORD;
    new_state VARCHAR(24);
BEGIN
    SELECT * INTO action_rec
    FROM wan_control_actions
    WHERE idempotency_key = p_idempotency_key;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Action with idempotency key ' || p_idempotency_key || ' not found.'
        );
    END IF;

    IF p_execution_status = 'CONFIRMED' THEN
        new_state := action_rec.target_state;
        
        UPDATE wan_control_actions
        SET status = 'EXECUTED',
            execution_result = p_receipt,
            executed_at = NOW()
        WHERE id = action_rec.id;

        UPDATE wan_operational_state
        SET current_state = new_state,
            reason = 'Router confirmed execution: ' || COALESCE(p_receipt->>'message', 'OK'),
            updated_at = NOW()
        WHERE router_id = p_router_id AND LOWER(interface_name) = LOWER(p_interface_name);

        RETURN jsonb_build_object(
            'success', TRUE,
            'status', 'CONFIRMED',
            'current_state', new_state,
            'message', 'Router confirmed execution. State is now ' || new_state
        );
    ELSE
        -- Execution failed on router (e.g. ABORT_SURVIVOR_DOWN, ABORT_AMBIGUOUS_RULES)
        new_state := CASE 
            WHEN action_rec.target_state = 'ISOLATED' THEN 'ISOLATION_FAILED'
            ELSE 'NORMAL'
        END;

        UPDATE wan_control_actions
        SET status = 'FAILED',
            execution_result = p_receipt,
            executed_at = NOW()
        WHERE id = action_rec.id;

        UPDATE wan_operational_state
        SET current_state = new_state,
            reason = 'Router execution failed: ' || COALESCE(p_receipt->>'error', 'Unknown error'),
            updated_at = NOW()
        WHERE router_id = p_router_id AND LOWER(interface_name) = LOWER(p_interface_name);

        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 'FAILED',
            'current_state', new_state,
            'error', p_receipt->>'error',
            'message', 'Router failed execution. State is ' || new_state
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 7.4. Configurable Day-of-Week Weights Matrix (Data-Driven, Egyptian Patterns)
-- ISO DOW: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
-- Default weights: Friday/Saturday weighted higher (1.30), weekdays (0.88)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS quota_day_weights (
    day_of_week INTEGER PRIMARY KEY CHECK (day_of_week BETWEEN 1 AND 7),
    day_name VARCHAR(16) NOT NULL,
    weight_multiplier NUMERIC(4, 2) NOT NULL DEFAULT 1.00 CHECK (weight_multiplier > 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 7.5. Adaptive Hierarchical Burn-Rate Analytical Function
-- Combines:
--  1. Cold-start guard (< 3 days elapsed): uses baseline historical daily allocation
--  2. Normal operation (>= 3 days elapsed): WMA(7d) [60%] + Cycle Average [40%]
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_adaptive_burn_rate(
    p_router_id VARCHAR,
    p_interface_name VARCHAR,
    p_cycle_start DATE,
    p_today_date DATE,
    p_total_used_bytes NUMERIC,
    p_base_quota_gb NUMERIC
)
RETURNS NUMERIC(10, 2) AS $$
DECLARE
    elapsed_days INTEGER;
    total_cycle_days INTEGER;
    cycle_daily_rate NUMERIC;
    wma_7d_rate NUMERIC;
    wma_days_count INTEGER;
    effective_rate NUMERIC;
BEGIN
    elapsed_days := GREATEST(1, (p_today_date - p_cycle_start)::INTEGER);
    cycle_daily_rate := (p_total_used_bytes / (1024.0 * 1024.0 * 1024.0)) / elapsed_days;

    -- Query rolling 7-day weighted moving average from daily usage rollups
    SELECT 
        COUNT(*),
        COALESCE(
            SUM(
                CASE LOWER(p_interface_name)
                    WHEN 'wan1' THEN wan1_total_gb
                    WHEN 'wan2' THEN wan2_total_gb
                    ELSE 0
                END * dw.weight_multiplier
            ) / NULLIF(SUM(dw.weight_multiplier), 0),
            0.00
        )
    INTO wma_days_count, wma_7d_rate
    FROM view_mikrotik_wan_daily_usage d
    JOIN quota_day_weights dw ON dw.day_of_week = EXTRACT(ISODOW FROM d.usage_date)::INTEGER
    WHERE d.router_id = p_router_id
      AND d.usage_date >= (p_today_date - INTERVAL '7 days')::DATE
      AND d.usage_date < p_today_date;

    -- Cold-start guard: If under 3 days of cycle telemetry, fallback gracefully
    IF elapsed_days < 3 THEN
        IF wma_days_count >= 3 AND wma_7d_rate > 0 THEN
            effective_rate := wma_7d_rate;
        ELSE
            -- Default conservative baseline: assuming full base quota consumed evenly over 30 days
            effective_rate := GREATEST(cycle_daily_rate, ROUND(p_base_quota_gb / 30.0, 2));
        END IF;
    ELSE
        IF wma_days_count >= 3 AND wma_7d_rate > 0 THEN
            effective_rate := (wma_7d_rate * 0.60) + (cycle_daily_rate * 0.40);
        ELSE
            effective_rate := cycle_daily_rate;
        END IF;
    END IF;

    RETURN ROUND(GREATEST(0.01, effective_rate), 2);
END;
$$ LANGUAGE plpgsql STABLE;

-- ------------------------------------------------------------------------------
-- 8. View: Dynamic Quota Cycle Status Calculation (Effective Quota + Analytics)
-- Time Zone: Africa/Cairo
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW view_mikrotik_wan_quota_status AS
WITH current_cairo_time AS (
    SELECT 
        (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::timestamp AS cairo_now,
        (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::date AS today_date,
        EXTRACT(YEAR FROM (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo'))::int AS current_year,
        EXTRACT(MONTH FROM (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo'))::int AS current_month,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo'))::int AS current_day
),
deterministic_boundaries AS (
    SELECT 
        q.router_id,
        q.interface_name,
        q.provider_name,
        q.quota_gb AS config_base_quota_gb,
        q.renewal_day,
        q.alert_threshold_percent,
        t.today_date,
        t.cairo_now,
        CASE 
            WHEN t.current_day >= q.renewal_day THEN 
                calculate_cycle_boundary_date(t.current_year, t.current_month, q.renewal_day)
            ELSE 
                calculate_cycle_boundary_date(
                    EXTRACT(YEAR FROM (make_date(t.current_year, t.current_month, 1) - INTERVAL '1 month'))::int,
                    EXTRACT(MONTH FROM (make_date(t.current_year, t.current_month, 1) - INTERVAL '1 month'))::int,
                    q.renewal_day
                )
        END AS cycle_start,
        CASE 
            WHEN t.current_day >= q.renewal_day THEN 
                calculate_cycle_boundary_date(
                    EXTRACT(YEAR FROM (make_date(t.current_year, t.current_month, 1) + INTERVAL '1 month'))::int,
                    EXTRACT(MONTH FROM (make_date(t.current_year, t.current_month, 1) + INTERVAL '1 month'))::int,
                    q.renewal_day
                )
            ELSE 
                calculate_cycle_boundary_date(t.current_year, t.current_month, q.renewal_day)
        END AS renewal_date
    FROM mikrotik_wan_quotas q
    CROSS JOIN current_cairo_time t
    WHERE q.is_active = TRUE
),
active_cycles_resolved AS (
    SELECT 
        b.router_id,
        b.interface_name,
        b.provider_name,
        b.config_base_quota_gb,
        b.renewal_day,
        b.alert_threshold_percent,
        b.today_date,
        b.cairo_now,
        b.cycle_start,
        b.renewal_date,
        bc.id AS billing_cycle_id,
        COALESCE(bc.status, 'ACTIVE') AS cycle_status,
        COALESCE(bc.base_quota_gb, b.config_base_quota_gb) AS base_quota_gb
    FROM deterministic_boundaries b
    LEFT JOIN billing_cycles bc 
        ON bc.router_id = b.router_id 
       AND LOWER(bc.interface_name) = LOWER(b.interface_name) 
       AND bc.cycle_start = b.cycle_start
),
addon_allocations_sum AS (
    SELECT 
        ac.router_id,
        ac.interface_name,
        COALESCE(SUM(qa.amount_gb), 0.00) AS addon_quota_gb
    FROM active_cycles_resolved ac
    LEFT JOIN quota_allocations qa 
        ON (
            (qa.billing_cycle_id IS NOT NULL AND qa.billing_cycle_id = ac.billing_cycle_id)
            OR (
                qa.billing_cycle_id IS NULL 
                AND qa.router_id = ac.router_id 
                AND LOWER(qa.interface_name) = LOWER(ac.interface_name)
                AND (qa.effective_at AT TIME ZONE 'Africa/Cairo')::date >= ac.cycle_start
                AND (qa.effective_at AT TIME ZONE 'Africa/Cairo')::date < ac.renewal_date
            )
        )
        AND qa.type = 'ADDON'
        AND qa.effective_at <= ac.cairo_now
        AND (qa.expires_at IS NULL OR qa.expires_at > ac.cairo_now)
    GROUP BY ac.router_id, ac.interface_name
),
usage_per_cycle AS (
    SELECT 
        ac.router_id,
        ac.interface_name,
        ac.provider_name,
        ac.renewal_day,
        ac.alert_threshold_percent,
        ac.cycle_start,
        ac.renewal_date,
        (ac.renewal_date - ac.today_date)::int AS days_left,
        ac.cycle_status,
        ac.base_quota_gb,
        COALESCE(ads.addon_quota_gb, 0.00) AS addon_quota_gb,
        (ac.base_quota_gb + COALESCE(ads.addon_quota_gb, 0.00)) AS total_quota_gb,
        COALESCE(
            SUM(
                CASE 
                    WHEN LOWER(ac.interface_name) = 'wan1' THEN (u.wan1_rx_bytes + u.wan1_tx_bytes)
                    WHEN LOWER(ac.interface_name) = 'wan2' THEN (u.wan2_rx_bytes + u.wan2_tx_bytes)
                    ELSE 0
                END
            ), 0
        ) AS total_used_bytes,
        ac.today_date
    FROM active_cycles_resolved ac
    LEFT JOIN addon_allocations_sum ads
        ON ads.router_id = ac.router_id 
       AND LOWER(ads.interface_name) = LOWER(ac.interface_name)
    LEFT JOIN mikrotik_wan_usage u 
        ON u.router_id = ac.router_id 
       AND (u.usage_at AT TIME ZONE 'Africa/Cairo') >= ac.cycle_start::timestamp
       AND (u.usage_at AT TIME ZONE 'Africa/Cairo') < (ac.renewal_date::timestamp)
       AND u.counter_reset = FALSE
    GROUP BY 
        ac.router_id, ac.interface_name, ac.provider_name, 
        ac.renewal_day, ac.alert_threshold_percent, ac.cycle_start, ac.renewal_date, 
        ac.today_date, ac.cycle_status, ac.base_quota_gb, ads.addon_quota_gb
),
calculated_metrics AS (
    SELECT 
        u.*,
        ROUND((u.total_used_bytes / (1024.0 * 1024.0 * 1024.0))::numeric, 2) AS used_gb_val,
        ROUND(GREATEST(0, u.total_quota_gb - (u.total_used_bytes / (1024.0 * 1024.0 * 1024.0)))::numeric, 2) AS remaining_gb_val,
        calculate_adaptive_burn_rate(
            u.router_id,
            u.interface_name,
            u.cycle_start,
            u.today_date,
            u.total_used_bytes,
            u.base_quota_gb
        ) AS daily_burn_rate_gb_val,
        COALESCE(wos.current_state, 'NORMAL') AS operational_state,
        wos.reason AS operational_state_reason,
        wos.state_changed_at AS operational_state_changed_at
    FROM usage_per_cycle u
    LEFT JOIN wan_operational_state wos 
        ON wos.router_id = u.router_id 
       AND LOWER(wos.interface_name) = LOWER(u.interface_name)
)
SELECT 
    router_id,
    interface_name,
    provider_name,
    -- Backward Compatibility: quota_gb exposes effective total quota (Base + Active Addons)
    total_quota_gb AS quota_gb,
    base_quota_gb,
    addon_quota_gb,
    total_quota_gb,
    renewal_day,
    cycle_start,
    renewal_date,
    cycle_start AS billing_cycle_start,
    renewal_date AS billing_cycle_end,
    cycle_status,
    days_left,
    used_gb_val AS used_gb,
    used_gb_val AS consumed_gb,
    remaining_gb_val AS remaining_gb,
    ROUND(
        LEAST(100.0, (used_gb_val / NULLIF(total_quota_gb, 0)) * 100.0)::numeric, 
        1
    ) AS used_percentage,
    alert_threshold_percent,
    daily_burn_rate_gb_val AS daily_burn_rate_gb,
    -- Projected exhaustion calculation
    CASE 
        WHEN remaining_gb_val <= 0 THEN today_date
        WHEN daily_burn_rate_gb_val > 0 THEN 
            (today_date + (FLOOR(remaining_gb_val / daily_burn_rate_gb_val) || ' days')::INTERVAL)::DATE
        ELSE renewal_date
    END AS projected_exhaustion_date,
    CASE 
        WHEN daily_burn_rate_gb_val > 0 THEN 
            FLOOR(remaining_gb_val / daily_burn_rate_gb_val)::INTEGER
        ELSE days_left
    END AS days_until_exhaustion,
    CASE 
        WHEN remaining_gb_val <= 0 THEN TRUE
        WHEN daily_burn_rate_gb_val > 0 AND (today_date + (FLOOR(remaining_gb_val / daily_burn_rate_gb_val) || ' days')::INTERVAL)::DATE < renewal_date THEN TRUE
        ELSE FALSE
    END AS will_exhaust_before_renewal,
    operational_state,
    operational_state_reason,
    operational_state_changed_at
FROM calculated_metrics;

-- 9. View: Aggregated Daily Rollups Per Interface & Grand Total
-- Time Zone: Africa/Cairo
CREATE OR REPLACE VIEW view_mikrotik_wan_daily_usage AS
SELECT 
    router_id,
    (usage_at AT TIME ZONE 'Africa/Cairo')::date AS usage_date,
    ROUND(SUM(wan1_rx_bytes + wan1_tx_bytes) / (1024.0 * 1024.0), 2) AS wan1_total_mb,
    ROUND(SUM(wan1_rx_bytes + wan1_tx_bytes) / (1024.0 * 1024.0 * 1024.0), 2) AS wan1_total_gb,
    ROUND(SUM(wan2_rx_bytes + wan2_tx_bytes) / (1024.0 * 1024.0), 2) AS wan2_total_mb,
    ROUND(SUM(wan2_rx_bytes + wan2_tx_bytes) / (1024.0 * 1024.0 * 1024.0), 2) AS wan2_total_gb,
    ROUND(SUM(total_bytes) / (1024.0 * 1024.0), 2) AS grand_total_mb,
    ROUND(SUM(total_bytes) / (1024.0 * 1024.0 * 1024.0), 2) AS grand_total_gb,
    COUNT(*) AS readings_count
FROM mikrotik_wan_usage
WHERE counter_reset = FALSE
GROUP BY router_id, (usage_at AT TIME ZONE 'Africa/Cairo')::date
ORDER BY usage_date DESC;

-- 10. Initial Seed Data (Idempotent)
INSERT INTO mikrotik_wan_quotas (
    router_id, interface_name, provider_name, quota_gb, renewal_day, alert_threshold_percent, is_active
) VALUES 
    ('home-router-01', 'wan1', 'Vodafone DSL', 150.00, 19, 80.00, TRUE),
    ('home-router-01', 'wan2', 'WE Egypt (DSL/Fiber)', 140.00, 7, 80.00, TRUE)
ON CONFLICT (router_id, interface_name) 
DO UPDATE SET 
    provider_name = EXCLUDED.provider_name,
    quota_gb = EXCLUDED.quota_gb,
    renewal_day = EXCLUDED.renewal_day,
    alert_threshold_percent = EXCLUDED.alert_threshold_percent,
    is_active = EXCLUDED.is_active;

INSERT INTO wan_incident_state (router_id, interface_name, is_down, consecutive_zero_counts, last_alert_sent_at)
VALUES 
    ('home-router-01', 'wan1', FALSE, 0, NULL),
    ('home-router-01', 'wan2', FALSE, 0, NULL)
ON CONFLICT (router_id, interface_name) DO NOTHING;

INSERT INTO router_heartbeat_state (router_id, is_offline, last_seen_at)
VALUES 
    ('home-router-01', FALSE, NOW())
ON CONFLICT (router_id) DO NOTHING;

-- Seed Day of Week Weights (Egyptian Weekend Pattern: Fri/Sat = 1.30, Weekdays = 0.88)
INSERT INTO quota_day_weights (day_of_week, day_name, weight_multiplier)
VALUES 
    (1, 'Monday', 0.88),
    (2, 'Tuesday', 0.88),
    (3, 'Wednesday', 0.88),
    (4, 'Thursday', 0.88),
    (5, 'Friday', 1.30),
    (6, 'Saturday', 1.30),
    (7, 'Sunday', 0.88)
ON CONFLICT (day_of_week) DO UPDATE SET 
    day_name = EXCLUDED.day_name,
    weight_multiplier = EXCLUDED.weight_multiplier,
    updated_at = NOW();

-- Seed Initial Billing Cycles for Active Quotas (Idempotent)
INSERT INTO billing_cycles (
    router_id, interface_name, cycle_start, cycle_end, status, base_quota_gb
)
SELECT 
    v.router_id,
    v.interface_name,
    v.cycle_start,
    v.renewal_date AS cycle_end,
    'ACTIVE' AS status,
    v.base_quota_gb
FROM view_mikrotik_wan_quota_status v
ON CONFLICT (router_id, interface_name, cycle_start) 
DO UPDATE SET 
    base_quota_gb = EXCLUDED.base_quota_gb,
    cycle_end = EXCLUDED.cycle_end;

-- Seed Initial BASE Quota Allocation for Current Billing Cycles (Idempotent)
INSERT INTO quota_allocations (
    billing_cycle_id, router_id, interface_name, type, amount_gb, effective_at, created_by, reference
)
SELECT 
    bc.id AS billing_cycle_id,
    bc.router_id,
    bc.interface_name,
    'BASE' AS type,
    bc.base_quota_gb AS amount_gb,
    bc.cycle_start::timestamptz AS effective_at,
    'migration' AS created_by,
    'initial_seed' AS reference
FROM billing_cycles bc
WHERE bc.status = 'ACTIVE'
  AND NOT EXISTS (
      SELECT 1 FROM quota_allocations qa 
      WHERE qa.billing_cycle_id = bc.id AND qa.type = 'BASE'
  );

-- Seed Initial WAN Operational States (Idempotent)
INSERT INTO wan_operational_state (router_id, interface_name, current_state, reason)
VALUES 
    ('home-router-01', 'wan1', 'NORMAL', 'Initial baseline state'),
    ('home-router-01', 'wan2', 'NORMAL', 'Initial baseline state')
ON CONFLICT (router_id, interface_name) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 11. Hotspot User Telemetry & Time-series Storage Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hotspot_user_telemetry (
    id BIGSERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    user_name VARCHAR(128) NOT NULL,
    profile VARCHAR(64),
    comment TEXT,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    active_connections_count INTEGER NOT NULL DEFAULT 0,
    ip_address INET,
    mac_address MACADDR,
    session_uptime VARCHAR(32),
    bytes_in BIGINT NOT NULL DEFAULT 0,
    bytes_out BIGINT NOT NULL DEFAULT 0,
    total_bytes BIGINT NOT NULL DEFAULT 0,
    limit_bytes_total BIGINT NOT NULL DEFAULT 0,
    remaining_bytes BIGINT NOT NULL DEFAULT 0,
    total_mb NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_gb NUMERIC(12, 2) NOT NULL DEFAULT 0,
    limit_gb NUMERIC(12, 2),
    remaining_gb NUMERIC(12, 2),
    used_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0,
    alert_tier VARCHAR(16) NOT NULL DEFAULT 'NORMAL',
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indices for Hotspot Telemetry & Fast Analytical Aggregations
CREATE INDEX IF NOT EXISTS idx_hotspot_user_time 
    ON hotspot_user_telemetry (user_name, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_hotspot_router_time 
    ON hotspot_user_telemetry (router_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_hotspot_mac 
    ON hotspot_user_telemetry (mac_address) 
    WHERE mac_address IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hotspot_alert 
    ON hotspot_user_telemetry (alert_tier, recorded_at DESC) 
    WHERE alert_tier != 'NORMAL';

-- ------------------------------------------------------------------------------
-- 12. View: Daily Hotspot User Usage with LAG() Reboot / Reset Resilience
-- Time Zone: Africa/Cairo
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW view_hotspot_daily_user_usage AS
WITH ordered_readings AS (
    SELECT 
        id,
        router_id,
        user_name,
        total_bytes,
        used_percentage,
        recorded_at,
        (recorded_at AT TIME ZONE 'Africa/Cairo')::date AS usage_date,
        -- Fetch immediately preceding sample for this exact user & router
        LAG(total_bytes) OVER (
            PARTITION BY router_id, user_name 
            ORDER BY recorded_at ASC
        ) AS prev_bytes,
        -- Fetch preceding date to guard across day transitions
        LAG((recorded_at AT TIME ZONE 'Africa/Cairo')::date) OVER (
            PARTITION BY router_id, user_name 
            ORDER BY recorded_at ASC
        ) AS prev_date
    FROM hotspot_user_telemetry
),
calculated_deltas AS (
    SELECT 
        router_id,
        user_name,
        usage_date,
        total_bytes,
        used_percentage,
        recorded_at,
        CASE
            -- First record ever seen: delta is zero (establishes baseline)
            WHEN prev_bytes IS NULL THEN 0
            -- Date changed: if previous was from yesterday, start from current
            WHEN prev_date < usage_date THEN 0
            -- Normal monotonic counter increase
            WHEN total_bytes >= prev_bytes THEN (total_bytes - prev_bytes)
            -- Counter Reset / Router Reboot: Previous counter was wiped, take current value as delta
            ELSE total_bytes
        END AS delta_bytes,
        CASE
            WHEN prev_bytes IS NOT NULL AND total_bytes < prev_bytes THEN TRUE
            ELSE FALSE
        END AS is_reboot_reset
    FROM ordered_readings
)
SELECT 
    router_id,
    user_name,
    usage_date,
    ROUND(SUM(delta_bytes) / (1024.0 * 1024.0), 2) AS consumed_today_mb,
    ROUND(SUM(delta_bytes) / (1024.0 * 1024.0 * 1024.0), 2) AS consumed_today_gb,
    MAX(used_percentage) AS peak_used_percentage,
    COUNT(*) AS samples_count,
    BOOL_OR(is_reboot_reset) AS had_reboot_or_reset,
    MIN(recorded_at) AS first_sample_at,
    MAX(recorded_at) AS last_sample_at
FROM calculated_deltas
GROUP BY router_id, user_name, usage_date
ORDER BY usage_date DESC, consumed_today_gb DESC;

-- ------------------------------------------------------------------------------
-- 13. Data Retention & Housekeeping Maintenance Procedure
-- Retains rolling 90 days of high-frequency telemetry.
-- Call manually or schedule via pg_cron: CALL purge_expired_mikrotik_telemetry(90);
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE purge_expired_mikrotik_telemetry(retention_days INTEGER DEFAULT 90)
LANGUAGE plpgsql
AS $$
DECLARE
    cutoff_timestamp TIMESTAMPTZ;
    purged_readings_count BIGINT;
    purged_hotspot_count BIGINT;
BEGIN
    cutoff_timestamp := NOW() - (retention_days || ' days')::INTERVAL;

    -- Purge raw WAN telemetry (Cascades automatically to mikrotik_wan_usage)
    DELETE FROM mikrotik_wan_readings
    WHERE received_at < cutoff_timestamp;
    GET DIAGNOSTICS purged_readings_count = ROW_COUNT;

    -- Purge Hotspot raw user telemetry
    DELETE FROM hotspot_user_telemetry
    WHERE recorded_at < cutoff_timestamp;
    GET DIAGNOSTICS purged_hotspot_count = ROW_COUNT;

    RAISE NOTICE 'Housekeeping Complete (Cutoff: %). Purged % WAN readings and % Hotspot records.',
        cutoff_timestamp, purged_readings_count, purged_hotspot_count;
END;
$$;
-- ------------------------------------------------------------------------------
-- 14. WAN Interface Latency, RTT & Quality Monitoring Table
-- Frequency: Ingested alongside periodic telemetry or dedicated Netwatch probes
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mikrotik_wan_quality (
    id BIGSERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    interface_name VARCHAR(32) NOT NULL,
    target_host VARCHAR(64) NOT NULL DEFAULT '8.8.8.8',
    latency_ms NUMERIC(6, 2) NOT NULL DEFAULT 0.00,
    min_latency_ms NUMERIC(6, 2),
    max_latency_ms NUMERIC(6, 2),
    packet_loss_percent NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    jitter_ms NUMERIC(6, 2) DEFAULT 0.00,
    status VARCHAR(16) NOT NULL DEFAULT 'HEALTHY' CHECK (status IN ('HEALTHY', 'DEGRADED', 'DOWN')),
    probed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wan_quality_router_time 
    ON mikrotik_wan_quality (router_id, interface_name, probed_at DESC);

CREATE INDEX IF NOT EXISTS idx_wan_quality_probed_at 
    ON mikrotik_wan_quality (probed_at DESC);

-- View: Latest Quality Status per Interface
CREATE OR REPLACE VIEW view_mikrotik_wan_latest_quality AS
SELECT DISTINCT ON (router_id, interface_name)
    router_id,
    interface_name,
    target_host,
    latency_ms,
    packet_loss_percent,
    jitter_ms,
    status,
    probed_at
FROM mikrotik_wan_quality
ORDER BY router_id, interface_name, probed_at DESC;


-- ------------------------------------------------------------------------------
-- 15. WAN Outage Events & NTRA ISP Compensation Claims
-- Frequency: Logged on outage detection / recovery, used for claims dispatch
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wan_outage_events (
    id BIGSERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    interface_name VARCHAR(32) NOT NULL,
    provider_name VARCHAR(64) NOT NULL,
    landline_number VARCHAR(32) NOT NULL,
    account_holder VARCHAR(128) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_minutes INTEGER,
    outage_cause VARCHAR(32) NOT NULL DEFAULT 'ISP_FAILURE',
    email_sent BOOLEAN NOT NULL DEFAULT FALSE,
    email_sent_at TIMESTAMPTZ,
    email_recipient VARCHAR(128),
    email_subject TEXT,
    email_body TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wan_outage_events_started 
    ON wan_outage_events (started_at DESC);

CREATE INDEX IF NOT EXISTS idx_wan_outage_events_router_iface 
    ON wan_outage_events (router_id, interface_name, started_at DESC);

-- ------------------------------------------------------------------------------
-- 16. Co-hosted Campaign Schema Reference (campaign_db shared tables)
-- Scoped tables for quota reservations, safety parameters, and campaign metrics
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'campaigntargetstatus') THEN
        CREATE TYPE campaigntargetstatus AS ENUM (
            'PENDING', 'CLAIMED', 'SENDING', 'SUCCESS', 'FAILED', 
            'SKIPPED', 'CANCELLED', 'DEAD_LETTER', 'DISPATCHED', 'UNKNOWN'
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS quota_reservations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    campaign_id INTEGER NOT NULL,
    reserved_messages INTEGER NOT NULL,
    consumed_messages INTEGER NOT NULL DEFAULT 0,
    released_messages INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL DEFAULT 'RESERVED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS campaign_safety_settings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    whatsapp_instance_id INTEGER NOT NULL UNIQUE,
    min_delay_seconds DOUBLE PRECISION NOT NULL DEFAULT 8.0,
    max_delay_seconds DOUBLE PRECISION NOT NULL DEFAULT 15.0,
    batch_size INTEGER NOT NULL DEFAULT 10,
    batch_cooldown_seconds INTEGER NOT NULL DEFAULT 120,
    daily_message_limit INTEGER NOT NULL DEFAULT 100,
    campaign_message_limit INTEGER NOT NULL DEFAULT 50,
    is_safety_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS campaign_metric_snapshots (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL,
    instance_name VARCHAR(100),
    campaigns_started_today INTEGER NOT NULL DEFAULT 0,
    campaigns_completed_today INTEGER NOT NULL DEFAULT 0,
    campaigns_failed_today INTEGER NOT NULL DEFAULT 0,
    groups_targeted_today INTEGER NOT NULL DEFAULT 0,
    successful_sends_today INTEGER NOT NULL DEFAULT 0,
    failed_sends_today INTEGER NOT NULL DEFAULT 0,
    retries_today INTEGER NOT NULL DEFAULT 0,
    pending_queue_count INTEGER NOT NULL DEFAULT 0,
    success_rate_percent DOUBLE PRECISION NOT NULL DEFAULT 100.0,
    groups_per_hour DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    avg_campaign_duration_seconds DOUBLE PRECISION NOT NULL DEFAULT 0.0
);

CREATE TABLE IF NOT EXISTS campaign_rebalance_events (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL,
    source_instance_id INTEGER NOT NULL,
    destination_instance_id INTEGER,
    reason_code VARCHAR(100) NOT NULL,
    moved_targets_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    eligible_targets_evaluated INTEGER NOT NULL DEFAULT 0,
    targets_skipped_active_lease INTEGER NOT NULL DEFAULT 0,
    targets_unassignable INTEGER NOT NULL DEFAULT 0,
    total_targets_in_scope INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS campaign_groups (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL,
    group_jid VARCHAR(255) NOT NULL,
    group_name VARCHAR(255),
    invite_link VARCHAR(500),
    target_members INTEGER NOT NULL DEFAULT 700,
    confirmed_joined INTEGER NOT NULL DEFAULT 0,
    pending_invites INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL DEFAULT 'OPEN',
    priority INTEGER NOT NULL DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS campaign_targets (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL,
    target_id INTEGER NOT NULL,
    status campaigntargetstatus NOT NULL,
    attempts INTEGER NOT NULL,
    last_attempt_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_code VARCHAR,
    error_message VARCHAR,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    lease_token VARCHAR(100),
    assigned_instance_id INTEGER,
    provider_message_id VARCHAR(255),
    next_attempt_at TIMESTAMPTZ,
    delivery_status VARCHAR(32),
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ
);
