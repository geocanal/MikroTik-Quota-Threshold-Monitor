--
-- PostgreSQL database dump
--

\restrict a7ZYmexYcEmZmfBXU6crqFhY8PQFK2Qpm1hc5K4lsn6Kp9uEFV93PNgaltzJu6r

-- Dumped from database version 16.15 (Debian 16.15-1.pgdg13+2)
-- Dumped by pg_dump version 16.15 (Debian 16.15-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: evolution; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA evolution;


--
-- Name: test_382c30a5b6134647b1d9e672ea00d45b; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA test_382c30a5b6134647b1d9e672ea00d45b;


--
-- Name: test_640dbf5abefb4790bf6f50095f5ba563; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA test_640dbf5abefb4790bf6f50095f5ba563;


--
-- Name: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA test_818d3ceb0ced4bb09b0a383c38a9cd7a;


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: DeviceMessage; Type: TYPE; Schema: evolution; Owner: -
--

CREATE TYPE evolution."DeviceMessage" AS ENUM (
    'ios',
    'android',
    'web',
    'unknown',
    'desktop'
);


--
-- Name: DifyBotType; Type: TYPE; Schema: evolution; Owner: -
--

CREATE TYPE evolution."DifyBotType" AS ENUM (
    'chatBot',
    'textGenerator',
    'agent',
    'workflow'
);


--
-- Name: InstanceConnectionStatus; Type: TYPE; Schema: evolution; Owner: -
--

CREATE TYPE evolution."InstanceConnectionStatus" AS ENUM (
    'open',
    'close',
    'connecting'
);


--
-- Name: OpenaiBotType; Type: TYPE; Schema: evolution; Owner: -
--

CREATE TYPE evolution."OpenaiBotType" AS ENUM (
    'assistant',
    'chatCompletion'
);


--
-- Name: SessionStatus; Type: TYPE; Schema: evolution; Owner: -
--

CREATE TYPE evolution."SessionStatus" AS ENUM (
    'opened',
    'closed',
    'paused'
);


--
-- Name: TriggerOperator; Type: TYPE; Schema: evolution; Owner: -
--

CREATE TYPE evolution."TriggerOperator" AS ENUM (
    'contains',
    'equals',
    'startsWith',
    'endsWith',
    'regex'
);


--
-- Name: TriggerType; Type: TYPE; Schema: evolution; Owner: -
--

CREATE TYPE evolution."TriggerType" AS ENUM (
    'all',
    'keyword',
    'none',
    'advanced'
);


--
-- Name: campaignstatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.campaignstatus AS ENUM (
    'DRAFT',
    'QUEUED',
    'SCHEDULED',
    'RUNNING',
    'PAUSED',
    'STOPPING',
    'STOPPED',
    'COMPLETED',
    'FAILED'
);


--
-- Name: campaigntargetstatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.campaigntargetstatus AS ENUM (
    'PENDING',
    'CLAIMED',
    'SENDING',
    'SUCCESS',
    'FAILED',
    'SKIPPED',
    'CANCELLED',
    'DEAD_LETTER',
    'DISPATCHED',
    'UNKNOWN'
);


--
-- Name: executionresultstatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.executionresultstatus AS ENUM (
    'SUCCESS',
    'TEMPORARY_FAILURE',
    'PERMANENT_FAILURE'
);


--
-- Name: campaignstatus; Type: TYPE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TYPE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaignstatus AS ENUM (
    'DRAFT',
    'QUEUED',
    'SCHEDULED',
    'RUNNING',
    'PAUSED',
    'STOPPING',
    'STOPPED',
    'COMPLETED',
    'FAILED'
);


--
-- Name: campaigntargetstatus; Type: TYPE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TYPE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigntargetstatus AS ENUM (
    'PENDING',
    'CLAIMED',
    'DISPATCHED',
    'SENDING',
    'SUCCESS',
    'FAILED',
    'UNKNOWN',
    'SKIPPED',
    'CANCELLED',
    'DEAD_LETTER'
);


--
-- Name: executionresultstatus; Type: TYPE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TYPE test_818d3ceb0ced4bb09b0a383c38a9cd7a.executionresultstatus AS ENUM (
    'SUCCESS',
    'TEMPORARY_FAILURE',
    'PERMANENT_FAILURE'
);


--
-- Name: calculate_adaptive_burn_rate(character varying, character varying, date, date, numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_adaptive_burn_rate(p_router_id character varying, p_interface_name character varying, p_cycle_start date, p_today_date date, p_total_used_bytes numeric, p_base_quota_gb numeric) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


--
-- Name: calculate_cycle_boundary_date(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_cycle_boundary_date(target_year integer, target_month integer, renewal_day integer) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $$
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
$$;


--
-- Name: confirm_router_execution(character varying, character varying, character varying, character varying, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_router_execution(p_idempotency_key character varying, p_router_id character varying, p_interface_name character varying, p_execution_status character varying, p_receipt jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: purge_expired_mikrotik_telemetry(integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.purge_expired_mikrotik_telemetry(IN retention_days integer DEFAULT 90)
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


--
-- Name: transition_wan_state(character varying, character varying, character varying, character varying, character varying, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transition_wan_state(p_idempotency_key character varying, p_router_id character varying, p_interface_name character varying, p_action_type character varying, p_requested_by character varying, p_reason text, p_force boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
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
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Chat; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Chat" (
    id text NOT NULL,
    "remoteJid" character varying(100) NOT NULL,
    labels jsonb,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone,
    "instanceId" text NOT NULL,
    name character varying(100),
    "unreadMessages" integer DEFAULT 0 NOT NULL
);


--
-- Name: Chatwoot; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Chatwoot" (
    id text NOT NULL,
    enabled boolean DEFAULT true,
    "accountId" character varying(100),
    token character varying(100),
    url character varying(500),
    "nameInbox" character varying(100),
    "signMsg" boolean DEFAULT false,
    "signDelimiter" character varying(100),
    number character varying(100),
    "reopenConversation" boolean DEFAULT false,
    "conversationPending" boolean DEFAULT false,
    "mergeBrazilContacts" boolean DEFAULT false,
    "importContacts" boolean DEFAULT false,
    "importMessages" boolean DEFAULT false,
    "daysLimitImportMessages" integer,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    logo character varying(500),
    organization character varying(100),
    "ignoreJids" jsonb
);


--
-- Name: Contact; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Contact" (
    id text NOT NULL,
    "remoteJid" character varying(100) NOT NULL,
    "pushName" character varying(100),
    "profilePicUrl" character varying(500),
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone,
    "instanceId" text NOT NULL
);


--
-- Name: Dify; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Dify" (
    id text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    "botType" evolution."DifyBotType" NOT NULL,
    "apiUrl" character varying(255),
    "apiKey" character varying(255),
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "triggerType" evolution."TriggerType",
    "triggerOperator" evolution."TriggerOperator",
    "triggerValue" text,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    description character varying(255),
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: DifySetting; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."DifySetting" (
    id text NOT NULL,
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "difyIdFallback" character varying(100),
    "instanceId" text NOT NULL,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: Evoai; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Evoai" (
    id text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    description character varying(255),
    "agentUrl" character varying(255),
    "apiKey" character varying(255),
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50,
    "triggerType" evolution."TriggerType",
    "triggerOperator" evolution."TriggerOperator",
    "triggerValue" text,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: EvoaiSetting; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."EvoaiSetting" (
    id text NOT NULL,
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "evoaiIdFallback" character varying(100),
    "instanceId" text NOT NULL
);


--
-- Name: EvolutionBot; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."EvolutionBot" (
    id text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    description character varying(255),
    "apiUrl" character varying(255),
    "apiKey" character varying(255),
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "triggerType" evolution."TriggerType",
    "triggerOperator" evolution."TriggerOperator",
    "triggerValue" text,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: EvolutionBotSetting; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."EvolutionBotSetting" (
    id text NOT NULL,
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "botIdFallback" character varying(100),
    "instanceId" text NOT NULL,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: Flowise; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Flowise" (
    id text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    description character varying(255),
    "apiUrl" character varying(255),
    "apiKey" character varying(255),
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "triggerType" evolution."TriggerType",
    "triggerOperator" evolution."TriggerOperator",
    "triggerValue" text,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: FlowiseSetting; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."FlowiseSetting" (
    id text NOT NULL,
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "flowiseIdFallback" character varying(100),
    "instanceId" text NOT NULL,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: Instance; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Instance" (
    id text NOT NULL,
    name character varying(255) NOT NULL,
    "connectionStatus" evolution."InstanceConnectionStatus" DEFAULT 'open'::evolution."InstanceConnectionStatus" NOT NULL,
    "ownerJid" character varying(100),
    "profilePicUrl" character varying(500),
    integration character varying(100),
    number character varying(100),
    token character varying(255),
    "clientName" character varying(100),
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone,
    "profileName" character varying(100),
    "businessId" character varying(100),
    "disconnectionAt" timestamp without time zone,
    "disconnectionObject" jsonb,
    "disconnectionReasonCode" integer
);


--
-- Name: IntegrationSession; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."IntegrationSession" (
    id text NOT NULL,
    "sessionId" character varying(255) NOT NULL,
    "remoteJid" character varying(100) NOT NULL,
    "pushName" text,
    status evolution."SessionStatus" NOT NULL,
    "awaitUser" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    parameters jsonb,
    context jsonb,
    "botId" text,
    type character varying(100)
);


--
-- Name: IsOnWhatsapp; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."IsOnWhatsapp" (
    id text NOT NULL,
    "remoteJid" character varying(100) NOT NULL,
    "jidOptions" text NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    lid character varying(100)
);


--
-- Name: Kafka; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Kafka" (
    id text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    events jsonb NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: Label; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Label" (
    id text NOT NULL,
    "labelId" character varying(100),
    name character varying(100) NOT NULL,
    color character varying(100) NOT NULL,
    "predefinedId" character varying(100),
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: Media; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Media" (
    id text NOT NULL,
    "fileName" character varying(500) NOT NULL,
    type character varying(100) NOT NULL,
    mimetype character varying(100) NOT NULL,
    "createdAt" date DEFAULT CURRENT_TIMESTAMP,
    "messageId" text NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: Message; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Message" (
    id text NOT NULL,
    key jsonb NOT NULL,
    "pushName" character varying(100),
    participant character varying(100),
    "messageType" character varying(100) NOT NULL,
    message jsonb NOT NULL,
    "contextInfo" jsonb,
    source evolution."DeviceMessage" NOT NULL,
    "messageTimestamp" integer NOT NULL,
    "chatwootMessageId" integer,
    "chatwootInboxId" integer,
    "chatwootConversationId" integer,
    "chatwootContactInboxSourceId" character varying(100),
    "chatwootIsRead" boolean,
    "instanceId" text NOT NULL,
    "webhookUrl" character varying(500),
    "sessionId" text,
    status character varying(30)
);


--
-- Name: MessageUpdate; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."MessageUpdate" (
    id text NOT NULL,
    "keyId" character varying(100) NOT NULL,
    "remoteJid" character varying(100) NOT NULL,
    "fromMe" boolean NOT NULL,
    participant character varying(100),
    "pollUpdates" jsonb,
    status character varying(30) NOT NULL,
    "messageId" text NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: N8n; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."N8n" (
    id text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    description character varying(255),
    "webhookUrl" character varying(255),
    "basicAuthUser" character varying(255),
    "basicAuthPass" character varying(255),
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50,
    "triggerType" evolution."TriggerType",
    "triggerOperator" evolution."TriggerOperator",
    "triggerValue" text,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: N8nSetting; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."N8nSetting" (
    id text NOT NULL,
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "n8nIdFallback" character varying(100),
    "instanceId" text NOT NULL
);


--
-- Name: Nats; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Nats" (
    id text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    events jsonb NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: OpenaiBot; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."OpenaiBot" (
    id text NOT NULL,
    "assistantId" character varying(255),
    model character varying(100),
    "systemMessages" jsonb,
    "assistantMessages" jsonb,
    "userMessages" jsonb,
    "maxTokens" integer,
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "triggerType" evolution."TriggerType",
    "triggerOperator" evolution."TriggerOperator",
    "triggerValue" text,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "openaiCredsId" text NOT NULL,
    "instanceId" text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    "botType" evolution."OpenaiBotType" NOT NULL,
    description character varying(255),
    "functionUrl" character varying(500),
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: OpenaiCreds; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."OpenaiCreds" (
    id text NOT NULL,
    "apiKey" character varying(255),
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    name character varying(255)
);


--
-- Name: OpenaiSetting; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."OpenaiSetting" (
    id text NOT NULL,
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "openaiCredsId" text NOT NULL,
    "openaiIdFallback" character varying(100),
    "instanceId" text NOT NULL,
    "speechToText" boolean DEFAULT false,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: Proxy; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Proxy" (
    id text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    host character varying(100) NOT NULL,
    port character varying(100) NOT NULL,
    protocol character varying(100) NOT NULL,
    username character varying(100) NOT NULL,
    password character varying(100) NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: Pusher; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Pusher" (
    id text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    "appId" character varying(100) NOT NULL,
    key character varying(100) NOT NULL,
    secret character varying(100) NOT NULL,
    cluster character varying(100) NOT NULL,
    "useTLS" boolean DEFAULT false NOT NULL,
    events jsonb NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: Rabbitmq; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Rabbitmq" (
    id text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    events jsonb NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: Session; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Session" (
    id text NOT NULL,
    "sessionId" text NOT NULL,
    creds text,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: Setting; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Setting" (
    id text NOT NULL,
    "rejectCall" boolean DEFAULT false NOT NULL,
    "msgCall" character varying(100),
    "groupsIgnore" boolean DEFAULT false NOT NULL,
    "alwaysOnline" boolean DEFAULT false NOT NULL,
    "readMessages" boolean DEFAULT false NOT NULL,
    "readStatus" boolean DEFAULT false NOT NULL,
    "syncFullHistory" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    "wavoipToken" character varying(100)
);


--
-- Name: Sqs; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Sqs" (
    id text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    events jsonb NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: Template; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Template" (
    id text NOT NULL,
    "templateId" character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    template jsonb NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    "webhookUrl" character varying(500)
);


--
-- Name: Typebot; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Typebot" (
    id text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    url character varying(500) NOT NULL,
    typebot character varying(100) NOT NULL,
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone,
    "triggerType" evolution."TriggerType",
    "triggerOperator" evolution."TriggerOperator",
    "triggerValue" text,
    "instanceId" text NOT NULL,
    "debounceTime" integer,
    "ignoreJids" jsonb,
    description character varying(255),
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: TypebotSetting; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."TypebotSetting" (
    id text NOT NULL,
    expire integer DEFAULT 0,
    "keywordFinish" character varying(100),
    "delayMessage" integer,
    "unknownMessage" character varying(100),
    "listeningFromMe" boolean DEFAULT false,
    "stopBotFromMe" boolean DEFAULT false,
    "keepOpen" boolean DEFAULT false,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    "debounceTime" integer,
    "typebotIdFallback" character varying(100),
    "ignoreJids" jsonb,
    "splitMessages" boolean DEFAULT false,
    "timePerChar" integer DEFAULT 50
);


--
-- Name: Webhook; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Webhook" (
    id text NOT NULL,
    url character varying(500) NOT NULL,
    enabled boolean DEFAULT true,
    events jsonb,
    "webhookByEvents" boolean DEFAULT false,
    "webhookBase64" boolean DEFAULT false,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL,
    headers jsonb
);


--
-- Name: Websocket; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution."Websocket" (
    id text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    events jsonb NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL,
    "instanceId" text NOT NULL
);


--
-- Name: _prisma_migrations; Type: TABLE; Schema: evolution; Owner: -
--

CREATE TABLE evolution._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


--
-- Name: ai_action_idempotency; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_action_idempotency (
    id integer NOT NULL,
    idempotency_key character varying(128) NOT NULL,
    tenant_id integer NOT NULL,
    inbound_message_id integer NOT NULL,
    conversation_id integer NOT NULL,
    action_type character varying(50) DEFAULT 'AUTO_REPLY'::character varying NOT NULL,
    state character varying(32) DEFAULT 'STARTED'::character varying NOT NULL,
    execution_id character varying(64) NOT NULL,
    trace_id character varying(64),
    outbound_message_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone
);


--
-- Name: ai_action_idempotency_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_action_idempotency_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_action_idempotency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_action_idempotency_id_seq OWNED BY public.ai_action_idempotency.id;


--
-- Name: ai_anomalies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_anomalies (
    id integer NOT NULL,
    user_id integer NOT NULL,
    anomaly_type character varying(50) NOT NULL,
    severity character varying(20) DEFAULT 'WARNING'::character varying NOT NULL,
    observed_value double precision NOT NULL,
    threshold_value double precision NOT NULL,
    details text,
    trace_id character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_anomalies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_anomalies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_anomalies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_anomalies_id_seq OWNED BY public.ai_anomalies.id;


--
-- Name: ai_budget_reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_budget_reservations (
    id integer NOT NULL,
    reservation_id character varying(64) NOT NULL,
    tenant_id integer NOT NULL,
    execution_id character varying(64) NOT NULL,
    trace_id character varying(64),
    requested_tokens integer DEFAULT 0 NOT NULL,
    reserved_tokens integer DEFAULT 0 NOT NULL,
    settled_tokens integer DEFAULT 0 NOT NULL,
    requested_cost_usd numeric(12,4) DEFAULT 0.0000 NOT NULL,
    reserved_cost_usd numeric(12,4) DEFAULT 0.0000 NOT NULL,
    settled_cost_usd numeric(12,4) DEFAULT 0.0000 NOT NULL,
    status character varying(32) DEFAULT 'RESERVED'::character varying NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    settled_at timestamp with time zone,
    released_at timestamp with time zone
);


--
-- Name: ai_budget_reservations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_budget_reservations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_budget_reservations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_budget_reservations_id_seq OWNED BY public.ai_budget_reservations.id;


--
-- Name: ai_circuit_breakers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_circuit_breakers (
    id integer NOT NULL,
    user_id integer NOT NULL,
    circuit_type character varying(50) NOT NULL,
    state character varying(20) DEFAULT 'CLOSED'::character varying NOT NULL,
    failure_count integer DEFAULT 0 NOT NULL,
    last_failure_reason character varying(255),
    opened_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_circuit_breakers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_circuit_breakers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_circuit_breakers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_circuit_breakers_id_seq OWNED BY public.ai_circuit_breakers.id;


--
-- Name: ai_configurations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_configurations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    mode character varying(50) DEFAULT 'DRY_RUN'::character varying NOT NULL,
    provider character varying(50) DEFAULT 'OPENAI'::character varying NOT NULL,
    model character varying(100) DEFAULT 'gpt-4o-mini'::character varying NOT NULL,
    api_key_ciphertext text,
    system_prompt text,
    business_context text,
    language character varying(50) DEFAULT 'ar-EG'::character varying NOT NULL,
    tone character varying(100) DEFAULT 'professional, helpful'::character varying NOT NULL,
    temperature double precision DEFAULT '0.3'::double precision NOT NULL,
    max_tokens integer DEFAULT 500 NOT NULL,
    confidence_threshold double precision DEFAULT '0.8'::double precision NOT NULL,
    auto_reply_enabled boolean DEFAULT false NOT NULL,
    escalation_enabled boolean DEFAULT true NOT NULL,
    human_takeover_timeout_minutes integer DEFAULT 60 NOT NULL,
    prompt_version integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    max_response_length integer DEFAULT 500 NOT NULL,
    daily_message_limit integer DEFAULT 100 NOT NULL,
    daily_token_limit integer DEFAULT 100000 NOT NULL,
    daily_cost_limit double precision DEFAULT '5'::double precision NOT NULL,
    provider_mode character varying(12) DEFAULT 'SYSTEM_QUOTA'::character varying NOT NULL,
    api_key_last4 character varying(4),
    api_key_validated_at timestamp with time zone
);


--
-- Name: ai_configurations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_configurations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_configurations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_configurations_id_seq OWNED BY public.ai_configurations.id;


--
-- Name: ai_control_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_control_audit_events (
    id integer NOT NULL,
    tenant_id integer,
    actor_id integer,
    event_type character varying(100) NOT NULL,
    reason text,
    previous_state character varying(255),
    new_state character varying(255),
    trace_id character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_control_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_control_audit_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_control_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_control_audit_events_id_seq OWNED BY public.ai_control_audit_events.id;


--
-- Name: ai_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_decisions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    conversation_id integer NOT NULL,
    message_id integer NOT NULL,
    ai_job_id integer,
    provider character varying(50) DEFAULT 'openai'::character varying NOT NULL,
    model character varying(100) DEFAULT 'gpt-4o-mini'::character varying NOT NULL,
    action character varying(50) NOT NULL,
    category character varying(50) NOT NULL,
    confidence double precision DEFAULT '1'::double precision NOT NULL,
    reason text,
    proposed_reply text,
    policy_result character varying(50) DEFAULT 'APPROVED'::character varying NOT NULL,
    prompt_version integer DEFAULT 1 NOT NULL,
    input_tokens integer DEFAULT 0 NOT NULL,
    output_tokens integer DEFAULT 0 NOT NULL,
    latency_ms double precision DEFAULT '0'::double precision NOT NULL,
    estimated_cost_usd double precision DEFAULT '0'::double precision NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    trace_id character varying(64)
);


--
-- Name: ai_decisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_decisions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_decisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_decisions_id_seq OWNED BY public.ai_decisions.id;


--
-- Name: ai_execution_traces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_execution_traces (
    id integer NOT NULL,
    trace_id character varying(64) NOT NULL,
    user_id integer NOT NULL,
    conversation_id integer NOT NULL,
    message_id integer NOT NULL,
    ai_job_id integer,
    operation character varying(50) DEFAULT 'conversation_reply'::character varying NOT NULL,
    provider character varying(50) DEFAULT 'openai'::character varying NOT NULL,
    model character varying(100) DEFAULT 'gpt-4o-mini'::character varying NOT NULL,
    prompt_version integer DEFAULT 1 NOT NULL,
    prompt_hash character varying(64),
    policy_version integer DEFAULT 1 NOT NULL,
    config_version integer DEFAULT 1 NOT NULL,
    input_tokens integer DEFAULT 0 NOT NULL,
    output_tokens integer DEFAULT 0 NOT NULL,
    total_tokens integer DEFAULT 0 NOT NULL,
    estimated_cost_usd double precision DEFAULT '0'::double precision NOT NULL,
    latency_ms double precision DEFAULT '0'::double precision NOT NULL,
    result_status character varying(50) DEFAULT 'SUCCESS'::character varying NOT NULL,
    action_taken character varying(50) DEFAULT 'AUTO_REPLY'::character varying NOT NULL,
    policy_result character varying(50) DEFAULT 'APPROVED'::character varying NOT NULL,
    decision_confidence double precision DEFAULT '1'::double precision NOT NULL,
    is_autonomous boolean DEFAULT false NOT NULL,
    is_escalated boolean DEFAULT false NOT NULL,
    failure_category character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_execution_traces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_execution_traces_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_execution_traces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_execution_traces_id_seq OWNED BY public.ai_execution_traces.id;


--
-- Name: ai_global_controls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_global_controls (
    id integer NOT NULL,
    ai_enabled boolean DEFAULT false NOT NULL,
    autonomous_enabled boolean DEFAULT false NOT NULL,
    emergency_stop boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_id integer
);


--
-- Name: ai_global_controls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_global_controls_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_global_controls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_global_controls_id_seq OWNED BY public.ai_global_controls.id;


--
-- Name: ai_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_jobs (
    id integer NOT NULL,
    user_id integer NOT NULL,
    conversation_id integer NOT NULL,
    message_id integer NOT NULL,
    status character varying(50) DEFAULT 'PENDING'::character varying NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 3 NOT NULL,
    lease_token character varying(100),
    locked_at timestamp with time zone,
    prompt_version integer DEFAULT 1 NOT NULL,
    decision jsonb,
    error_code character varying(100),
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone
);


--
-- Name: ai_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_jobs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_jobs_id_seq OWNED BY public.ai_jobs.id;


--
-- Name: ai_policy_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_policy_versions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    version integer NOT NULL,
    policy_hash character varying(64) NOT NULL,
    rules_json jsonb NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_policy_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_policy_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_policy_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_policy_versions_id_seq OWNED BY public.ai_policy_versions.id;


--
-- Name: ai_prompt_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_prompt_versions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    version integer NOT NULL,
    system_prompt text NOT NULL,
    business_context text,
    content_hash character varying(64) NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_prompt_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_prompt_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_prompt_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_prompt_versions_id_seq OWNED BY public.ai_prompt_versions.id;


--
-- Name: ai_tenant_budgets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_tenant_budgets (
    id integer NOT NULL,
    tenant_id integer NOT NULL,
    budget_period character varying(50) DEFAULT 'DAILY'::character varying NOT NULL,
    max_tokens integer DEFAULT 500000 NOT NULL,
    max_cost_usd numeric(12,4) DEFAULT 10.0000 NOT NULL,
    consumed_tokens integer DEFAULT 0 NOT NULL,
    consumed_cost_usd numeric(12,4) DEFAULT 0.0000 NOT NULL,
    reserved_tokens integer DEFAULT 0 NOT NULL,
    reserved_cost_usd numeric(12,4) DEFAULT 0.0000 NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_tenant_budgets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_tenant_budgets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_tenant_budgets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_tenant_budgets_id_seq OWNED BY public.ai_tenant_budgets.id;


--
-- Name: ai_tenant_controls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_tenant_controls (
    id integer NOT NULL,
    tenant_id integer NOT NULL,
    ai_enabled boolean DEFAULT false NOT NULL,
    autonomous_enabled boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_tenant_controls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_tenant_controls_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_tenant_controls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_tenant_controls_id_seq OWNED BY public.ai_tenant_controls.id;


--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


--
-- Name: billing_cycles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_cycles (
    id bigint NOT NULL,
    router_id character varying(64) NOT NULL,
    interface_name character varying(32) NOT NULL,
    cycle_start date NOT NULL,
    cycle_end date NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    base_quota_gb numeric(10,2) DEFAULT 0.00 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    initial_offset_gb numeric(10,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT billing_cycles_status_check CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'CLOSED'::character varying, 'RECONCILED'::character varying])::text[]))),
    CONSTRAINT chk_cycle_end_after_start CHECK ((cycle_end > cycle_start))
);


--
-- Name: billing_cycles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.billing_cycles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: billing_cycles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.billing_cycles_id_seq OWNED BY public.billing_cycles.id;


--
-- Name: campaign_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign_groups (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    group_jid character varying(255) NOT NULL,
    group_name character varying(255),
    invite_link character varying(500),
    target_members integer DEFAULT 700 NOT NULL,
    confirmed_joined integer DEFAULT 0 NOT NULL,
    pending_invites integer DEFAULT 0 NOT NULL,
    status character varying(50) DEFAULT 'OPEN'::character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: campaign_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campaign_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campaign_groups_id_seq OWNED BY public.campaign_groups.id;


--
-- Name: campaign_metric_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign_metric_snapshots (
    id integer NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    instance_name character varying(100),
    campaigns_started_today integer DEFAULT 0 NOT NULL,
    campaigns_completed_today integer DEFAULT 0 NOT NULL,
    campaigns_failed_today integer DEFAULT 0 NOT NULL,
    groups_targeted_today integer DEFAULT 0 NOT NULL,
    successful_sends_today integer DEFAULT 0 NOT NULL,
    failed_sends_today integer DEFAULT 0 NOT NULL,
    retries_today integer DEFAULT 0 NOT NULL,
    pending_queue_count integer DEFAULT 0 NOT NULL,
    success_rate_percent double precision DEFAULT '100'::double precision NOT NULL,
    groups_per_hour double precision DEFAULT '0'::double precision NOT NULL,
    avg_campaign_duration_seconds double precision DEFAULT '0'::double precision NOT NULL
);


--
-- Name: campaign_metric_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campaign_metric_snapshots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_metric_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campaign_metric_snapshots_id_seq OWNED BY public.campaign_metric_snapshots.id;


--
-- Name: campaign_rebalance_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign_rebalance_events (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    source_instance_id integer NOT NULL,
    destination_instance_id integer,
    reason_code character varying(100) NOT NULL,
    moved_targets_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    eligible_targets_evaluated integer DEFAULT 0 NOT NULL,
    targets_skipped_active_lease integer DEFAULT 0 NOT NULL,
    targets_unassignable integer DEFAULT 0 NOT NULL,
    total_targets_in_scope integer DEFAULT 0 NOT NULL
);


--
-- Name: campaign_rebalance_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campaign_rebalance_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_rebalance_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campaign_rebalance_events_id_seq OWNED BY public.campaign_rebalance_events.id;


--
-- Name: campaign_safety_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign_safety_settings (
    id integer NOT NULL,
    user_id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    min_delay_seconds double precision DEFAULT '8'::double precision NOT NULL,
    max_delay_seconds double precision DEFAULT '15'::double precision NOT NULL,
    batch_size integer DEFAULT 10 NOT NULL,
    batch_cooldown_seconds integer DEFAULT 120 NOT NULL,
    daily_message_limit integer DEFAULT 100 NOT NULL,
    campaign_message_limit integer DEFAULT 50 NOT NULL,
    is_safety_enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: campaign_safety_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campaign_safety_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_safety_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campaign_safety_settings_id_seq OWNED BY public.campaign_safety_settings.id;


--
-- Name: campaign_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign_targets (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    target_id integer NOT NULL,
    status public.campaigntargetstatus NOT NULL,
    attempts integer NOT NULL,
    last_attempt_at timestamp with time zone,
    completed_at timestamp with time zone,
    error_code character varying,
    error_message character varying,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    lease_token character varying(100),
    assigned_instance_id integer,
    provider_message_id character varying(255),
    next_attempt_at timestamp with time zone,
    delivery_status character varying(32),
    delivered_at timestamp with time zone,
    read_at timestamp with time zone
);


--
-- Name: campaign_targets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campaign_targets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campaign_targets_id_seq OWNED BY public.campaign_targets.id;


--
-- Name: campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaigns (
    id integer NOT NULL,
    name character varying NOT NULL,
    message_content character varying NOT NULL,
    status public.campaignstatus NOT NULL,
    scheduled_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    total_targets integer NOT NULL,
    success_count integer NOT NULL,
    failed_count integer NOT NULL,
    skipped_count integer NOT NULL,
    cancelled_count integer NOT NULL,
    source_campaign_id integer,
    user_id integer,
    whatsapp_instance_id integer,
    media_url character varying,
    media_type character varying,
    campaign_type character varying(32) DEFAULT 'GENERIC'::character varying NOT NULL
);


--
-- Name: campaigns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campaigns_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaigns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campaigns_id_seq OWNED BY public.campaigns.id;


--
-- Name: collection_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_targets (
    id integer NOT NULL,
    collection_id integer NOT NULL,
    target_id integer NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: collection_targets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.collection_targets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collection_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.collection_targets_id_seq OWNED BY public.collection_targets.id;


--
-- Name: collections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collections (
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    user_id integer,
    whatsapp_instance_id integer
);


--
-- Name: collections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.collections_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.collections_id_seq OWNED BY public.collections.id;


--
-- Name: component_health; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.component_health (
    id character varying NOT NULL,
    component_type character varying NOT NULL,
    last_heartbeat_at timestamp with time zone NOT NULL,
    status character varying NOT NULL
);


--
-- Name: contact_campaign_progress; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact_campaign_progress (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    contact_id integer NOT NULL,
    state character varying(50) DEFAULT 'NEW'::character varying NOT NULL,
    allocated_group_id integer,
    outreach_sent_at timestamp with time zone,
    replied_at timestamp with time zone,
    reply_text character varying,
    allocated_at timestamp with time zone,
    invite_sent_at timestamp with time zone,
    joined_at timestamp with time zone,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    opening_variant_id character varying(50),
    followup_stage integer DEFAULT 0 NOT NULL,
    last_outreach_at timestamp with time zone,
    next_followup_at timestamp with time zone,
    followup_stopped_at timestamp with time zone,
    followup_stop_reason character varying(50),
    last_followup_variant_id character varying(50),
    membership_check_count integer DEFAULT 0 NOT NULL,
    next_membership_check_at timestamp with time zone
);


--
-- Name: contact_campaign_progress_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contact_campaign_progress_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contact_campaign_progress_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contact_campaign_progress_id_seq OWNED BY public.contact_campaign_progress.id;


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    whatsapp_instance_id integer,
    provider character varying(50) DEFAULT 'evolution'::character varying NOT NULL,
    external_id character varying(255) NOT NULL,
    phone_number character varying(50),
    display_name character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    status character varying(50) DEFAULT 'active'::character varying NOT NULL,
    metadata jsonb,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contacts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contacts_id_seq OWNED BY public.contacts.id;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    whatsapp_instance_id integer,
    contact_id integer NOT NULL,
    provider character varying(50) DEFAULT 'evolution'::character varying NOT NULL,
    external_thread_id character varying(255),
    status character varying(50) DEFAULT 'ACTIVE'::character varying NOT NULL,
    unread_count integer DEFAULT 0 NOT NULL,
    last_message_at timestamp with time zone,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    conversation_mode character varying(50) DEFAULT 'AI_ACTIVE'::character varying NOT NULL,
    human_takeover_at timestamp with time zone
);


--
-- Name: conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conversations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conversations_id_seq OWNED BY public.conversations.id;


--
-- Name: daily_system_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_system_reports (
    id integer NOT NULL,
    report_date timestamp with time zone NOT NULL,
    report_type character varying(20) DEFAULT 'daily'::character varying NOT NULL,
    health_score integer DEFAULT 100 NOT NULL,
    status character varying(20) DEFAULT 'HEALTHY'::character varying NOT NULL,
    critical_count integer DEFAULT 0 NOT NULL,
    warning_count integer DEFAULT 0 NOT NULL,
    subject character varying(255) NOT NULL,
    summary_text text NOT NULL,
    html_content text NOT NULL,
    metrics_summary jsonb,
    email_sent boolean DEFAULT false NOT NULL,
    sent_at timestamp with time zone,
    error_message text
);


--
-- Name: daily_system_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.daily_system_reports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_system_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.daily_system_reports_id_seq OWNED BY public.daily_system_reports.id;


--
-- Name: dead_letter_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dead_letter_targets (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    campaign_target_id integer NOT NULL,
    target_id integer NOT NULL,
    user_id integer,
    attempts integer DEFAULT 0 NOT NULL,
    error_code character varying(100),
    error_message text,
    last_error_details jsonb,
    redriven_at timestamp with time zone,
    redrive_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: dead_letter_targets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dead_letter_targets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dead_letter_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dead_letter_targets_id_seq OWNED BY public.dead_letter_targets.id;


--
-- Name: delivery_idempotency; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_idempotency (
    id integer NOT NULL,
    idempotency_key character varying(255) NOT NULL,
    campaign_id integer NOT NULL,
    campaign_target_id integer NOT NULL,
    target_id integer NOT NULL,
    user_id integer,
    status character varying(50) DEFAULT 'RESERVED'::character varying NOT NULL,
    attempt integer DEFAULT 1 NOT NULL,
    external_reference character varying(255),
    error_code character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: delivery_idempotency_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.delivery_idempotency_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delivery_idempotency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.delivery_idempotency_id_seq OWNED BY public.delivery_idempotency.id;


--
-- Name: execution_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.execution_logs (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    campaign_target_id integer NOT NULL,
    action character varying NOT NULL,
    result public.executionresultstatus NOT NULL,
    error_code character varying,
    error_message character varying,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: execution_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.execution_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: execution_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.execution_logs_id_seq OWNED BY public.execution_logs.id;


--
-- Name: group_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_invitations (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    campaign_group_id integer NOT NULL,
    contact_id integer NOT NULL,
    invite_link character varying(500) NOT NULL,
    status character varying(50) DEFAULT 'RESERVED'::character varying NOT NULL,
    provider_message_id character varying(255),
    sent_at timestamp with time zone,
    joined_at timestamp with time zone,
    idempotency_key character varying(255) NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: group_invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_invitations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_invitations_id_seq OWNED BY public.group_invitations.id;


--
-- Name: hotspot_user_telemetry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hotspot_user_telemetry (
    id bigint NOT NULL,
    router_id character varying(64) NOT NULL,
    user_name character varying(128) NOT NULL,
    profile character varying(64),
    comment text,
    is_active boolean DEFAULT false NOT NULL,
    active_connections_count integer DEFAULT 0 NOT NULL,
    ip_address inet,
    mac_address macaddr,
    session_uptime character varying(32),
    bytes_in bigint DEFAULT 0 NOT NULL,
    bytes_out bigint DEFAULT 0 NOT NULL,
    total_bytes bigint DEFAULT 0 NOT NULL,
    limit_bytes_total bigint DEFAULT 0 NOT NULL,
    remaining_bytes bigint DEFAULT 0 NOT NULL,
    total_mb numeric(12,2) DEFAULT 0 NOT NULL,
    total_gb numeric(12,2) DEFAULT 0 NOT NULL,
    limit_gb numeric(12,2),
    remaining_gb numeric(12,2),
    used_percentage numeric(5,2) DEFAULT 0 NOT NULL,
    alert_tier character varying(16) DEFAULT 'NORMAL'::character varying NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hotspot_user_telemetry_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hotspot_user_telemetry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hotspot_user_telemetry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hotspot_user_telemetry_id_seq OWNED BY public.hotspot_user_telemetry.id;


--
-- Name: instance_pacing_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.instance_pacing_states (
    id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    state character varying NOT NULL,
    entered_at timestamp with time zone NOT NULL,
    reason character varying,
    failure_pressure double precision NOT NULL,
    retry_pressure double precision NOT NULL,
    vg_pressure double precision NOT NULL,
    consecutive_successes integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: instance_pacing_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.instance_pacing_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_pacing_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.instance_pacing_states_id_seq OWNED BY public.instance_pacing_states.id;


--
-- Name: instance_pacing_transitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.instance_pacing_transitions (
    id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    old_state character varying NOT NULL,
    new_state character varying NOT NULL,
    reason character varying,
    failure_pressure double precision NOT NULL,
    retry_pressure double precision NOT NULL,
    vg_pressure double precision NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: instance_pacing_transitions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.instance_pacing_transitions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_pacing_transitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.instance_pacing_transitions_id_seq OWNED BY public.instance_pacing_transitions.id;


--
-- Name: instance_rebalance_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.instance_rebalance_states (
    id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    state character varying(32) DEFAULT 'HEALTHY'::character varying NOT NULL,
    failure_code character varying(100),
    quarantined_at timestamp with time zone,
    cooldown_until timestamp with time zone,
    rebalance_generation integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: instance_rebalance_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.instance_rebalance_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_rebalance_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.instance_rebalance_states_id_seq OWNED BY public.instance_rebalance_states.id;


--
-- Name: instance_risk_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.instance_risk_profiles (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    risk_state character varying(32) DEFAULT 'NORMAL'::character varying NOT NULL,
    risk_score double precision DEFAULT '0'::double precision NOT NULL,
    outbound_1h integer DEFAULT 0 NOT NULL,
    outbound_24h integer DEFAULT 0 NOT NULL,
    unique_recipients_24h integer DEFAULT 0 NOT NULL,
    unique_groups_24h integer DEFAULT 0 NOT NULL,
    reply_rate double precision DEFAULT '0'::double precision NOT NULL,
    delivery_failure_rate double precision DEFAULT '0'::double precision NOT NULL,
    opt_out_rate double precision DEFAULT '0'::double precision NOT NULL,
    negative_signal_rate double precision DEFAULT '0'::double precision NOT NULL,
    consecutive_failures integer DEFAULT 0 NOT NULL,
    health_score double precision DEFAULT '100'::double precision NOT NULL,
    last_risk_event_at timestamp with time zone,
    last_evaluated_at timestamp with time zone,
    risk_version integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: instance_risk_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.instance_risk_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_risk_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.instance_risk_profiles_id_seq OWNED BY public.instance_risk_profiles.id;


--
-- Name: instance_state_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.instance_state_audit_events (
    id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    user_id integer,
    previous_state character varying(32) NOT NULL,
    new_state character varying(32) NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    reason_code character varying(200) NOT NULL,
    signal_category character varying(64) NOT NULL,
    consecutive_failures integer,
    cooldown_depth_seconds double precision,
    pacing_state_at_transition character varying(32),
    metadata_json jsonb
);


--
-- Name: instance_state_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.instance_state_audit_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_state_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.instance_state_audit_events_id_seq OWNED BY public.instance_state_audit_events.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    user_id integer NOT NULL,
    whatsapp_instance_id integer,
    conversation_id integer NOT NULL,
    contact_id integer NOT NULL,
    provider character varying(50) DEFAULT 'evolution'::character varying NOT NULL,
    external_message_id character varying(255),
    client_message_key character varying(255),
    direction character varying(50) NOT NULL,
    message_type character varying(50) DEFAULT 'TEXT'::character varying NOT NULL,
    body text NOT NULL,
    status character varying(50) DEFAULT 'PENDING'::character varying NOT NULL,
    error_code character varying(100),
    error_message text,
    provider_timestamp timestamp with time zone,
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    read_at timestamp with time zone,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: mikrotik_wan_quality; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mikrotik_wan_quality (
    id bigint NOT NULL,
    router_id character varying(64) NOT NULL,
    interface_name character varying(32) NOT NULL,
    target_host character varying(64) DEFAULT '8.8.8.8'::character varying NOT NULL,
    latency_ms numeric(6,2) DEFAULT 0.00 NOT NULL,
    min_latency_ms numeric(6,2),
    max_latency_ms numeric(6,2),
    packet_loss_percent numeric(5,2) DEFAULT 0.00 NOT NULL,
    jitter_ms numeric(6,2) DEFAULT 0.00,
    status character varying(16) DEFAULT 'HEALTHY'::character varying NOT NULL,
    probed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mikrotik_wan_quality_status_check CHECK (((status)::text = ANY ((ARRAY['HEALTHY'::character varying, 'DEGRADED'::character varying, 'DOWN'::character varying])::text[])))
);


--
-- Name: mikrotik_wan_quality_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mikrotik_wan_quality_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mikrotik_wan_quality_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mikrotik_wan_quality_id_seq OWNED BY public.mikrotik_wan_quality.id;


--
-- Name: mikrotik_wan_quotas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mikrotik_wan_quotas (
    id integer NOT NULL,
    router_id character varying(64) NOT NULL,
    interface_name character varying(16) NOT NULL,
    provider_name character varying(64),
    quota_gb numeric(10,2) NOT NULL,
    renewal_day integer NOT NULL,
    alert_threshold_percent integer DEFAULT 80,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    landline_number character varying(32),
    account_holder character varying(128),
    support_email character varying(128),
    CONSTRAINT mikrotik_wan_quotas_renewal_day_check CHECK (((renewal_day >= 1) AND (renewal_day <= 31)))
);


--
-- Name: mikrotik_wan_quotas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mikrotik_wan_quotas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mikrotik_wan_quotas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mikrotik_wan_quotas_id_seq OWNED BY public.mikrotik_wan_quotas.id;


--
-- Name: mikrotik_wan_readings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mikrotik_wan_readings (
    id bigint NOT NULL,
    router_id text NOT NULL,
    uptime text,
    wan1_rx bigint NOT NULL,
    wan1_tx bigint NOT NULL,
    wan2_rx bigint NOT NULL,
    wan2_tx bigint NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mikrotik_wan_readings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mikrotik_wan_readings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mikrotik_wan_readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mikrotik_wan_readings_id_seq OWNED BY public.mikrotik_wan_readings.id;


--
-- Name: mikrotik_wan_usage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mikrotik_wan_usage (
    id bigint NOT NULL,
    router_id text NOT NULL,
    reading_id bigint,
    wan1_rx_bytes bigint DEFAULT 0 NOT NULL,
    wan1_tx_bytes bigint DEFAULT 0 NOT NULL,
    wan2_rx_bytes bigint DEFAULT 0 NOT NULL,
    wan2_tx_bytes bigint DEFAULT 0 NOT NULL,
    total_bytes bigint DEFAULT 0 NOT NULL,
    counter_reset boolean DEFAULT false NOT NULL,
    usage_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mikrotik_wan_usage_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mikrotik_wan_usage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mikrotik_wan_usage_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mikrotik_wan_usage_id_seq OWNED BY public.mikrotik_wan_usage.id;


--
-- Name: quota_alert_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quota_alert_state (
    router_id character varying(64) NOT NULL,
    interface_name character varying(16) NOT NULL,
    cycle_start date NOT NULL,
    alerted_80 boolean DEFAULT false,
    alerted_95 boolean DEFAULT false,
    last_alert_at timestamp with time zone DEFAULT now()
);


--
-- Name: quota_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quota_allocations (
    id bigint NOT NULL,
    billing_cycle_id bigint,
    router_id character varying(64) NOT NULL,
    interface_name character varying(32) NOT NULL,
    type character varying(16) NOT NULL,
    amount_gb numeric(10,2) NOT NULL,
    effective_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by character varying(64) DEFAULT 'system'::character varying NOT NULL,
    reference character varying(128),
    metadata jsonb DEFAULT '{}'::jsonb,
    CONSTRAINT quota_allocations_amount_gb_check CHECK ((amount_gb > (0)::numeric)),
    CONSTRAINT quota_allocations_type_check CHECK (((type)::text = ANY ((ARRAY['BASE'::character varying, 'ADDON'::character varying])::text[])))
);


--
-- Name: quota_allocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quota_allocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quota_allocations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quota_allocations_id_seq OWNED BY public.quota_allocations.id;


--
-- Name: quota_day_weights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quota_day_weights (
    day_of_week integer NOT NULL,
    day_name character varying(16) NOT NULL,
    weight_multiplier numeric(4,2) DEFAULT 1.00 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT quota_day_weights_day_of_week_check CHECK (((day_of_week >= 1) AND (day_of_week <= 7))),
    CONSTRAINT quota_day_weights_weight_multiplier_check CHECK ((weight_multiplier > (0)::numeric))
);


--
-- Name: quota_reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quota_reservations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    campaign_id integer NOT NULL,
    reserved_messages integer NOT NULL,
    consumed_messages integer DEFAULT 0 NOT NULL,
    released_messages integer DEFAULT 0 NOT NULL,
    status character varying(50) DEFAULT 'RESERVED'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: quota_reservations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quota_reservations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quota_reservations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quota_reservations_id_seq OWNED BY public.quota_reservations.id;


--
-- Name: recipient_risk_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recipient_risk_profiles (
    id integer NOT NULL,
    user_id integer NOT NULL,
    instance_id integer,
    recipient_jid character varying(255) NOT NULL,
    recipient_type character varying(32) DEFAULT 'PHONE'::character varying NOT NULL,
    risk_state character varying(32) DEFAULT 'UNKNOWN'::character varying NOT NULL,
    last_inbound_at timestamp with time zone,
    last_outbound_at timestamp with time zone,
    messages_sent_24h integer DEFAULT 0 NOT NULL,
    messages_received_24h integer DEFAULT 0 NOT NULL,
    reply_count_7d integer DEFAULT 0 NOT NULL,
    block_count integer DEFAULT 0 NOT NULL,
    opt_out_count integer DEFAULT 0 NOT NULL,
    delivery_failures_24h integer DEFAULT 0 NOT NULL,
    negative_signal_count integer DEFAULT 0 NOT NULL,
    consent_status character varying(32) DEFAULT 'UNKNOWN'::character varying NOT NULL,
    consent_source character varying(100),
    consent_at timestamp with time zone,
    risk_score double precision DEFAULT '0'::double precision NOT NULL,
    risk_version integer DEFAULT 1 NOT NULL,
    last_evaluated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: recipient_risk_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recipient_risk_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recipient_risk_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recipient_risk_profiles_id_seq OWNED BY public.recipient_risk_profiles.id;


--
-- Name: refresh_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refresh_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token_hash character varying(64) NOT NULL,
    family_id character varying(64) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    rotated_at timestamp with time zone,
    replaced_by_id integer,
    last_used_at timestamp with time zone
);


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.refresh_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.refresh_tokens_id_seq OWNED BY public.refresh_tokens.id;


--
-- Name: risk_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.risk_decisions (
    id integer NOT NULL,
    user_id integer,
    instance_id integer,
    campaign_id integer,
    campaign_target_id integer,
    recipient_jid character varying(255) NOT NULL,
    recipient_type character varying(32) DEFAULT 'PHONE'::character varying NOT NULL,
    decision character varying(32) NOT NULL,
    reason_codes jsonb NOT NULL,
    risk_score double precision DEFAULT '0'::double precision NOT NULL,
    account_state character varying(32) NOT NULL,
    recipient_state character varying(32) NOT NULL,
    enforced boolean DEFAULT false NOT NULL,
    policy_version character varying(32) DEFAULT 'risk-r1'::character varying NOT NULL,
    evaluation_context jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: risk_decisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.risk_decisions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_decisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.risk_decisions_id_seq OWNED BY public.risk_decisions.id;


--
-- Name: risk_signals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.risk_signals (
    id integer NOT NULL,
    user_id integer,
    instance_id integer,
    recipient_jid character varying(255) NOT NULL,
    recipient_type character varying(32) DEFAULT 'PHONE'::character varying NOT NULL,
    signal_type character varying(64) NOT NULL,
    source character varying(64) DEFAULT 'WCCP_WORKER'::character varying NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: risk_signals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.risk_signals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_signals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.risk_signals_id_seq OWNED BY public.risk_signals.id;


--
-- Name: risk_state_transitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.risk_state_transitions (
    id integer NOT NULL,
    scope character varying(32) NOT NULL,
    instance_id integer,
    recipient_jid character varying(255),
    previous_state character varying(32) NOT NULL,
    new_state character varying(32) NOT NULL,
    previous_score double precision DEFAULT '0'::double precision NOT NULL,
    new_score double precision DEFAULT '0'::double precision NOT NULL,
    reason_codes jsonb NOT NULL,
    risk_version integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: risk_state_transitions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.risk_state_transitions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_state_transitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.risk_state_transitions_id_seq OWNED BY public.risk_state_transitions.id;


--
-- Name: router_heartbeat_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.router_heartbeat_state (
    id integer NOT NULL,
    router_id character varying(64) NOT NULL,
    is_offline boolean DEFAULT false NOT NULL,
    last_seen_at timestamp with time zone,
    last_alert_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: router_heartbeat_state_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.router_heartbeat_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: router_heartbeat_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.router_heartbeat_state_id_seq OWNED BY public.router_heartbeat_state.id;


--
-- Name: subscription_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_events (
    id integer NOT NULL,
    user_id integer NOT NULL,
    old_tier character varying(50),
    new_tier character varying(50) NOT NULL,
    old_status character varying(50),
    new_status character varying(50) NOT NULL,
    duration_days integer,
    source character varying(50) DEFAULT 'SYSTEM'::character varying NOT NULL,
    admin_telegram_id bigint,
    metadata json,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: subscription_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subscription_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscription_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subscription_events_id_seq OWNED BY public.subscription_events.id;


--
-- Name: subscription_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_payments (
    id integer NOT NULL,
    user_id integer NOT NULL,
    tier character varying(50) NOT NULL,
    amount_usd double precision NOT NULL,
    currency character varying(10) DEFAULT 'USD'::character varying NOT NULL,
    payment_method character varying(50) NOT NULL,
    receipt_file_id character varying(255),
    receipt_caption character varying(1000),
    status character varying(50) DEFAULT 'PENDING'::character varying NOT NULL,
    reviewed_by_admin_id bigint,
    reviewed_at timestamp with time zone,
    rejection_reason character varying(500),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: subscription_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subscription_payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscription_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subscription_payments_id_seq OWNED BY public.subscription_payments.id;


--
-- Name: system_metric_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_metric_snapshots (
    id integer NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    ram_total_mb double precision DEFAULT '0'::double precision NOT NULL,
    ram_used_mb double precision DEFAULT '0'::double precision NOT NULL,
    ram_available_mb double precision DEFAULT '0'::double precision NOT NULL,
    ram_used_percent double precision DEFAULT '0'::double precision NOT NULL,
    swap_total_mb double precision DEFAULT '0'::double precision NOT NULL,
    swap_used_mb double precision DEFAULT '0'::double precision NOT NULL,
    load_1m double precision DEFAULT '0'::double precision NOT NULL,
    load_5m double precision DEFAULT '0'::double precision NOT NULL,
    load_15m double precision DEFAULT '0'::double precision NOT NULL,
    cpu_count integer DEFAULT 4 NOT NULL,
    disk_total_gb double precision DEFAULT '0'::double precision NOT NULL,
    disk_used_gb double precision DEFAULT '0'::double precision NOT NULL,
    disk_available_gb double precision DEFAULT '0'::double precision NOT NULL,
    disk_used_percent double precision DEFAULT '0'::double precision NOT NULL,
    evolution_ram_mb double precision DEFAULT '0'::double precision NOT NULL,
    evolution_cpu_percent double precision DEFAULT '0'::double precision NOT NULL,
    evolution_restart_count integer DEFAULT 0 NOT NULL,
    evolution_status character varying(50) DEFAULT 'unknown'::character varying NOT NULL,
    postgres_ram_mb double precision DEFAULT '0'::double precision NOT NULL,
    postgres_cpu_percent double precision DEFAULT '0'::double precision NOT NULL,
    redis_used_memory_mb double precision DEFAULT '0'::double precision NOT NULL,
    redis_maxmemory_mb double precision DEFAULT '0'::double precision NOT NULL,
    redis_utilization_percent double precision DEFAULT '0'::double precision NOT NULL,
    redis_connected_clients integer DEFAULT 0 NOT NULL,
    redis_evicted_keys_total integer DEFAULT 0 NOT NULL,
    redis_expired_keys_total integer DEFAULT 0 NOT NULL,
    redis_fragmentation_ratio double precision DEFAULT '0'::double precision NOT NULL,
    redis_keys_count integer DEFAULT 0 NOT NULL,
    db_active_connections integer DEFAULT 0 NOT NULL,
    db_idle_connections integer DEFAULT 0 NOT NULL,
    db_idle_in_transaction integer DEFAULT 0 NOT NULL,
    db_long_running_queries integer DEFAULT 0 NOT NULL,
    db_size_mb double precision DEFAULT '0'::double precision NOT NULL,
    db_message_table_size_mb double precision DEFAULT '0'::double precision NOT NULL,
    db_message_row_estimate integer DEFAULT 0 NOT NULL,
    db_critical_index_present boolean DEFAULT true NOT NULL,
    metadata_json jsonb
);


--
-- Name: system_metric_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_metric_snapshots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_metric_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.system_metric_snapshots_id_seq OWNED BY public.system_metric_snapshots.id;


--
-- Name: targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.targets (
    id integer NOT NULL,
    external_id character varying NOT NULL,
    name character varying,
    enabled boolean NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    user_id integer,
    whatsapp_instance_id integer
);


--
-- Name: targets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.targets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.targets_id_seq OWNED BY public.targets.id;


--
-- Name: templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates (
    id integer NOT NULL,
    name character varying NOT NULL,
    content character varying NOT NULL,
    enabled boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.templates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.templates_id_seq OWNED BY public.templates.id;


--
-- Name: usage_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_events (
    id integer NOT NULL,
    user_id integer NOT NULL,
    campaign_id integer NOT NULL,
    delivery_id character varying(255) NOT NULL,
    message_count integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: usage_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usage_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usage_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usage_events_id_seq OWNED BY public.usage_events.id;


--
-- Name: user_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_subscriptions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    tier character varying(50) DEFAULT 'FREE'::character varying NOT NULL,
    status character varying(50) DEFAULT 'ACTIVE'::character varying NOT NULL,
    starts_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    auto_renew boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_subscriptions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_subscriptions_id_seq OWNED BY public.user_subscriptions.id;


--
-- Name: user_usage_daily; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_usage_daily (
    id integer NOT NULL,
    user_id integer NOT NULL,
    usage_date date NOT NULL,
    messages_sent integer DEFAULT 0 NOT NULL,
    campaigns_created integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_usage_daily_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_usage_daily_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_usage_daily_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_usage_daily_id_seq OWNED BY public.user_usage_daily.id;


--
-- Name: user_usage_monthly; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_usage_monthly (
    id integer NOT NULL,
    user_id integer NOT NULL,
    usage_month character varying(7) NOT NULL,
    messages_sent integer DEFAULT 0 NOT NULL,
    campaigns_created integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_usage_monthly_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_usage_monthly_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_usage_monthly_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_usage_monthly_id_seq OWNED BY public.user_usage_monthly.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    telegram_user_id bigint NOT NULL,
    username character varying,
    display_name character varying,
    is_active boolean DEFAULT true NOT NULL,
    safety_notice_accepted boolean DEFAULT false NOT NULL,
    safety_notice_accepted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    language character varying(10) DEFAULT 'ar'::character varying NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: view_hotspot_daily_user_usage; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_hotspot_daily_user_usage AS
 WITH ordered_readings AS (
         SELECT hotspot_user_telemetry.id,
            hotspot_user_telemetry.router_id,
            hotspot_user_telemetry.user_name,
            hotspot_user_telemetry.total_bytes,
            hotspot_user_telemetry.used_percentage,
            hotspot_user_telemetry.recorded_at,
            ((hotspot_user_telemetry.recorded_at AT TIME ZONE 'Africa/Cairo'::text))::date AS usage_date,
            lag(hotspot_user_telemetry.total_bytes) OVER (PARTITION BY hotspot_user_telemetry.router_id, hotspot_user_telemetry.user_name ORDER BY hotspot_user_telemetry.recorded_at) AS prev_bytes,
            lag(((hotspot_user_telemetry.recorded_at AT TIME ZONE 'Africa/Cairo'::text))::date) OVER (PARTITION BY hotspot_user_telemetry.router_id, hotspot_user_telemetry.user_name ORDER BY hotspot_user_telemetry.recorded_at) AS prev_date
           FROM public.hotspot_user_telemetry
        ), calculated_deltas AS (
         SELECT ordered_readings.router_id,
            ordered_readings.user_name,
            ordered_readings.usage_date,
            ordered_readings.total_bytes,
            ordered_readings.used_percentage,
            ordered_readings.recorded_at,
                CASE
                    WHEN (ordered_readings.prev_bytes IS NULL) THEN (0)::bigint
                    WHEN (ordered_readings.prev_date < ordered_readings.usage_date) THEN (0)::bigint
                    WHEN (ordered_readings.total_bytes >= ordered_readings.prev_bytes) THEN (ordered_readings.total_bytes - ordered_readings.prev_bytes)
                    ELSE ordered_readings.total_bytes
                END AS delta_bytes,
                CASE
                    WHEN ((ordered_readings.prev_bytes IS NOT NULL) AND (ordered_readings.total_bytes < ordered_readings.prev_bytes)) THEN true
                    ELSE false
                END AS is_reboot_reset
           FROM ordered_readings
        )
 SELECT router_id,
    user_name,
    usage_date,
    round((sum(delta_bytes) / (1024.0 * 1024.0)), 2) AS consumed_today_mb,
    round((sum(delta_bytes) / ((1024.0 * 1024.0) * 1024.0)), 2) AS consumed_today_gb,
    max(used_percentage) AS peak_used_percentage,
    count(*) AS samples_count,
    bool_or(is_reboot_reset) AS had_reboot_or_reset,
    min(recorded_at) AS first_sample_at,
    max(recorded_at) AS last_sample_at
   FROM calculated_deltas
  GROUP BY router_id, user_name, usage_date
  ORDER BY usage_date DESC, (round((sum(delta_bytes) / ((1024.0 * 1024.0) * 1024.0)), 2)) DESC;


--
-- Name: view_mikrotik_wan_daily_usage; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_mikrotik_wan_daily_usage AS
 SELECT router_id,
    ((usage_at AT TIME ZONE 'Africa/Cairo'::text))::date AS usage_date,
    round((sum((wan1_rx_bytes + wan1_tx_bytes)) / (1024.0 * 1024.0)), 2) AS wan1_total_mb,
    round((sum((wan1_rx_bytes + wan1_tx_bytes)) / ((1024.0 * 1024.0) * 1024.0)), 2) AS wan1_total_gb,
    round((sum((wan2_rx_bytes + wan2_tx_bytes)) / (1024.0 * 1024.0)), 2) AS wan2_total_mb,
    round((sum((wan2_rx_bytes + wan2_tx_bytes)) / ((1024.0 * 1024.0) * 1024.0)), 2) AS wan2_total_gb,
    round((sum(total_bytes) / (1024.0 * 1024.0)), 2) AS grand_total_mb,
    round((sum(total_bytes) / ((1024.0 * 1024.0) * 1024.0)), 2) AS grand_total_gb,
    count(*) AS readings_count
   FROM public.mikrotik_wan_usage
  WHERE (counter_reset = false)
  GROUP BY router_id, (((usage_at AT TIME ZONE 'Africa/Cairo'::text))::date)
  ORDER BY (((usage_at AT TIME ZONE 'Africa/Cairo'::text))::date) DESC;


--
-- Name: view_mikrotik_wan_latest_quality; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_mikrotik_wan_latest_quality AS
 SELECT DISTINCT ON (router_id, interface_name) router_id,
    interface_name,
    target_host,
    latency_ms,
    packet_loss_percent,
    jitter_ms,
    status,
    probed_at
   FROM public.mikrotik_wan_quality
  ORDER BY router_id, interface_name, probed_at DESC;


--
-- Name: view_mikrotik_wan_monthly_usage; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_mikrotik_wan_monthly_usage AS
 SELECT router_id,
    to_char((usage_at AT TIME ZONE 'Africa/Cairo'::text), 'YYYY-MM'::text) AS usage_month,
    sum(wan1_rx_bytes) AS wan1_rx_bytes,
    sum(wan1_tx_bytes) AS wan1_tx_bytes,
    sum((wan1_rx_bytes + wan1_tx_bytes)) AS wan1_total_bytes,
    round((((sum((wan1_rx_bytes + wan1_tx_bytes)) / (1024)::numeric) / (1024)::numeric) / (1024)::numeric), 2) AS wan1_total_gb,
    sum(wan2_rx_bytes) AS wan2_rx_bytes,
    sum(wan2_tx_bytes) AS wan2_tx_bytes,
    sum((wan2_rx_bytes + wan2_tx_bytes)) AS wan2_total_bytes,
    round((((sum((wan2_rx_bytes + wan2_tx_bytes)) / (1024)::numeric) / (1024)::numeric) / (1024)::numeric), 2) AS wan2_total_gb,
    sum(total_bytes) AS grand_total_bytes,
    round((((sum(total_bytes) / (1024)::numeric) / (1024)::numeric) / (1024)::numeric), 2) AS grand_total_gb,
    count(*) AS total_readings,
    count(DISTINCT date((usage_at AT TIME ZONE 'Africa/Cairo'::text))) AS active_days
   FROM public.mikrotik_wan_usage
  GROUP BY router_id, (to_char((usage_at AT TIME ZONE 'Africa/Cairo'::text), 'YYYY-MM'::text))
  ORDER BY (to_char((usage_at AT TIME ZONE 'Africa/Cairo'::text), 'YYYY-MM'::text)) DESC;


--
-- Name: wan_operational_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wan_operational_state (
    id integer NOT NULL,
    router_id character varying(64) NOT NULL,
    interface_name character varying(32) NOT NULL,
    current_state character varying(24) DEFAULT 'NORMAL'::character varying NOT NULL,
    previous_state character varying(24),
    reason text,
    state_changed_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    CONSTRAINT wan_operational_state_current_state_check CHECK (((current_state)::text = ANY ((ARRAY['NORMAL'::character varying, 'ISOLATION_REQUESTED'::character varying, 'ISOLATED'::character varying, 'ISOLATION_FAILED'::character varying, 'RESTORATION_REQUESTED'::character varying, 'THROTTLED'::character varying, 'RECOVERED'::character varying])::text[])))
);


--
-- Name: view_mikrotik_wan_quota_status; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_mikrotik_wan_quota_status AS
 WITH current_cairo_time AS (
         SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo'::text) AS cairo_now,
            ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo'::text))::date AS today_date,
            (EXTRACT(year FROM (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo'::text)))::integer AS current_year,
            (EXTRACT(month FROM (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo'::text)))::integer AS current_month,
            (EXTRACT(day FROM (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo'::text)))::integer AS current_day
        ), deterministic_boundaries AS (
         SELECT q.router_id,
            q.interface_name,
            q.provider_name,
            q.quota_gb AS config_base_quota_gb,
            q.renewal_day,
            q.alert_threshold_percent,
            t.today_date,
            t.cairo_now,
                CASE
                    WHEN (t.current_day >= q.renewal_day) THEN public.calculate_cycle_boundary_date(t.current_year, t.current_month, q.renewal_day)
                    ELSE public.calculate_cycle_boundary_date((EXTRACT(year FROM (make_date(t.current_year, t.current_month, 1) - '1 mon'::interval)))::integer, (EXTRACT(month FROM (make_date(t.current_year, t.current_month, 1) - '1 mon'::interval)))::integer, q.renewal_day)
                END AS cycle_start,
                CASE
                    WHEN (t.current_day >= q.renewal_day) THEN public.calculate_cycle_boundary_date((EXTRACT(year FROM (make_date(t.current_year, t.current_month, 1) + '1 mon'::interval)))::integer, (EXTRACT(month FROM (make_date(t.current_year, t.current_month, 1) + '1 mon'::interval)))::integer, q.renewal_day)
                    ELSE public.calculate_cycle_boundary_date(t.current_year, t.current_month, q.renewal_day)
                END AS renewal_date
           FROM (public.mikrotik_wan_quotas q
             CROSS JOIN current_cairo_time t)
          WHERE (q.is_active = true)
        ), active_cycles_resolved AS (
         SELECT b.router_id,
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
            COALESCE(bc.status, 'ACTIVE'::character varying) AS cycle_status,
            COALESCE(bc.base_quota_gb, b.config_base_quota_gb) AS base_quota_gb,
            COALESCE(bc.initial_offset_gb, 0.00) AS initial_offset_gb
           FROM (deterministic_boundaries b
             LEFT JOIN public.billing_cycles bc ON ((((bc.router_id)::text = (b.router_id)::text) AND (lower((bc.interface_name)::text) = lower((b.interface_name)::text)) AND (bc.cycle_start = b.cycle_start))))
        ), addon_allocations_sum AS (
         SELECT ac.router_id,
            ac.interface_name,
            COALESCE(sum(qa.amount_gb), 0.00) AS addon_quota_gb
           FROM (active_cycles_resolved ac
             LEFT JOIN public.quota_allocations qa ON (((((qa.billing_cycle_id IS NOT NULL) AND (qa.billing_cycle_id = ac.billing_cycle_id)) OR ((qa.billing_cycle_id IS NULL) AND ((qa.router_id)::text = (ac.router_id)::text) AND (lower((qa.interface_name)::text) = lower((ac.interface_name)::text)) AND (((qa.effective_at AT TIME ZONE 'Africa/Cairo'::text))::date >= ac.cycle_start) AND (((qa.effective_at AT TIME ZONE 'Africa/Cairo'::text))::date < ac.renewal_date))) AND ((qa.type)::text = 'ADDON'::text) AND (qa.effective_at <= ac.cairo_now) AND ((qa.expires_at IS NULL) OR (qa.expires_at > ac.cairo_now)))))
          GROUP BY ac.router_id, ac.interface_name
        ), usage_per_cycle AS (
         SELECT ac.router_id,
            ac.interface_name,
            ac.provider_name,
            ac.renewal_day,
            ac.alert_threshold_percent,
            ac.cycle_start,
            ac.renewal_date,
            (ac.renewal_date - ac.today_date) AS days_left,
            ac.cycle_status,
            ac.base_quota_gb,
            COALESCE(ads.addon_quota_gb, 0.00) AS addon_quota_gb,
            (ac.base_quota_gb + COALESCE(ads.addon_quota_gb, 0.00)) AS total_quota_gb,
            COALESCE(sum(
                CASE
                    WHEN (lower((ac.interface_name)::text) = 'wan1'::text) THEN (u.wan1_rx_bytes + u.wan1_tx_bytes)
                    WHEN (lower((ac.interface_name)::text) = 'wan2'::text) THEN (u.wan2_rx_bytes + u.wan2_tx_bytes)
                    ELSE (0)::bigint
                END), (0)::numeric) AS total_used_bytes,
            ac.initial_offset_gb,
            ac.today_date
           FROM ((active_cycles_resolved ac
             LEFT JOIN addon_allocations_sum ads ON ((((ads.router_id)::text = (ac.router_id)::text) AND (lower((ads.interface_name)::text) = lower((ac.interface_name)::text)))))
             LEFT JOIN public.mikrotik_wan_usage u ON (((u.router_id = (ac.router_id)::text) AND ((u.usage_at AT TIME ZONE 'Africa/Cairo'::text) >= (ac.cycle_start)::timestamp without time zone) AND ((u.usage_at AT TIME ZONE 'Africa/Cairo'::text) < (ac.renewal_date)::timestamp without time zone) AND (u.counter_reset = false))))
          GROUP BY ac.router_id, ac.interface_name, ac.provider_name, ac.renewal_day, ac.alert_threshold_percent, ac.cycle_start, ac.renewal_date, ac.today_date, ac.cycle_status, ac.base_quota_gb, ads.addon_quota_gb, ac.initial_offset_gb
        ), calculated_metrics AS (
         SELECT u.router_id,
            u.interface_name,
            u.provider_name,
            u.renewal_day,
            u.alert_threshold_percent,
            u.cycle_start,
            u.renewal_date,
            u.days_left,
            u.cycle_status,
            u.base_quota_gb,
            u.addon_quota_gb,
            u.total_quota_gb,
            u.total_used_bytes,
            u.initial_offset_gb,
            u.today_date,
            round(GREATEST((0)::numeric, ((u.total_used_bytes / ((1024.0 * 1024.0) * 1024.0)) + u.initial_offset_gb)), 2) AS used_gb_val,
            round(GREATEST((0)::numeric, (u.total_quota_gb - GREATEST((0)::numeric, ((u.total_used_bytes / ((1024.0 * 1024.0) * 1024.0)) + u.initial_offset_gb)))), 2) AS remaining_gb_val,
            public.calculate_adaptive_burn_rate(u.router_id, u.interface_name, u.cycle_start, u.today_date, u.total_used_bytes, u.base_quota_gb) AS daily_burn_rate_gb_val,
            COALESCE(wos.current_state, 'NORMAL'::character varying) AS operational_state,
            wos.reason AS operational_state_reason,
            wos.state_changed_at AS operational_state_changed_at
           FROM (usage_per_cycle u
             LEFT JOIN public.wan_operational_state wos ON ((((wos.router_id)::text = (u.router_id)::text) AND (lower((wos.interface_name)::text) = lower((u.interface_name)::text)))))
        )
 SELECT router_id,
    interface_name,
    provider_name,
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
    round(LEAST(100.0, ((used_gb_val / NULLIF(total_quota_gb, (0)::numeric)) * 100.0)), 1) AS used_percentage,
    alert_threshold_percent,
    daily_burn_rate_gb_val AS daily_burn_rate_gb,
        CASE
            WHEN (remaining_gb_val <= (0)::numeric) THEN today_date
            WHEN (daily_burn_rate_gb_val > (0)::numeric) THEN ((today_date + ((floor((remaining_gb_val / daily_burn_rate_gb_val)) || ' days'::text))::interval))::date
            ELSE renewal_date
        END AS projected_exhaustion_date,
        CASE
            WHEN (daily_burn_rate_gb_val > (0)::numeric) THEN (floor((remaining_gb_val / daily_burn_rate_gb_val)))::integer
            ELSE days_left
        END AS days_until_exhaustion,
        CASE
            WHEN (remaining_gb_val <= (0)::numeric) THEN true
            WHEN ((daily_burn_rate_gb_val > (0)::numeric) AND (((today_date + ((floor((remaining_gb_val / daily_burn_rate_gb_val)) || ' days'::text))::interval))::date < renewal_date)) THEN true
            ELSE false
        END AS will_exhaust_before_renewal,
    operational_state,
    operational_state_reason,
    operational_state_changed_at
   FROM calculated_metrics;


--
-- Name: wan_control_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wan_control_actions (
    id bigint NOT NULL,
    idempotency_key character varying(128) NOT NULL,
    router_id character varying(64) NOT NULL,
    interface_name character varying(32) NOT NULL,
    action_type character varying(32) NOT NULL,
    target_state character varying(24) NOT NULL,
    status character varying(24) DEFAULT 'PENDING'::character varying NOT NULL,
    requested_by character varying(64) DEFAULT 'system'::character varying NOT NULL,
    reason text,
    execution_result jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    executed_at timestamp with time zone,
    CONSTRAINT wan_control_actions_action_type_check CHECK (((action_type)::text = ANY ((ARRAY['ISOLATE'::character varying, 'RESTORE'::character varying, 'THROTTLE'::character varying, 'UNTHROTTLE'::character varying])::text[]))),
    CONSTRAINT wan_control_actions_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'EXECUTED'::character varying, 'SKIPPED'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: wan_control_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wan_control_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wan_control_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wan_control_actions_id_seq OWNED BY public.wan_control_actions.id;


--
-- Name: wan_incident_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wan_incident_state (
    router_id character varying(64) NOT NULL,
    interface_name character varying(16) NOT NULL,
    is_down boolean DEFAULT false,
    consecutive_zero_counts integer DEFAULT 0,
    last_alert_sent_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now(),
    outage_started_at timestamp with time zone,
    outage_cause character varying(32) DEFAULT 'ISP_FAILURE'::character varying,
    is_isolated boolean DEFAULT false,
    isolated_reason character varying(128),
    isolated_at timestamp with time zone,
    speed_limit_rx character varying(32),
    speed_limit_tx character varying(32)
);


--
-- Name: wan_operational_state_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wan_operational_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wan_operational_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wan_operational_state_id_seq OWNED BY public.wan_operational_state.id;


--
-- Name: wan_outage_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wan_outage_events (
    id bigint NOT NULL,
    router_id character varying(64) NOT NULL,
    interface_name character varying(32) NOT NULL,
    provider_name character varying(64) NOT NULL,
    landline_number character varying(32) NOT NULL,
    account_holder character varying(128) NOT NULL,
    started_at timestamp with time zone NOT NULL,
    ended_at timestamp with time zone,
    duration_minutes integer,
    outage_cause character varying(32) DEFAULT 'ISP_FAILURE'::character varying NOT NULL,
    email_sent boolean DEFAULT false NOT NULL,
    email_sent_at timestamp with time zone,
    email_recipient character varying(128),
    email_subject text,
    email_body text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: wan_outage_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wan_outage_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wan_outage_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wan_outage_events_id_seq OWNED BY public.wan_outage_events.id;


--
-- Name: whatsapp_instance_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.whatsapp_instance_snapshots (
    id integer NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    instance_name character varying(100) NOT NULL,
    status character varying(50) NOT NULL,
    uptime_seconds integer DEFAULT 0 NOT NULL,
    disconnect_count_24h integer DEFAULT 0 NOT NULL,
    reconnect_attempts_24h integer DEFAULT 0 NOT NULL,
    last_disconnect_time timestamp with time zone,
    last_disconnect_reason character varying(255)
);


--
-- Name: whatsapp_instance_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.whatsapp_instance_snapshots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: whatsapp_instance_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.whatsapp_instance_snapshots_id_seq OWNED BY public.whatsapp_instance_snapshots.id;


--
-- Name: whatsapp_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.whatsapp_instances (
    id integer NOT NULL,
    user_id integer NOT NULL,
    instance_name character varying NOT NULL,
    display_name character varying,
    phone_number character varying,
    provider character varying DEFAULT 'evolution'::character varying NOT NULL,
    status character varying DEFAULT 'disconnected'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_default boolean DEFAULT true NOT NULL,
    last_verified_at timestamp with time zone
);


--
-- Name: whatsapp_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.whatsapp_instances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: whatsapp_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.whatsapp_instances_id_seq OWNED BY public.whatsapp_instances.id;


--
-- Name: ai_action_idempotency; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency (
    id integer NOT NULL,
    idempotency_key character varying(128) NOT NULL,
    tenant_id integer NOT NULL,
    inbound_message_id integer NOT NULL,
    conversation_id integer NOT NULL,
    action_type character varying(50) NOT NULL,
    state character varying(32) NOT NULL,
    execution_id character varying(64) NOT NULL,
    trace_id character varying(64),
    outbound_message_id integer,
    created_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone
);


--
-- Name: ai_action_idempotency_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_action_idempotency_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency.id;


--
-- Name: ai_anomalies; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies (
    id integer NOT NULL,
    user_id integer NOT NULL,
    anomaly_type character varying(50) NOT NULL,
    severity character varying(20) NOT NULL,
    observed_value double precision NOT NULL,
    threshold_value double precision NOT NULL,
    details text,
    trace_id character varying(64),
    created_at timestamp with time zone NOT NULL
);


--
-- Name: ai_anomalies_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_anomalies_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies.id;


--
-- Name: ai_budget_reservations; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations (
    id integer NOT NULL,
    reservation_id character varying(64) NOT NULL,
    tenant_id integer NOT NULL,
    execution_id character varying(64) NOT NULL,
    trace_id character varying(64),
    requested_tokens integer NOT NULL,
    reserved_tokens integer NOT NULL,
    settled_tokens integer NOT NULL,
    requested_cost_usd numeric(12,4) NOT NULL,
    reserved_cost_usd numeric(12,4) NOT NULL,
    settled_cost_usd numeric(12,4) NOT NULL,
    status character varying(32) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL,
    settled_at timestamp with time zone,
    released_at timestamp with time zone
);


--
-- Name: ai_budget_reservations_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_budget_reservations_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations.id;


--
-- Name: ai_circuit_breakers; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers (
    id integer NOT NULL,
    user_id integer NOT NULL,
    circuit_type character varying(50) NOT NULL,
    state character varying(20) NOT NULL,
    failure_count integer NOT NULL,
    last_failure_reason character varying(255),
    opened_at timestamp with time zone,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: ai_circuit_breakers_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_circuit_breakers_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers.id;


--
-- Name: ai_configurations; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    enabled boolean NOT NULL,
    mode character varying(10) NOT NULL,
    provider character varying(9) NOT NULL,
    provider_mode character varying(12) NOT NULL,
    model character varying(100) NOT NULL,
    api_key_ciphertext text,
    api_key_last4 character varying(4),
    api_key_validated_at timestamp with time zone,
    system_prompt text,
    business_context text,
    language character varying(50) NOT NULL,
    tone character varying(100) NOT NULL,
    temperature double precision NOT NULL,
    max_tokens integer NOT NULL,
    confidence_threshold double precision NOT NULL,
    auto_reply_enabled boolean NOT NULL,
    escalation_enabled boolean NOT NULL,
    human_takeover_timeout_minutes integer NOT NULL,
    max_response_length integer NOT NULL,
    daily_message_limit integer NOT NULL,
    daily_token_limit integer NOT NULL,
    daily_cost_limit double precision NOT NULL,
    prompt_version integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: ai_configurations_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_configurations_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations.id;


--
-- Name: ai_control_audit_events; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events (
    id integer NOT NULL,
    tenant_id integer,
    actor_id integer,
    event_type character varying(100) NOT NULL,
    reason text,
    previous_state character varying(255),
    new_state character varying(255),
    trace_id character varying(64),
    created_at timestamp with time zone NOT NULL
);


--
-- Name: ai_control_audit_events_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_control_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events.id;


--
-- Name: ai_decisions; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    conversation_id integer NOT NULL,
    message_id integer NOT NULL,
    ai_job_id integer,
    trace_id character varying(64),
    provider character varying(50) NOT NULL,
    model character varying(100) NOT NULL,
    action character varying(10) NOT NULL,
    category character varying(19) NOT NULL,
    confidence double precision NOT NULL,
    reason text,
    proposed_reply text,
    policy_result character varying(50) NOT NULL,
    prompt_version integer NOT NULL,
    input_tokens integer NOT NULL,
    output_tokens integer NOT NULL,
    latency_ms double precision NOT NULL,
    estimated_cost_usd double precision NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: ai_decisions_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_decisions_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions.id;


--
-- Name: ai_execution_traces; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces (
    id integer NOT NULL,
    trace_id character varying(64) NOT NULL,
    user_id integer NOT NULL,
    conversation_id integer NOT NULL,
    message_id integer NOT NULL,
    ai_job_id integer,
    operation character varying(50) NOT NULL,
    provider character varying(50) NOT NULL,
    model character varying(100) NOT NULL,
    prompt_version integer NOT NULL,
    prompt_hash character varying(64),
    policy_version integer NOT NULL,
    config_version integer NOT NULL,
    input_tokens integer NOT NULL,
    output_tokens integer NOT NULL,
    total_tokens integer NOT NULL,
    estimated_cost_usd double precision NOT NULL,
    latency_ms double precision NOT NULL,
    result_status character varying(50) NOT NULL,
    action_taken character varying(50) NOT NULL,
    policy_result character varying(50) NOT NULL,
    decision_confidence double precision NOT NULL,
    is_autonomous boolean NOT NULL,
    is_escalated boolean NOT NULL,
    failure_category character varying(100),
    created_at timestamp with time zone NOT NULL
);


--
-- Name: ai_execution_traces_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_execution_traces_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces.id;


--
-- Name: ai_global_controls; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_global_controls (
    id integer NOT NULL,
    ai_enabled boolean NOT NULL,
    autonomous_enabled boolean NOT NULL,
    emergency_stop boolean NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    updated_by_id integer
);


--
-- Name: ai_global_controls_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_global_controls_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_global_controls_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_global_controls_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_global_controls.id;


--
-- Name: ai_jobs; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs (
    id integer NOT NULL,
    user_id integer NOT NULL,
    conversation_id integer NOT NULL,
    message_id integer NOT NULL,
    status character varying(10) NOT NULL,
    attempts integer NOT NULL,
    max_attempts integer NOT NULL,
    lease_token character varying(100),
    locked_at timestamp with time zone,
    prompt_version integer NOT NULL,
    decision jsonb,
    error_code character varying(100),
    error_message text,
    created_at timestamp with time zone NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone
);


--
-- Name: ai_jobs_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs.id;


--
-- Name: ai_knowledge_items; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items (
    id integer NOT NULL,
    user_id integer NOT NULL,
    knowledge_type character varying(14) NOT NULL,
    title character varying(255) NOT NULL,
    content text NOT NULL,
    category character varying(100),
    is_active boolean NOT NULL,
    priority integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: ai_knowledge_items_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_knowledge_items_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items.id;


--
-- Name: ai_policy_versions; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    version integer NOT NULL,
    policy_hash character varying(64) NOT NULL,
    rules_json jsonb NOT NULL,
    status character varying(20) NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: ai_policy_versions_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_policy_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions.id;


--
-- Name: ai_prompt_versions; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    version integer NOT NULL,
    system_prompt text NOT NULL,
    business_context text,
    content_hash character varying(64) NOT NULL,
    status character varying(20) NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: ai_prompt_versions_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_prompt_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions.id;


--
-- Name: ai_tenant_budgets; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets (
    id integer NOT NULL,
    tenant_id integer NOT NULL,
    budget_period character varying(50) NOT NULL,
    max_tokens integer NOT NULL,
    max_cost_usd numeric(12,4) NOT NULL,
    consumed_tokens integer NOT NULL,
    consumed_cost_usd numeric(12,4) NOT NULL,
    reserved_tokens integer NOT NULL,
    reserved_cost_usd numeric(12,4) NOT NULL,
    is_enabled boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: ai_tenant_budgets_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_tenant_budgets_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets.id;


--
-- Name: ai_tenant_controls; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls (
    id integer NOT NULL,
    tenant_id integer NOT NULL,
    ai_enabled boolean NOT NULL,
    autonomous_enabled boolean NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: ai_tenant_controls_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_tenant_controls_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls.id;


--
-- Name: campaign_groups; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    group_jid character varying(255) NOT NULL,
    group_name character varying(255),
    invite_link character varying(500),
    target_members integer NOT NULL,
    confirmed_joined integer NOT NULL,
    pending_invites integer NOT NULL,
    status character varying(14) NOT NULL,
    priority integer NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: campaign_groups_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups.id;


--
-- Name: campaign_metric_snapshots; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots (
    id integer NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    instance_name character varying(100),
    campaigns_started_today integer NOT NULL,
    campaigns_completed_today integer NOT NULL,
    campaigns_failed_today integer NOT NULL,
    groups_targeted_today integer NOT NULL,
    successful_sends_today integer NOT NULL,
    failed_sends_today integer NOT NULL,
    retries_today integer NOT NULL,
    pending_queue_count integer NOT NULL,
    success_rate_percent double precision NOT NULL,
    groups_per_hour double precision NOT NULL,
    avg_campaign_duration_seconds double precision NOT NULL
);


--
-- Name: campaign_metric_snapshots_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_metric_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots.id;


--
-- Name: campaign_rebalance_events; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    source_instance_id integer NOT NULL,
    destination_instance_id integer,
    reason_code character varying(100) NOT NULL,
    moved_targets_count integer NOT NULL,
    eligible_targets_evaluated integer NOT NULL,
    targets_skipped_active_lease integer NOT NULL,
    targets_unassignable integer NOT NULL,
    total_targets_in_scope integer NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: campaign_rebalance_events_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_rebalance_events_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events.id;


--
-- Name: campaign_safety_settings; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings (
    id integer NOT NULL,
    user_id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    min_delay_seconds double precision NOT NULL,
    max_delay_seconds double precision NOT NULL,
    batch_size integer NOT NULL,
    batch_cooldown_seconds integer NOT NULL,
    daily_message_limit integer NOT NULL,
    campaign_message_limit integer NOT NULL,
    is_safety_enabled boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: campaign_safety_settings_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_safety_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings.id;


--
-- Name: campaign_targets; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    target_id integer NOT NULL,
    assigned_instance_id integer,
    provider_message_id character varying(255),
    status test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigntargetstatus NOT NULL,
    attempts integer NOT NULL,
    next_attempt_at timestamp with time zone,
    version integer NOT NULL,
    lease_token character varying(100),
    last_attempt_at timestamp with time zone,
    completed_at timestamp with time zone,
    error_code character varying,
    error_message character varying,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: campaign_targets_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets.id;


--
-- Name: campaigns; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns (
    id integer NOT NULL,
    user_id integer,
    whatsapp_instance_id integer,
    name character varying NOT NULL,
    message_content character varying NOT NULL,
    media_url character varying,
    media_type character varying,
    status test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaignstatus NOT NULL,
    scheduled_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    total_targets integer NOT NULL,
    success_count integer NOT NULL,
    failed_count integer NOT NULL,
    skipped_count integer NOT NULL,
    cancelled_count integer NOT NULL,
    source_campaign_id integer
);


--
-- Name: campaigns_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaigns_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns.id;


--
-- Name: collection_targets; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets (
    id integer NOT NULL,
    collection_id integer NOT NULL,
    target_id integer NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: collection_targets_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collection_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets.id;


--
-- Name: collections; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections (
    id integer NOT NULL,
    user_id integer,
    whatsapp_instance_id integer,
    name character varying NOT NULL,
    description character varying,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: collections_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collections_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections.id;


--
-- Name: component_health; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.component_health (
    id character varying NOT NULL,
    component_type character varying NOT NULL,
    last_heartbeat_at timestamp with time zone NOT NULL,
    status character varying NOT NULL
);


--
-- Name: contact_campaign_progress; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    contact_id integer NOT NULL,
    state character varying(11) NOT NULL,
    allocated_group_id integer,
    outreach_sent_at timestamp with time zone,
    replied_at timestamp with time zone,
    reply_text character varying,
    allocated_at timestamp with time zone,
    invite_sent_at timestamp with time zone,
    joined_at timestamp with time zone,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: contact_campaign_progress_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contact_campaign_progress_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress.id;


--
-- Name: contacts; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    whatsapp_instance_id integer,
    provider character varying(50) NOT NULL,
    external_id character varying(255) NOT NULL,
    phone_number character varying(50),
    display_name character varying(255),
    is_active boolean NOT NULL,
    status character varying(50) NOT NULL,
    metadata jsonb,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: contacts_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts.id;


--
-- Name: conversations; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    whatsapp_instance_id integer,
    contact_id integer NOT NULL,
    provider character varying(50) NOT NULL,
    external_thread_id character varying(255),
    status character varying(8) NOT NULL,
    conversation_mode character varying(12) NOT NULL,
    human_takeover_at timestamp with time zone,
    unread_count integer NOT NULL,
    last_message_at timestamp with time zone,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: conversations_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations.id;


--
-- Name: daily_system_reports; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.daily_system_reports (
    id integer NOT NULL,
    report_date timestamp with time zone NOT NULL,
    report_type character varying(20) NOT NULL,
    health_score integer NOT NULL,
    status character varying(20) NOT NULL,
    critical_count integer NOT NULL,
    warning_count integer NOT NULL,
    subject character varying(255) NOT NULL,
    summary_text text NOT NULL,
    html_content text NOT NULL,
    metrics_summary jsonb,
    email_sent boolean NOT NULL,
    sent_at timestamp with time zone,
    error_message text
);


--
-- Name: daily_system_reports_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.daily_system_reports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_system_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.daily_system_reports_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.daily_system_reports.id;


--
-- Name: dead_letter_targets; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    campaign_target_id integer NOT NULL,
    target_id integer NOT NULL,
    user_id integer,
    attempts integer NOT NULL,
    error_code character varying(100),
    error_message text,
    last_error_details jsonb,
    redriven_at timestamp with time zone,
    redrive_count integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: dead_letter_targets_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dead_letter_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets.id;


--
-- Name: delivery_idempotency; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency (
    id integer NOT NULL,
    idempotency_key character varying(255) NOT NULL,
    campaign_id integer NOT NULL,
    campaign_target_id integer NOT NULL,
    target_id integer NOT NULL,
    user_id integer,
    status character varying(50) NOT NULL,
    attempt integer NOT NULL,
    external_reference character varying(255),
    error_code character varying(100),
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: delivery_idempotency_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delivery_idempotency_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency.id;


--
-- Name: execution_logs; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    campaign_target_id integer NOT NULL,
    action character varying NOT NULL,
    result test_818d3ceb0ced4bb09b0a383c38a9cd7a.executionresultstatus NOT NULL,
    error_code character varying,
    error_message character varying,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: execution_logs_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: execution_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs.id;


--
-- Name: group_invitations; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    campaign_group_id integer NOT NULL,
    contact_id integer NOT NULL,
    invite_link character varying(500) NOT NULL,
    status character varying(16) NOT NULL,
    provider_message_id character varying(255),
    sent_at timestamp with time zone,
    joined_at timestamp with time zone,
    idempotency_key character varying(255) NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: group_invitations_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations.id;


--
-- Name: instance_pacing_states; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_states (
    id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    state character varying NOT NULL,
    entered_at timestamp with time zone NOT NULL,
    reason character varying,
    failure_pressure double precision NOT NULL,
    retry_pressure double precision NOT NULL,
    vg_pressure double precision NOT NULL,
    consecutive_successes integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: instance_pacing_states_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_pacing_states_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_states_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_states.id;


--
-- Name: instance_pacing_transitions; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions (
    id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    old_state character varying NOT NULL,
    new_state character varying NOT NULL,
    reason character varying,
    failure_pressure double precision NOT NULL,
    retry_pressure double precision NOT NULL,
    vg_pressure double precision NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: instance_pacing_transitions_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_pacing_transitions_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions.id;


--
-- Name: instance_rebalance_states; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states (
    id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    state character varying(32) NOT NULL,
    failure_code character varying(100),
    quarantined_at timestamp with time zone,
    cooldown_until timestamp with time zone,
    rebalance_generation integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: instance_rebalance_states_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_rebalance_states_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states.id;


--
-- Name: instance_risk_profiles; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    risk_state character varying(32) NOT NULL,
    risk_score double precision NOT NULL,
    outbound_1h integer NOT NULL,
    outbound_24h integer NOT NULL,
    unique_recipients_24h integer NOT NULL,
    unique_groups_24h integer NOT NULL,
    reply_rate double precision NOT NULL,
    delivery_failure_rate double precision NOT NULL,
    opt_out_rate double precision NOT NULL,
    negative_signal_rate double precision NOT NULL,
    consecutive_failures integer NOT NULL,
    health_score double precision NOT NULL,
    last_risk_event_at timestamp with time zone,
    last_evaluated_at timestamp with time zone,
    risk_version integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: instance_risk_profiles_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_risk_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles.id;


--
-- Name: instance_state_audit_events; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events (
    id integer NOT NULL,
    whatsapp_instance_id integer NOT NULL,
    user_id integer,
    previous_state character varying(32) NOT NULL,
    new_state character varying(32) NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    reason_code character varying(200) NOT NULL,
    signal_category character varying(64) NOT NULL,
    consecutive_failures integer,
    cooldown_depth_seconds double precision,
    pacing_state_at_transition character varying(32),
    metadata_json jsonb
);


--
-- Name: instance_state_audit_events_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_state_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events.id;


--
-- Name: messages; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages (
    id integer NOT NULL,
    user_id integer NOT NULL,
    whatsapp_instance_id integer,
    conversation_id integer NOT NULL,
    contact_id integer NOT NULL,
    provider character varying(50) NOT NULL,
    external_message_id character varying(255),
    client_message_key character varying(255),
    direction character varying(8) NOT NULL,
    message_type character varying(8) NOT NULL,
    body text NOT NULL,
    status character varying(9) NOT NULL,
    error_code character varying(100),
    error_message text,
    provider_timestamp timestamp with time zone,
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    read_at timestamp with time zone,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages.id;


--
-- Name: quota_reservations; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    campaign_id integer NOT NULL,
    reserved_messages integer NOT NULL,
    consumed_messages integer NOT NULL,
    released_messages integer NOT NULL,
    status character varying(9) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: quota_reservations_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quota_reservations_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations.id;


--
-- Name: recipient_risk_profiles; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles (
    id integer NOT NULL,
    user_id integer NOT NULL,
    instance_id integer,
    recipient_jid character varying(255) NOT NULL,
    recipient_type character varying(32) NOT NULL,
    risk_state character varying(32) NOT NULL,
    last_inbound_at timestamp with time zone,
    last_outbound_at timestamp with time zone,
    messages_sent_24h integer NOT NULL,
    messages_received_24h integer NOT NULL,
    reply_count_7d integer NOT NULL,
    block_count integer NOT NULL,
    opt_out_count integer NOT NULL,
    delivery_failures_24h integer NOT NULL,
    negative_signal_count integer NOT NULL,
    consent_status character varying(32) NOT NULL,
    consent_source character varying(100),
    consent_at timestamp with time zone,
    risk_score double precision NOT NULL,
    risk_version integer NOT NULL,
    last_evaluated_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: recipient_risk_profiles_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recipient_risk_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles.id;


--
-- Name: refresh_tokens; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token_hash character varying(64) NOT NULL,
    family_id character varying(64) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    rotated_at timestamp with time zone,
    replaced_by_id integer,
    last_used_at timestamp with time zone
);


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens.id;


--
-- Name: risk_decisions; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions (
    id integer NOT NULL,
    user_id integer,
    instance_id integer,
    campaign_id integer,
    campaign_target_id integer,
    recipient_jid character varying(255) NOT NULL,
    recipient_type character varying(32) NOT NULL,
    decision character varying(32) NOT NULL,
    reason_codes jsonb NOT NULL,
    risk_score double precision NOT NULL,
    account_state character varying(32) NOT NULL,
    recipient_state character varying(32) NOT NULL,
    enforced boolean NOT NULL,
    policy_version character varying(32) NOT NULL,
    evaluation_context jsonb NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: risk_decisions_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_decisions_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions.id;


--
-- Name: risk_signals; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals (
    id integer NOT NULL,
    user_id integer,
    instance_id integer,
    recipient_jid character varying(255) NOT NULL,
    recipient_type character varying(32) NOT NULL,
    signal_type character varying(64) NOT NULL,
    source character varying(64) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: risk_signals_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_signals_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals.id;


--
-- Name: risk_state_transitions; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions (
    id integer NOT NULL,
    scope character varying(32) NOT NULL,
    instance_id integer,
    recipient_jid character varying(255),
    previous_state character varying(32) NOT NULL,
    new_state character varying(32) NOT NULL,
    previous_score double precision NOT NULL,
    new_score double precision NOT NULL,
    reason_codes jsonb NOT NULL,
    risk_version integer NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: risk_state_transitions_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_state_transitions_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions.id;


--
-- Name: subscription_events; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_events (
    id integer NOT NULL,
    user_id integer NOT NULL,
    old_tier character varying(50),
    new_tier character varying(50) NOT NULL,
    old_status character varying(50),
    new_status character varying(50) NOT NULL,
    duration_days integer,
    source character varying(50) NOT NULL,
    admin_telegram_id bigint,
    metadata json,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: subscription_events_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscription_events_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_events_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_events.id;


--
-- Name: subscription_payments; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_payments (
    id integer NOT NULL,
    user_id integer NOT NULL,
    tier character varying(10) NOT NULL,
    amount_usd double precision NOT NULL,
    currency character varying(10) NOT NULL,
    payment_method character varying(50) NOT NULL,
    receipt_file_id character varying(255),
    receipt_caption character varying(1000),
    status character varying(12) NOT NULL,
    reviewed_by_admin_id bigint,
    reviewed_at timestamp with time zone,
    rejection_reason character varying(500),
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: subscription_payments_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscription_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_payments_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_payments.id;


--
-- Name: system_metric_snapshots; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.system_metric_snapshots (
    id integer NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    ram_total_mb double precision NOT NULL,
    ram_used_mb double precision NOT NULL,
    ram_available_mb double precision NOT NULL,
    ram_used_percent double precision NOT NULL,
    swap_total_mb double precision NOT NULL,
    swap_used_mb double precision NOT NULL,
    load_1m double precision NOT NULL,
    load_5m double precision NOT NULL,
    load_15m double precision NOT NULL,
    cpu_count integer NOT NULL,
    disk_total_gb double precision NOT NULL,
    disk_used_gb double precision NOT NULL,
    disk_available_gb double precision NOT NULL,
    disk_used_percent double precision NOT NULL,
    evolution_ram_mb double precision NOT NULL,
    evolution_cpu_percent double precision NOT NULL,
    evolution_restart_count integer NOT NULL,
    evolution_status character varying(50) NOT NULL,
    postgres_ram_mb double precision NOT NULL,
    postgres_cpu_percent double precision NOT NULL,
    redis_used_memory_mb double precision NOT NULL,
    redis_maxmemory_mb double precision NOT NULL,
    redis_utilization_percent double precision NOT NULL,
    redis_connected_clients integer NOT NULL,
    redis_evicted_keys_total integer NOT NULL,
    redis_expired_keys_total integer NOT NULL,
    redis_fragmentation_ratio double precision NOT NULL,
    redis_keys_count integer NOT NULL,
    db_active_connections integer NOT NULL,
    db_idle_connections integer NOT NULL,
    db_idle_in_transaction integer NOT NULL,
    db_long_running_queries integer NOT NULL,
    db_size_mb double precision NOT NULL,
    db_message_table_size_mb double precision NOT NULL,
    db_message_row_estimate integer NOT NULL,
    db_critical_index_present boolean NOT NULL,
    metadata_json jsonb
);


--
-- Name: system_metric_snapshots_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.system_metric_snapshots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_metric_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.system_metric_snapshots_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.system_metric_snapshots.id;


--
-- Name: targets; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets (
    id integer NOT NULL,
    user_id integer,
    whatsapp_instance_id integer,
    external_id character varying NOT NULL,
    name character varying,
    enabled boolean NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: targets_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: targets_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets.id;


--
-- Name: templates; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.templates (
    id integer NOT NULL,
    name character varying NOT NULL,
    content character varying NOT NULL,
    enabled boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: templates_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.templates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: templates_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.templates_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.templates.id;


--
-- Name: usage_events; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events (
    id integer NOT NULL,
    user_id integer NOT NULL,
    campaign_id integer NOT NULL,
    delivery_id character varying(255) NOT NULL,
    message_count integer NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: usage_events_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usage_events_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events.id;


--
-- Name: user_subscriptions; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_subscriptions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    tier character varying(10) NOT NULL,
    status character varying(9) NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone,
    auto_renew boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: user_subscriptions_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_subscriptions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_subscriptions_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_subscriptions.id;


--
-- Name: user_usage_daily; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily (
    id integer NOT NULL,
    user_id integer NOT NULL,
    usage_date date NOT NULL,
    messages_sent integer NOT NULL,
    campaigns_created integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: user_usage_daily_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_usage_daily_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily.id;


--
-- Name: user_usage_monthly; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly (
    id integer NOT NULL,
    user_id integer NOT NULL,
    usage_month character varying(7) NOT NULL,
    messages_sent integer NOT NULL,
    campaigns_created integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: user_usage_monthly_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_usage_monthly_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly.id;


--
-- Name: users; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.users (
    id integer NOT NULL,
    telegram_user_id bigint NOT NULL,
    username character varying,
    display_name character varying,
    is_active boolean NOT NULL,
    language character varying(10) NOT NULL,
    safety_notice_accepted boolean NOT NULL,
    safety_notice_accepted_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.users_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.users.id;


--
-- Name: whatsapp_instance_snapshots; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots (
    id integer NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    instance_name character varying(100) NOT NULL,
    status character varying(50) NOT NULL,
    uptime_seconds integer NOT NULL,
    disconnect_count_24h integer NOT NULL,
    reconnect_attempts_24h integer NOT NULL,
    last_disconnect_time timestamp with time zone,
    last_disconnect_reason character varying(255)
);


--
-- Name: whatsapp_instance_snapshots_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: whatsapp_instance_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots.id;


--
-- Name: whatsapp_instances; Type: TABLE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE TABLE test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances (
    id integer NOT NULL,
    user_id integer NOT NULL,
    instance_name character varying NOT NULL,
    display_name character varying,
    phone_number character varying,
    provider character varying NOT NULL,
    status character varying NOT NULL,
    is_default boolean NOT NULL,
    last_verified_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: whatsapp_instances_id_seq; Type: SEQUENCE; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: whatsapp_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER SEQUENCE test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances_id_seq OWNED BY test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances.id;


--
-- Name: ai_action_idempotency id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_idempotency ALTER COLUMN id SET DEFAULT nextval('public.ai_action_idempotency_id_seq'::regclass);


--
-- Name: ai_anomalies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_anomalies ALTER COLUMN id SET DEFAULT nextval('public.ai_anomalies_id_seq'::regclass);


--
-- Name: ai_budget_reservations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_budget_reservations ALTER COLUMN id SET DEFAULT nextval('public.ai_budget_reservations_id_seq'::regclass);


--
-- Name: ai_circuit_breakers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_circuit_breakers ALTER COLUMN id SET DEFAULT nextval('public.ai_circuit_breakers_id_seq'::regclass);


--
-- Name: ai_configurations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_configurations ALTER COLUMN id SET DEFAULT nextval('public.ai_configurations_id_seq'::regclass);


--
-- Name: ai_control_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_control_audit_events ALTER COLUMN id SET DEFAULT nextval('public.ai_control_audit_events_id_seq'::regclass);


--
-- Name: ai_decisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_decisions ALTER COLUMN id SET DEFAULT nextval('public.ai_decisions_id_seq'::regclass);


--
-- Name: ai_execution_traces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_execution_traces ALTER COLUMN id SET DEFAULT nextval('public.ai_execution_traces_id_seq'::regclass);


--
-- Name: ai_global_controls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_global_controls ALTER COLUMN id SET DEFAULT nextval('public.ai_global_controls_id_seq'::regclass);


--
-- Name: ai_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_jobs ALTER COLUMN id SET DEFAULT nextval('public.ai_jobs_id_seq'::regclass);


--
-- Name: ai_policy_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_policy_versions ALTER COLUMN id SET DEFAULT nextval('public.ai_policy_versions_id_seq'::regclass);


--
-- Name: ai_prompt_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_prompt_versions ALTER COLUMN id SET DEFAULT nextval('public.ai_prompt_versions_id_seq'::regclass);


--
-- Name: ai_tenant_budgets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tenant_budgets ALTER COLUMN id SET DEFAULT nextval('public.ai_tenant_budgets_id_seq'::regclass);


--
-- Name: ai_tenant_controls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tenant_controls ALTER COLUMN id SET DEFAULT nextval('public.ai_tenant_controls_id_seq'::regclass);


--
-- Name: billing_cycles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_cycles ALTER COLUMN id SET DEFAULT nextval('public.billing_cycles_id_seq'::regclass);


--
-- Name: campaign_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_groups ALTER COLUMN id SET DEFAULT nextval('public.campaign_groups_id_seq'::regclass);


--
-- Name: campaign_metric_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_metric_snapshots ALTER COLUMN id SET DEFAULT nextval('public.campaign_metric_snapshots_id_seq'::regclass);


--
-- Name: campaign_rebalance_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_rebalance_events ALTER COLUMN id SET DEFAULT nextval('public.campaign_rebalance_events_id_seq'::regclass);


--
-- Name: campaign_safety_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_safety_settings ALTER COLUMN id SET DEFAULT nextval('public.campaign_safety_settings_id_seq'::regclass);


--
-- Name: campaign_targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_targets ALTER COLUMN id SET DEFAULT nextval('public.campaign_targets_id_seq'::regclass);


--
-- Name: campaigns id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns ALTER COLUMN id SET DEFAULT nextval('public.campaigns_id_seq'::regclass);


--
-- Name: collection_targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_targets ALTER COLUMN id SET DEFAULT nextval('public.collection_targets_id_seq'::regclass);


--
-- Name: collections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections ALTER COLUMN id SET DEFAULT nextval('public.collections_id_seq'::regclass);


--
-- Name: contact_campaign_progress id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_campaign_progress ALTER COLUMN id SET DEFAULT nextval('public.contact_campaign_progress_id_seq'::regclass);


--
-- Name: contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts ALTER COLUMN id SET DEFAULT nextval('public.contacts_id_seq'::regclass);


--
-- Name: conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations ALTER COLUMN id SET DEFAULT nextval('public.conversations_id_seq'::regclass);


--
-- Name: daily_system_reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_system_reports ALTER COLUMN id SET DEFAULT nextval('public.daily_system_reports_id_seq'::regclass);


--
-- Name: dead_letter_targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dead_letter_targets ALTER COLUMN id SET DEFAULT nextval('public.dead_letter_targets_id_seq'::regclass);


--
-- Name: delivery_idempotency id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_idempotency ALTER COLUMN id SET DEFAULT nextval('public.delivery_idempotency_id_seq'::regclass);


--
-- Name: execution_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_logs ALTER COLUMN id SET DEFAULT nextval('public.execution_logs_id_seq'::regclass);


--
-- Name: group_invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations ALTER COLUMN id SET DEFAULT nextval('public.group_invitations_id_seq'::regclass);


--
-- Name: hotspot_user_telemetry id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hotspot_user_telemetry ALTER COLUMN id SET DEFAULT nextval('public.hotspot_user_telemetry_id_seq'::regclass);


--
-- Name: instance_pacing_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_pacing_states ALTER COLUMN id SET DEFAULT nextval('public.instance_pacing_states_id_seq'::regclass);


--
-- Name: instance_pacing_transitions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_pacing_transitions ALTER COLUMN id SET DEFAULT nextval('public.instance_pacing_transitions_id_seq'::regclass);


--
-- Name: instance_rebalance_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_rebalance_states ALTER COLUMN id SET DEFAULT nextval('public.instance_rebalance_states_id_seq'::regclass);


--
-- Name: instance_risk_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_risk_profiles ALTER COLUMN id SET DEFAULT nextval('public.instance_risk_profiles_id_seq'::regclass);


--
-- Name: instance_state_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_state_audit_events ALTER COLUMN id SET DEFAULT nextval('public.instance_state_audit_events_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: mikrotik_wan_quality id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_quality ALTER COLUMN id SET DEFAULT nextval('public.mikrotik_wan_quality_id_seq'::regclass);


--
-- Name: mikrotik_wan_quotas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_quotas ALTER COLUMN id SET DEFAULT nextval('public.mikrotik_wan_quotas_id_seq'::regclass);


--
-- Name: mikrotik_wan_readings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_readings ALTER COLUMN id SET DEFAULT nextval('public.mikrotik_wan_readings_id_seq'::regclass);


--
-- Name: mikrotik_wan_usage id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_usage ALTER COLUMN id SET DEFAULT nextval('public.mikrotik_wan_usage_id_seq'::regclass);


--
-- Name: quota_allocations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_allocations ALTER COLUMN id SET DEFAULT nextval('public.quota_allocations_id_seq'::regclass);


--
-- Name: quota_reservations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_reservations ALTER COLUMN id SET DEFAULT nextval('public.quota_reservations_id_seq'::regclass);


--
-- Name: recipient_risk_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipient_risk_profiles ALTER COLUMN id SET DEFAULT nextval('public.recipient_risk_profiles_id_seq'::regclass);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('public.refresh_tokens_id_seq'::regclass);


--
-- Name: risk_decisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_decisions ALTER COLUMN id SET DEFAULT nextval('public.risk_decisions_id_seq'::regclass);


--
-- Name: risk_signals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_signals ALTER COLUMN id SET DEFAULT nextval('public.risk_signals_id_seq'::regclass);


--
-- Name: risk_state_transitions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_state_transitions ALTER COLUMN id SET DEFAULT nextval('public.risk_state_transitions_id_seq'::regclass);


--
-- Name: router_heartbeat_state id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.router_heartbeat_state ALTER COLUMN id SET DEFAULT nextval('public.router_heartbeat_state_id_seq'::regclass);


--
-- Name: subscription_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_events ALTER COLUMN id SET DEFAULT nextval('public.subscription_events_id_seq'::regclass);


--
-- Name: subscription_payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_payments ALTER COLUMN id SET DEFAULT nextval('public.subscription_payments_id_seq'::regclass);


--
-- Name: system_metric_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_metric_snapshots ALTER COLUMN id SET DEFAULT nextval('public.system_metric_snapshots_id_seq'::regclass);


--
-- Name: targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.targets ALTER COLUMN id SET DEFAULT nextval('public.targets_id_seq'::regclass);


--
-- Name: templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates ALTER COLUMN id SET DEFAULT nextval('public.templates_id_seq'::regclass);


--
-- Name: usage_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events ALTER COLUMN id SET DEFAULT nextval('public.usage_events_id_seq'::regclass);


--
-- Name: user_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.user_subscriptions_id_seq'::regclass);


--
-- Name: user_usage_daily id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_usage_daily ALTER COLUMN id SET DEFAULT nextval('public.user_usage_daily_id_seq'::regclass);


--
-- Name: user_usage_monthly id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_usage_monthly ALTER COLUMN id SET DEFAULT nextval('public.user_usage_monthly_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: wan_control_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wan_control_actions ALTER COLUMN id SET DEFAULT nextval('public.wan_control_actions_id_seq'::regclass);


--
-- Name: wan_operational_state id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wan_operational_state ALTER COLUMN id SET DEFAULT nextval('public.wan_operational_state_id_seq'::regclass);


--
-- Name: wan_outage_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wan_outage_events ALTER COLUMN id SET DEFAULT nextval('public.wan_outage_events_id_seq'::regclass);


--
-- Name: whatsapp_instance_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_instance_snapshots ALTER COLUMN id SET DEFAULT nextval('public.whatsapp_instance_snapshots_id_seq'::regclass);


--
-- Name: whatsapp_instances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_instances ALTER COLUMN id SET DEFAULT nextval('public.whatsapp_instances_id_seq'::regclass);


--
-- Name: ai_action_idempotency id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency_id_seq'::regclass);


--
-- Name: ai_anomalies id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies_id_seq'::regclass);


--
-- Name: ai_budget_reservations id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations_id_seq'::regclass);


--
-- Name: ai_circuit_breakers id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers_id_seq'::regclass);


--
-- Name: ai_configurations id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations_id_seq'::regclass);


--
-- Name: ai_control_audit_events id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events_id_seq'::regclass);


--
-- Name: ai_decisions id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions_id_seq'::regclass);


--
-- Name: ai_execution_traces id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces_id_seq'::regclass);


--
-- Name: ai_global_controls id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_global_controls ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_global_controls_id_seq'::regclass);


--
-- Name: ai_jobs id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs_id_seq'::regclass);


--
-- Name: ai_knowledge_items id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items_id_seq'::regclass);


--
-- Name: ai_policy_versions id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions_id_seq'::regclass);


--
-- Name: ai_prompt_versions id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions_id_seq'::regclass);


--
-- Name: ai_tenant_budgets id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets_id_seq'::regclass);


--
-- Name: ai_tenant_controls id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls_id_seq'::regclass);


--
-- Name: campaign_groups id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups_id_seq'::regclass);


--
-- Name: campaign_metric_snapshots id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots_id_seq'::regclass);


--
-- Name: campaign_rebalance_events id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events_id_seq'::regclass);


--
-- Name: campaign_safety_settings id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings_id_seq'::regclass);


--
-- Name: campaign_targets id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets_id_seq'::regclass);


--
-- Name: campaigns id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns_id_seq'::regclass);


--
-- Name: collection_targets id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets_id_seq'::regclass);


--
-- Name: collections id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections_id_seq'::regclass);


--
-- Name: contact_campaign_progress id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress_id_seq'::regclass);


--
-- Name: contacts id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts_id_seq'::regclass);


--
-- Name: conversations id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations_id_seq'::regclass);


--
-- Name: daily_system_reports id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.daily_system_reports ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.daily_system_reports_id_seq'::regclass);


--
-- Name: dead_letter_targets id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets_id_seq'::regclass);


--
-- Name: delivery_idempotency id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency_id_seq'::regclass);


--
-- Name: execution_logs id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs_id_seq'::regclass);


--
-- Name: group_invitations id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations_id_seq'::regclass);


--
-- Name: instance_pacing_states id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_states ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_states_id_seq'::regclass);


--
-- Name: instance_pacing_transitions id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions_id_seq'::regclass);


--
-- Name: instance_rebalance_states id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states_id_seq'::regclass);


--
-- Name: instance_risk_profiles id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles_id_seq'::regclass);


--
-- Name: instance_state_audit_events id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages_id_seq'::regclass);


--
-- Name: quota_reservations id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations_id_seq'::regclass);


--
-- Name: recipient_risk_profiles id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles_id_seq'::regclass);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens_id_seq'::regclass);


--
-- Name: risk_decisions id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions_id_seq'::regclass);


--
-- Name: risk_signals id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals_id_seq'::regclass);


--
-- Name: risk_state_transitions id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions_id_seq'::regclass);


--
-- Name: subscription_events id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_events ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_events_id_seq'::regclass);


--
-- Name: subscription_payments id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_payments ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_payments_id_seq'::regclass);


--
-- Name: system_metric_snapshots id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.system_metric_snapshots ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.system_metric_snapshots_id_seq'::regclass);


--
-- Name: targets id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets_id_seq'::regclass);


--
-- Name: templates id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.templates ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.templates_id_seq'::regclass);


--
-- Name: usage_events id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events_id_seq'::regclass);


--
-- Name: user_subscriptions id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_subscriptions ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_subscriptions_id_seq'::regclass);


--
-- Name: user_usage_daily id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily_id_seq'::regclass);


--
-- Name: user_usage_monthly id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.users ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.users_id_seq'::regclass);


--
-- Name: whatsapp_instance_snapshots id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots_id_seq'::regclass);


--
-- Name: whatsapp_instances id; Type: DEFAULT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances ALTER COLUMN id SET DEFAULT nextval('test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances_id_seq'::regclass);


--
-- Name: Chat Chat_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Chat"
    ADD CONSTRAINT "Chat_pkey" PRIMARY KEY (id);


--
-- Name: Chatwoot Chatwoot_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Chatwoot"
    ADD CONSTRAINT "Chatwoot_pkey" PRIMARY KEY (id);


--
-- Name: Contact Contact_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Contact"
    ADD CONSTRAINT "Contact_pkey" PRIMARY KEY (id);


--
-- Name: DifySetting DifySetting_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."DifySetting"
    ADD CONSTRAINT "DifySetting_pkey" PRIMARY KEY (id);


--
-- Name: Dify Dify_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Dify"
    ADD CONSTRAINT "Dify_pkey" PRIMARY KEY (id);


--
-- Name: EvoaiSetting EvoaiSetting_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."EvoaiSetting"
    ADD CONSTRAINT "EvoaiSetting_pkey" PRIMARY KEY (id);


--
-- Name: Evoai Evoai_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Evoai"
    ADD CONSTRAINT "Evoai_pkey" PRIMARY KEY (id);


--
-- Name: EvolutionBotSetting EvolutionBotSetting_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."EvolutionBotSetting"
    ADD CONSTRAINT "EvolutionBotSetting_pkey" PRIMARY KEY (id);


--
-- Name: EvolutionBot EvolutionBot_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."EvolutionBot"
    ADD CONSTRAINT "EvolutionBot_pkey" PRIMARY KEY (id);


--
-- Name: FlowiseSetting FlowiseSetting_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."FlowiseSetting"
    ADD CONSTRAINT "FlowiseSetting_pkey" PRIMARY KEY (id);


--
-- Name: Flowise Flowise_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Flowise"
    ADD CONSTRAINT "Flowise_pkey" PRIMARY KEY (id);


--
-- Name: Instance Instance_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Instance"
    ADD CONSTRAINT "Instance_pkey" PRIMARY KEY (id);


--
-- Name: IntegrationSession IntegrationSession_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."IntegrationSession"
    ADD CONSTRAINT "IntegrationSession_pkey" PRIMARY KEY (id);


--
-- Name: IsOnWhatsapp IsOnWhatsapp_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."IsOnWhatsapp"
    ADD CONSTRAINT "IsOnWhatsapp_pkey" PRIMARY KEY (id);


--
-- Name: Kafka Kafka_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Kafka"
    ADD CONSTRAINT "Kafka_pkey" PRIMARY KEY (id);


--
-- Name: Label Label_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Label"
    ADD CONSTRAINT "Label_pkey" PRIMARY KEY (id);


--
-- Name: Media Media_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Media"
    ADD CONSTRAINT "Media_pkey" PRIMARY KEY (id);


--
-- Name: MessageUpdate MessageUpdate_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."MessageUpdate"
    ADD CONSTRAINT "MessageUpdate_pkey" PRIMARY KEY (id);


--
-- Name: Message Message_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Message"
    ADD CONSTRAINT "Message_pkey" PRIMARY KEY (id);


--
-- Name: N8nSetting N8nSetting_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."N8nSetting"
    ADD CONSTRAINT "N8nSetting_pkey" PRIMARY KEY (id);


--
-- Name: N8n N8n_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."N8n"
    ADD CONSTRAINT "N8n_pkey" PRIMARY KEY (id);


--
-- Name: Nats Nats_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Nats"
    ADD CONSTRAINT "Nats_pkey" PRIMARY KEY (id);


--
-- Name: OpenaiBot OpenaiBot_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."OpenaiBot"
    ADD CONSTRAINT "OpenaiBot_pkey" PRIMARY KEY (id);


--
-- Name: OpenaiCreds OpenaiCreds_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."OpenaiCreds"
    ADD CONSTRAINT "OpenaiCreds_pkey" PRIMARY KEY (id);


--
-- Name: OpenaiSetting OpenaiSetting_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."OpenaiSetting"
    ADD CONSTRAINT "OpenaiSetting_pkey" PRIMARY KEY (id);


--
-- Name: Proxy Proxy_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Proxy"
    ADD CONSTRAINT "Proxy_pkey" PRIMARY KEY (id);


--
-- Name: Pusher Pusher_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Pusher"
    ADD CONSTRAINT "Pusher_pkey" PRIMARY KEY (id);


--
-- Name: Rabbitmq Rabbitmq_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Rabbitmq"
    ADD CONSTRAINT "Rabbitmq_pkey" PRIMARY KEY (id);


--
-- Name: Session Session_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Session"
    ADD CONSTRAINT "Session_pkey" PRIMARY KEY (id);


--
-- Name: Setting Setting_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Setting"
    ADD CONSTRAINT "Setting_pkey" PRIMARY KEY (id);


--
-- Name: Sqs Sqs_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Sqs"
    ADD CONSTRAINT "Sqs_pkey" PRIMARY KEY (id);


--
-- Name: Template Template_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Template"
    ADD CONSTRAINT "Template_pkey" PRIMARY KEY (id);


--
-- Name: TypebotSetting TypebotSetting_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."TypebotSetting"
    ADD CONSTRAINT "TypebotSetting_pkey" PRIMARY KEY (id);


--
-- Name: Typebot Typebot_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Typebot"
    ADD CONSTRAINT "Typebot_pkey" PRIMARY KEY (id);


--
-- Name: Webhook Webhook_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Webhook"
    ADD CONSTRAINT "Webhook_pkey" PRIMARY KEY (id);


--
-- Name: Websocket Websocket_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Websocket"
    ADD CONSTRAINT "Websocket_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: ai_action_idempotency ai_action_idempotency_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_pkey PRIMARY KEY (id);


--
-- Name: ai_anomalies ai_anomalies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_anomalies
    ADD CONSTRAINT ai_anomalies_pkey PRIMARY KEY (id);


--
-- Name: ai_budget_reservations ai_budget_reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_budget_reservations
    ADD CONSTRAINT ai_budget_reservations_pkey PRIMARY KEY (id);


--
-- Name: ai_circuit_breakers ai_circuit_breakers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_circuit_breakers
    ADD CONSTRAINT ai_circuit_breakers_pkey PRIMARY KEY (id);


--
-- Name: ai_configurations ai_configurations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_configurations
    ADD CONSTRAINT ai_configurations_pkey PRIMARY KEY (id);


--
-- Name: ai_control_audit_events ai_control_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_control_audit_events
    ADD CONSTRAINT ai_control_audit_events_pkey PRIMARY KEY (id);


--
-- Name: ai_decisions ai_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_decisions
    ADD CONSTRAINT ai_decisions_pkey PRIMARY KEY (id);


--
-- Name: ai_execution_traces ai_execution_traces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_execution_traces
    ADD CONSTRAINT ai_execution_traces_pkey PRIMARY KEY (id);


--
-- Name: ai_global_controls ai_global_controls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_global_controls
    ADD CONSTRAINT ai_global_controls_pkey PRIMARY KEY (id);


--
-- Name: ai_jobs ai_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_jobs
    ADD CONSTRAINT ai_jobs_pkey PRIMARY KEY (id);


--
-- Name: ai_policy_versions ai_policy_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_policy_versions
    ADD CONSTRAINT ai_policy_versions_pkey PRIMARY KEY (id);


--
-- Name: ai_prompt_versions ai_prompt_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_prompt_versions
    ADD CONSTRAINT ai_prompt_versions_pkey PRIMARY KEY (id);


--
-- Name: ai_tenant_budgets ai_tenant_budgets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tenant_budgets
    ADD CONSTRAINT ai_tenant_budgets_pkey PRIMARY KEY (id);


--
-- Name: ai_tenant_controls ai_tenant_controls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tenant_controls
    ADD CONSTRAINT ai_tenant_controls_pkey PRIMARY KEY (id);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: billing_cycles billing_cycles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_cycles
    ADD CONSTRAINT billing_cycles_pkey PRIMARY KEY (id);


--
-- Name: campaign_groups campaign_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_groups
    ADD CONSTRAINT campaign_groups_pkey PRIMARY KEY (id);


--
-- Name: campaign_metric_snapshots campaign_metric_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_metric_snapshots
    ADD CONSTRAINT campaign_metric_snapshots_pkey PRIMARY KEY (id);


--
-- Name: campaign_rebalance_events campaign_rebalance_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_rebalance_events
    ADD CONSTRAINT campaign_rebalance_events_pkey PRIMARY KEY (id);


--
-- Name: campaign_safety_settings campaign_safety_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_safety_settings
    ADD CONSTRAINT campaign_safety_settings_pkey PRIMARY KEY (id);


--
-- Name: campaign_safety_settings campaign_safety_settings_whatsapp_instance_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_safety_settings
    ADD CONSTRAINT campaign_safety_settings_whatsapp_instance_id_key UNIQUE (whatsapp_instance_id);


--
-- Name: campaign_targets campaign_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_targets
    ADD CONSTRAINT campaign_targets_pkey PRIMARY KEY (id);


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (id);


--
-- Name: collection_targets collection_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_targets
    ADD CONSTRAINT collection_targets_pkey PRIMARY KEY (id);


--
-- Name: collections collections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (id);


--
-- Name: component_health component_health_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.component_health
    ADD CONSTRAINT component_health_pkey PRIMARY KEY (id);


--
-- Name: contact_campaign_progress contact_campaign_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_campaign_progress
    ADD CONSTRAINT contact_campaign_progress_pkey PRIMARY KEY (id);


--
-- Name: contacts contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: daily_system_reports daily_system_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_system_reports
    ADD CONSTRAINT daily_system_reports_pkey PRIMARY KEY (id);


--
-- Name: dead_letter_targets dead_letter_targets_campaign_target_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_campaign_target_id_key UNIQUE (campaign_target_id);


--
-- Name: dead_letter_targets dead_letter_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_pkey PRIMARY KEY (id);


--
-- Name: delivery_idempotency delivery_idempotency_idempotency_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: delivery_idempotency delivery_idempotency_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_pkey PRIMARY KEY (id);


--
-- Name: execution_logs execution_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_logs
    ADD CONSTRAINT execution_logs_pkey PRIMARY KEY (id);


--
-- Name: group_invitations group_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT group_invitations_pkey PRIMARY KEY (id);


--
-- Name: hotspot_user_telemetry hotspot_user_telemetry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hotspot_user_telemetry
    ADD CONSTRAINT hotspot_user_telemetry_pkey PRIMARY KEY (id);


--
-- Name: instance_pacing_states instance_pacing_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_pacing_states
    ADD CONSTRAINT instance_pacing_states_pkey PRIMARY KEY (id);


--
-- Name: instance_pacing_transitions instance_pacing_transitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_pacing_transitions
    ADD CONSTRAINT instance_pacing_transitions_pkey PRIMARY KEY (id);


--
-- Name: instance_rebalance_states instance_rebalance_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_rebalance_states
    ADD CONSTRAINT instance_rebalance_states_pkey PRIMARY KEY (id);


--
-- Name: instance_rebalance_states instance_rebalance_states_whatsapp_instance_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_rebalance_states
    ADD CONSTRAINT instance_rebalance_states_whatsapp_instance_id_key UNIQUE (whatsapp_instance_id);


--
-- Name: instance_risk_profiles instance_risk_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_risk_profiles
    ADD CONSTRAINT instance_risk_profiles_pkey PRIMARY KEY (id);


--
-- Name: instance_state_audit_events instance_state_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_state_audit_events
    ADD CONSTRAINT instance_state_audit_events_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: mikrotik_wan_quality mikrotik_wan_quality_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_quality
    ADD CONSTRAINT mikrotik_wan_quality_pkey PRIMARY KEY (id);


--
-- Name: mikrotik_wan_quotas mikrotik_wan_quotas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_quotas
    ADD CONSTRAINT mikrotik_wan_quotas_pkey PRIMARY KEY (id);


--
-- Name: mikrotik_wan_readings mikrotik_wan_readings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_readings
    ADD CONSTRAINT mikrotik_wan_readings_pkey PRIMARY KEY (id);


--
-- Name: mikrotik_wan_usage mikrotik_wan_usage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_usage
    ADD CONSTRAINT mikrotik_wan_usage_pkey PRIMARY KEY (id);


--
-- Name: quota_alert_state quota_alert_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_alert_state
    ADD CONSTRAINT quota_alert_state_pkey PRIMARY KEY (router_id, interface_name, cycle_start);


--
-- Name: quota_allocations quota_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_allocations
    ADD CONSTRAINT quota_allocations_pkey PRIMARY KEY (id);


--
-- Name: quota_day_weights quota_day_weights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_day_weights
    ADD CONSTRAINT quota_day_weights_pkey PRIMARY KEY (day_of_week);


--
-- Name: quota_reservations quota_reservations_campaign_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_reservations
    ADD CONSTRAINT quota_reservations_campaign_id_key UNIQUE (campaign_id);


--
-- Name: quota_reservations quota_reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_reservations
    ADD CONSTRAINT quota_reservations_pkey PRIMARY KEY (id);


--
-- Name: recipient_risk_profiles recipient_risk_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipient_risk_profiles
    ADD CONSTRAINT recipient_risk_profiles_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: risk_decisions risk_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_decisions
    ADD CONSTRAINT risk_decisions_pkey PRIMARY KEY (id);


--
-- Name: risk_signals risk_signals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_signals
    ADD CONSTRAINT risk_signals_pkey PRIMARY KEY (id);


--
-- Name: risk_state_transitions risk_state_transitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_state_transitions
    ADD CONSTRAINT risk_state_transitions_pkey PRIMARY KEY (id);


--
-- Name: router_heartbeat_state router_heartbeat_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.router_heartbeat_state
    ADD CONSTRAINT router_heartbeat_state_pkey PRIMARY KEY (id);


--
-- Name: router_heartbeat_state router_heartbeat_state_router_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.router_heartbeat_state
    ADD CONSTRAINT router_heartbeat_state_router_id_key UNIQUE (router_id);


--
-- Name: subscription_events subscription_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_events
    ADD CONSTRAINT subscription_events_pkey PRIMARY KEY (id);


--
-- Name: subscription_payments subscription_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_payments
    ADD CONSTRAINT subscription_payments_pkey PRIMARY KEY (id);


--
-- Name: system_metric_snapshots system_metric_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_metric_snapshots
    ADD CONSTRAINT system_metric_snapshots_pkey PRIMARY KEY (id);


--
-- Name: targets targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.targets
    ADD CONSTRAINT targets_pkey PRIMARY KEY (id);


--
-- Name: templates templates_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_name_key UNIQUE (name);


--
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: mikrotik_wan_quotas unique_router_interface; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_quotas
    ADD CONSTRAINT unique_router_interface UNIQUE (router_id, interface_name);


--
-- Name: ai_action_idempotency uq_ai_action_idempotency_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_idempotency
    ADD CONSTRAINT uq_ai_action_idempotency_key UNIQUE (idempotency_key);


--
-- Name: ai_budget_reservations uq_ai_budget_reservations_reservation_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_budget_reservations
    ADD CONSTRAINT uq_ai_budget_reservations_reservation_id UNIQUE (reservation_id);


--
-- Name: ai_circuit_breakers uq_ai_circuit_user_type; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_circuit_breakers
    ADD CONSTRAINT uq_ai_circuit_user_type UNIQUE (user_id, circuit_type);


--
-- Name: ai_configurations uq_ai_configurations_user_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_configurations
    ADD CONSTRAINT uq_ai_configurations_user_id UNIQUE (user_id);


--
-- Name: ai_action_idempotency uq_ai_idempotency_tenant_msg_action; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_idempotency
    ADD CONSTRAINT uq_ai_idempotency_tenant_msg_action UNIQUE (tenant_id, inbound_message_id, action_type);


--
-- Name: ai_jobs uq_ai_jobs_user_message; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_jobs
    ADD CONSTRAINT uq_ai_jobs_user_message UNIQUE (user_id, message_id);


--
-- Name: ai_policy_versions uq_ai_policy_user_version; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_policy_versions
    ADD CONSTRAINT uq_ai_policy_user_version UNIQUE (user_id, version);


--
-- Name: ai_prompt_versions uq_ai_prompt_user_version; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_prompt_versions
    ADD CONSTRAINT uq_ai_prompt_user_version UNIQUE (user_id, version);


--
-- Name: ai_tenant_budgets uq_ai_tenant_budgets_tenant_period; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tenant_budgets
    ADD CONSTRAINT uq_ai_tenant_budgets_tenant_period UNIQUE (tenant_id, budget_period);


--
-- Name: ai_tenant_controls uq_ai_tenant_controls_tenant_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tenant_controls
    ADD CONSTRAINT uq_ai_tenant_controls_tenant_id UNIQUE (tenant_id);


--
-- Name: billing_cycles uq_billing_cycle_router_iface_start; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_cycles
    ADD CONSTRAINT uq_billing_cycle_router_iface_start UNIQUE (router_id, interface_name, cycle_start);


--
-- Name: campaign_groups uq_campaign_group_campaign_jid; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_groups
    ADD CONSTRAINT uq_campaign_group_campaign_jid UNIQUE (campaign_id, group_jid);


--
-- Name: campaign_targets uq_campaign_target; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_targets
    ADD CONSTRAINT uq_campaign_target UNIQUE (campaign_id, target_id);


--
-- Name: collection_targets uq_collection_target; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_targets
    ADD CONSTRAINT uq_collection_target UNIQUE (collection_id, target_id);


--
-- Name: collections uq_collections_instance_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT uq_collections_instance_name UNIQUE (whatsapp_instance_id, name);


--
-- Name: contact_campaign_progress uq_contact_campaign_progress; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_campaign_progress
    ADD CONSTRAINT uq_contact_campaign_progress UNIQUE (campaign_id, contact_id);


--
-- Name: contacts uq_contacts_tenant_instance_external; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT uq_contacts_tenant_instance_external UNIQUE (user_id, whatsapp_instance_id, external_id);


--
-- Name: conversations uq_conversations_tenant_instance_contact; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT uq_conversations_tenant_instance_contact UNIQUE (user_id, whatsapp_instance_id, contact_id);


--
-- Name: group_invitations uq_group_invitations_campaign_contact; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT uq_group_invitations_campaign_contact UNIQUE (campaign_id, contact_id);


--
-- Name: group_invitations uq_group_invitations_idempotency_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT uq_group_invitations_idempotency_key UNIQUE (idempotency_key);


--
-- Name: recipient_risk_profiles uq_recipient_risk_profiles_user_jid; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipient_risk_profiles
    ADD CONSTRAINT uq_recipient_risk_profiles_user_jid UNIQUE (user_id, recipient_jid);


--
-- Name: targets uq_targets_instance_external_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.targets
    ADD CONSTRAINT uq_targets_instance_external_id UNIQUE (whatsapp_instance_id, external_id);


--
-- Name: user_usage_daily uq_user_usage_daily_user_date; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_usage_daily
    ADD CONSTRAINT uq_user_usage_daily_user_date UNIQUE (user_id, usage_date);


--
-- Name: user_usage_monthly uq_user_usage_monthly_user_month; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_usage_monthly
    ADD CONSTRAINT uq_user_usage_monthly_user_month UNIQUE (user_id, usage_month);


--
-- Name: wan_operational_state uq_wan_operational_state; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wan_operational_state
    ADD CONSTRAINT uq_wan_operational_state UNIQUE (router_id, interface_name);


--
-- Name: usage_events usage_events_delivery_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_delivery_id_key UNIQUE (delivery_id);


--
-- Name: usage_events usage_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_pkey PRIMARY KEY (id);


--
-- Name: user_subscriptions user_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: user_subscriptions user_subscriptions_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_user_id_key UNIQUE (user_id);


--
-- Name: user_usage_daily user_usage_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_usage_daily
    ADD CONSTRAINT user_usage_daily_pkey PRIMARY KEY (id);


--
-- Name: user_usage_monthly user_usage_monthly_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_usage_monthly
    ADD CONSTRAINT user_usage_monthly_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wan_control_actions wan_control_actions_idempotency_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wan_control_actions
    ADD CONSTRAINT wan_control_actions_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: wan_control_actions wan_control_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wan_control_actions
    ADD CONSTRAINT wan_control_actions_pkey PRIMARY KEY (id);


--
-- Name: wan_incident_state wan_incident_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wan_incident_state
    ADD CONSTRAINT wan_incident_state_pkey PRIMARY KEY (router_id, interface_name);


--
-- Name: wan_operational_state wan_operational_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wan_operational_state
    ADD CONSTRAINT wan_operational_state_pkey PRIMARY KEY (id);


--
-- Name: wan_outage_events wan_outage_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wan_outage_events
    ADD CONSTRAINT wan_outage_events_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_instance_snapshots whatsapp_instance_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_instance_snapshots
    ADD CONSTRAINT whatsapp_instance_snapshots_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_instances whatsapp_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_instances
    ADD CONSTRAINT whatsapp_instances_pkey PRIMARY KEY (id);


--
-- Name: ai_action_idempotency ai_action_idempotency_idempotency_key_key; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: ai_action_idempotency ai_action_idempotency_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_pkey PRIMARY KEY (id);


--
-- Name: ai_anomalies ai_anomalies_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies
    ADD CONSTRAINT ai_anomalies_pkey PRIMARY KEY (id);


--
-- Name: ai_budget_reservations ai_budget_reservations_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations
    ADD CONSTRAINT ai_budget_reservations_pkey PRIMARY KEY (id);


--
-- Name: ai_circuit_breakers ai_circuit_breakers_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers
    ADD CONSTRAINT ai_circuit_breakers_pkey PRIMARY KEY (id);


--
-- Name: ai_configurations ai_configurations_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations
    ADD CONSTRAINT ai_configurations_pkey PRIMARY KEY (id);


--
-- Name: ai_control_audit_events ai_control_audit_events_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events
    ADD CONSTRAINT ai_control_audit_events_pkey PRIMARY KEY (id);


--
-- Name: ai_decisions ai_decisions_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions
    ADD CONSTRAINT ai_decisions_pkey PRIMARY KEY (id);


--
-- Name: ai_execution_traces ai_execution_traces_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces
    ADD CONSTRAINT ai_execution_traces_pkey PRIMARY KEY (id);


--
-- Name: ai_global_controls ai_global_controls_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_global_controls
    ADD CONSTRAINT ai_global_controls_pkey PRIMARY KEY (id);


--
-- Name: ai_jobs ai_jobs_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs
    ADD CONSTRAINT ai_jobs_pkey PRIMARY KEY (id);


--
-- Name: ai_knowledge_items ai_knowledge_items_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items
    ADD CONSTRAINT ai_knowledge_items_pkey PRIMARY KEY (id);


--
-- Name: ai_policy_versions ai_policy_versions_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions
    ADD CONSTRAINT ai_policy_versions_pkey PRIMARY KEY (id);


--
-- Name: ai_prompt_versions ai_prompt_versions_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions
    ADD CONSTRAINT ai_prompt_versions_pkey PRIMARY KEY (id);


--
-- Name: ai_tenant_budgets ai_tenant_budgets_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets
    ADD CONSTRAINT ai_tenant_budgets_pkey PRIMARY KEY (id);


--
-- Name: ai_tenant_controls ai_tenant_controls_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls
    ADD CONSTRAINT ai_tenant_controls_pkey PRIMARY KEY (id);


--
-- Name: campaign_groups campaign_groups_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups
    ADD CONSTRAINT campaign_groups_pkey PRIMARY KEY (id);


--
-- Name: campaign_metric_snapshots campaign_metric_snapshots_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots
    ADD CONSTRAINT campaign_metric_snapshots_pkey PRIMARY KEY (id);


--
-- Name: campaign_rebalance_events campaign_rebalance_events_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events
    ADD CONSTRAINT campaign_rebalance_events_pkey PRIMARY KEY (id);


--
-- Name: campaign_safety_settings campaign_safety_settings_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings
    ADD CONSTRAINT campaign_safety_settings_pkey PRIMARY KEY (id);


--
-- Name: campaign_targets campaign_targets_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets
    ADD CONSTRAINT campaign_targets_pkey PRIMARY KEY (id);


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (id);


--
-- Name: collection_targets collection_targets_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets
    ADD CONSTRAINT collection_targets_pkey PRIMARY KEY (id);


--
-- Name: collections collections_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (id);


--
-- Name: component_health component_health_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.component_health
    ADD CONSTRAINT component_health_pkey PRIMARY KEY (id);


--
-- Name: contact_campaign_progress contact_campaign_progress_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress
    ADD CONSTRAINT contact_campaign_progress_pkey PRIMARY KEY (id);


--
-- Name: contacts contacts_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: daily_system_reports daily_system_reports_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.daily_system_reports
    ADD CONSTRAINT daily_system_reports_pkey PRIMARY KEY (id);


--
-- Name: dead_letter_targets dead_letter_targets_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_pkey PRIMARY KEY (id);


--
-- Name: delivery_idempotency delivery_idempotency_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_pkey PRIMARY KEY (id);


--
-- Name: execution_logs execution_logs_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs
    ADD CONSTRAINT execution_logs_pkey PRIMARY KEY (id);


--
-- Name: group_invitations group_invitations_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations
    ADD CONSTRAINT group_invitations_pkey PRIMARY KEY (id);


--
-- Name: instance_pacing_states instance_pacing_states_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_states
    ADD CONSTRAINT instance_pacing_states_pkey PRIMARY KEY (id);


--
-- Name: instance_pacing_transitions instance_pacing_transitions_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions
    ADD CONSTRAINT instance_pacing_transitions_pkey PRIMARY KEY (id);


--
-- Name: instance_rebalance_states instance_rebalance_states_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states
    ADD CONSTRAINT instance_rebalance_states_pkey PRIMARY KEY (id);


--
-- Name: instance_risk_profiles instance_risk_profiles_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles
    ADD CONSTRAINT instance_risk_profiles_pkey PRIMARY KEY (id);


--
-- Name: instance_state_audit_events instance_state_audit_events_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events
    ADD CONSTRAINT instance_state_audit_events_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: quota_reservations quota_reservations_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations
    ADD CONSTRAINT quota_reservations_pkey PRIMARY KEY (id);


--
-- Name: recipient_risk_profiles recipient_risk_profiles_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles
    ADD CONSTRAINT recipient_risk_profiles_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: risk_decisions risk_decisions_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions
    ADD CONSTRAINT risk_decisions_pkey PRIMARY KEY (id);


--
-- Name: risk_signals risk_signals_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals
    ADD CONSTRAINT risk_signals_pkey PRIMARY KEY (id);


--
-- Name: risk_state_transitions risk_state_transitions_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions
    ADD CONSTRAINT risk_state_transitions_pkey PRIMARY KEY (id);


--
-- Name: subscription_events subscription_events_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_events
    ADD CONSTRAINT subscription_events_pkey PRIMARY KEY (id);


--
-- Name: subscription_payments subscription_payments_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_payments
    ADD CONSTRAINT subscription_payments_pkey PRIMARY KEY (id);


--
-- Name: system_metric_snapshots system_metric_snapshots_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.system_metric_snapshots
    ADD CONSTRAINT system_metric_snapshots_pkey PRIMARY KEY (id);


--
-- Name: targets targets_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets
    ADD CONSTRAINT targets_pkey PRIMARY KEY (id);


--
-- Name: templates templates_name_key; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.templates
    ADD CONSTRAINT templates_name_key UNIQUE (name);


--
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: ai_circuit_breakers uq_ai_circuit_user_type; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers
    ADD CONSTRAINT uq_ai_circuit_user_type UNIQUE (user_id, circuit_type);


--
-- Name: ai_configurations uq_ai_configurations_user_id; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations
    ADD CONSTRAINT uq_ai_configurations_user_id UNIQUE (user_id);


--
-- Name: ai_action_idempotency uq_ai_idempotency_tenant_msg_action; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency
    ADD CONSTRAINT uq_ai_idempotency_tenant_msg_action UNIQUE (tenant_id, inbound_message_id, action_type);


--
-- Name: ai_jobs uq_ai_jobs_user_message; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs
    ADD CONSTRAINT uq_ai_jobs_user_message UNIQUE (user_id, message_id);


--
-- Name: ai_policy_versions uq_ai_policy_user_version; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions
    ADD CONSTRAINT uq_ai_policy_user_version UNIQUE (user_id, version);


--
-- Name: ai_prompt_versions uq_ai_prompt_user_version; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions
    ADD CONSTRAINT uq_ai_prompt_user_version UNIQUE (user_id, version);


--
-- Name: ai_tenant_budgets uq_ai_tenant_budgets_tenant_period; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets
    ADD CONSTRAINT uq_ai_tenant_budgets_tenant_period UNIQUE (tenant_id, budget_period);


--
-- Name: ai_tenant_controls uq_ai_tenant_controls_tenant_id; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls
    ADD CONSTRAINT uq_ai_tenant_controls_tenant_id UNIQUE (tenant_id);


--
-- Name: campaign_groups uq_campaign_group_campaign_jid; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups
    ADD CONSTRAINT uq_campaign_group_campaign_jid UNIQUE (campaign_id, group_jid);


--
-- Name: campaign_targets uq_campaign_target; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets
    ADD CONSTRAINT uq_campaign_target UNIQUE (campaign_id, target_id);


--
-- Name: collection_targets uq_collection_target; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets
    ADD CONSTRAINT uq_collection_target UNIQUE (collection_id, target_id);


--
-- Name: collections uq_collections_instance_name; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections
    ADD CONSTRAINT uq_collections_instance_name UNIQUE (whatsapp_instance_id, name);


--
-- Name: contact_campaign_progress uq_contact_campaign_progress; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress
    ADD CONSTRAINT uq_contact_campaign_progress UNIQUE (campaign_id, contact_id);


--
-- Name: contacts uq_contacts_tenant_external; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts
    ADD CONSTRAINT uq_contacts_tenant_external UNIQUE (user_id, external_id);


--
-- Name: conversations uq_conversations_tenant_contact; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations
    ADD CONSTRAINT uq_conversations_tenant_contact UNIQUE (user_id, contact_id);


--
-- Name: group_invitations uq_group_invitations_campaign_contact; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations
    ADD CONSTRAINT uq_group_invitations_campaign_contact UNIQUE (campaign_id, contact_id);


--
-- Name: recipient_risk_profiles uq_recipient_risk_profiles_user_jid; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles
    ADD CONSTRAINT uq_recipient_risk_profiles_user_jid UNIQUE (user_id, recipient_jid);


--
-- Name: targets uq_targets_instance_external_id; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets
    ADD CONSTRAINT uq_targets_instance_external_id UNIQUE (whatsapp_instance_id, external_id);


--
-- Name: user_usage_daily uq_user_usage_daily_user_date; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily
    ADD CONSTRAINT uq_user_usage_daily_user_date UNIQUE (user_id, usage_date);


--
-- Name: user_usage_monthly uq_user_usage_monthly_user_month; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly
    ADD CONSTRAINT uq_user_usage_monthly_user_month UNIQUE (user_id, usage_month);


--
-- Name: usage_events usage_events_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events
    ADD CONSTRAINT usage_events_pkey PRIMARY KEY (id);


--
-- Name: user_subscriptions user_subscriptions_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_subscriptions
    ADD CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: user_usage_daily user_usage_daily_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily
    ADD CONSTRAINT user_usage_daily_pkey PRIMARY KEY (id);


--
-- Name: user_usage_monthly user_usage_monthly_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly
    ADD CONSTRAINT user_usage_monthly_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_instance_snapshots whatsapp_instance_snapshots_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots
    ADD CONSTRAINT whatsapp_instance_snapshots_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_instances whatsapp_instances_pkey; Type: CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances
    ADD CONSTRAINT whatsapp_instances_pkey PRIMARY KEY (id);


--
-- Name: Chat_instanceId_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "Chat_instanceId_idx" ON evolution."Chat" USING btree ("instanceId");


--
-- Name: Chat_instanceId_remoteJid_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Chat_instanceId_remoteJid_key" ON evolution."Chat" USING btree ("instanceId", "remoteJid");


--
-- Name: Chat_remoteJid_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "Chat_remoteJid_idx" ON evolution."Chat" USING btree ("remoteJid");


--
-- Name: Chatwoot_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Chatwoot_instanceId_key" ON evolution."Chatwoot" USING btree ("instanceId");


--
-- Name: Contact_instanceId_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "Contact_instanceId_idx" ON evolution."Contact" USING btree ("instanceId");


--
-- Name: Contact_remoteJid_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "Contact_remoteJid_idx" ON evolution."Contact" USING btree ("remoteJid");


--
-- Name: Contact_remoteJid_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Contact_remoteJid_instanceId_key" ON evolution."Contact" USING btree ("remoteJid", "instanceId");


--
-- Name: DifySetting_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "DifySetting_instanceId_key" ON evolution."DifySetting" USING btree ("instanceId");


--
-- Name: EvoaiSetting_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "EvoaiSetting_instanceId_key" ON evolution."EvoaiSetting" USING btree ("instanceId");


--
-- Name: EvolutionBotSetting_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "EvolutionBotSetting_instanceId_key" ON evolution."EvolutionBotSetting" USING btree ("instanceId");


--
-- Name: FlowiseSetting_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "FlowiseSetting_instanceId_key" ON evolution."FlowiseSetting" USING btree ("instanceId");


--
-- Name: Instance_name_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Instance_name_key" ON evolution."Instance" USING btree (name);


--
-- Name: IsOnWhatsapp_remoteJid_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "IsOnWhatsapp_remoteJid_key" ON evolution."IsOnWhatsapp" USING btree ("remoteJid");


--
-- Name: Kafka_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Kafka_instanceId_key" ON evolution."Kafka" USING btree ("instanceId");


--
-- Name: Label_labelId_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Label_labelId_instanceId_key" ON evolution."Label" USING btree ("labelId", "instanceId");


--
-- Name: Media_messageId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Media_messageId_key" ON evolution."Media" USING btree ("messageId");


--
-- Name: MessageUpdate_instanceId_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "MessageUpdate_instanceId_idx" ON evolution."MessageUpdate" USING btree ("instanceId");


--
-- Name: MessageUpdate_messageId_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "MessageUpdate_messageId_idx" ON evolution."MessageUpdate" USING btree ("messageId");


--
-- Name: Message_instanceId_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "Message_instanceId_idx" ON evolution."Message" USING btree ("instanceId");


--
-- Name: Message_instance_status_remotejid_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "Message_instance_status_remotejid_idx" ON evolution."Message" USING btree ("instanceId", status, ((key ->> 'remoteJid'::text)), (((key ->> 'fromMe'::text))::boolean));


--
-- Name: N8nSetting_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "N8nSetting_instanceId_key" ON evolution."N8nSetting" USING btree ("instanceId");


--
-- Name: Nats_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Nats_instanceId_key" ON evolution."Nats" USING btree ("instanceId");


--
-- Name: OpenaiCreds_apiKey_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "OpenaiCreds_apiKey_key" ON evolution."OpenaiCreds" USING btree ("apiKey");


--
-- Name: OpenaiCreds_name_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "OpenaiCreds_name_key" ON evolution."OpenaiCreds" USING btree (name);


--
-- Name: OpenaiSetting_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "OpenaiSetting_instanceId_key" ON evolution."OpenaiSetting" USING btree ("instanceId");


--
-- Name: OpenaiSetting_openaiCredsId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "OpenaiSetting_openaiCredsId_key" ON evolution."OpenaiSetting" USING btree ("openaiCredsId");


--
-- Name: Proxy_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Proxy_instanceId_key" ON evolution."Proxy" USING btree ("instanceId");


--
-- Name: Pusher_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Pusher_instanceId_key" ON evolution."Pusher" USING btree ("instanceId");


--
-- Name: Rabbitmq_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Rabbitmq_instanceId_key" ON evolution."Rabbitmq" USING btree ("instanceId");


--
-- Name: Session_sessionId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Session_sessionId_key" ON evolution."Session" USING btree ("sessionId");


--
-- Name: Setting_instanceId_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "Setting_instanceId_idx" ON evolution."Setting" USING btree ("instanceId");


--
-- Name: Setting_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Setting_instanceId_key" ON evolution."Setting" USING btree ("instanceId");


--
-- Name: Sqs_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Sqs_instanceId_key" ON evolution."Sqs" USING btree ("instanceId");


--
-- Name: Template_name_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Template_name_key" ON evolution."Template" USING btree (name);


--
-- Name: Template_templateId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Template_templateId_key" ON evolution."Template" USING btree ("templateId");


--
-- Name: TypebotSetting_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "TypebotSetting_instanceId_key" ON evolution."TypebotSetting" USING btree ("instanceId");


--
-- Name: Webhook_instanceId_idx; Type: INDEX; Schema: evolution; Owner: -
--

CREATE INDEX "Webhook_instanceId_idx" ON evolution."Webhook" USING btree ("instanceId");


--
-- Name: Webhook_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Webhook_instanceId_key" ON evolution."Webhook" USING btree ("instanceId");


--
-- Name: Websocket_instanceId_key; Type: INDEX; Schema: evolution; Owner: -
--

CREATE UNIQUE INDEX "Websocket_instanceId_key" ON evolution."Websocket" USING btree ("instanceId");


--
-- Name: idx_billing_cycles_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_billing_cycles_dates ON public.billing_cycles USING btree (router_id, interface_name, cycle_start, cycle_end);


--
-- Name: idx_billing_cycles_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_billing_cycles_lookup ON public.billing_cycles USING btree (router_id, interface_name, status);


--
-- Name: idx_hotspot_alert; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hotspot_alert ON public.hotspot_user_telemetry USING btree (alert_tier, recorded_at DESC) WHERE ((alert_tier)::text <> 'NORMAL'::text);


--
-- Name: idx_hotspot_mac; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hotspot_mac ON public.hotspot_user_telemetry USING btree (mac_address) WHERE (mac_address IS NOT NULL);


--
-- Name: idx_hotspot_router_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hotspot_router_time ON public.hotspot_user_telemetry USING btree (router_id, recorded_at DESC);


--
-- Name: idx_hotspot_user_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hotspot_user_time ON public.hotspot_user_telemetry USING btree (user_name, recorded_at DESC);


--
-- Name: idx_mikrotik_quotas_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mikrotik_quotas_active ON public.mikrotik_wan_quotas USING btree (router_id, is_active);


--
-- Name: idx_mikrotik_readings_received_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mikrotik_readings_received_at ON public.mikrotik_wan_readings USING btree (received_at DESC);


--
-- Name: idx_mikrotik_readings_router_received; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mikrotik_readings_router_received ON public.mikrotik_wan_readings USING btree (router_id, received_at DESC);


--
-- Name: idx_mikrotik_usage_reading_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mikrotik_usage_reading_id ON public.mikrotik_wan_usage USING btree (reading_id);


--
-- Name: idx_mikrotik_usage_router_usage_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mikrotik_usage_router_usage_at ON public.mikrotik_wan_usage USING btree (router_id, usage_at DESC);


--
-- Name: idx_mikrotik_usage_usage_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mikrotik_usage_usage_at ON public.mikrotik_wan_usage USING btree (usage_at DESC);


--
-- Name: idx_mikrotik_wan_readings_router_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mikrotik_wan_readings_router_time ON public.mikrotik_wan_readings USING btree (router_id, received_at DESC);


--
-- Name: idx_mikrotik_wan_usage_router_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mikrotik_wan_usage_router_time ON public.mikrotik_wan_usage USING btree (router_id, usage_at DESC);


--
-- Name: idx_quota_allocations_cycle; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quota_allocations_cycle ON public.quota_allocations USING btree (billing_cycle_id);


--
-- Name: idx_quota_allocations_router_iface; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quota_allocations_router_iface ON public.quota_allocations USING btree (router_id, interface_name, effective_at);


--
-- Name: idx_wan_control_actions_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wan_control_actions_created ON public.wan_control_actions USING btree (created_at DESC);


--
-- Name: idx_wan_control_actions_router; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wan_control_actions_router ON public.wan_control_actions USING btree (router_id, interface_name, status);


--
-- Name: idx_wan_operational_state_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wan_operational_state_lookup ON public.wan_operational_state USING btree (router_id, interface_name, current_state);


--
-- Name: idx_wan_quality_probed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wan_quality_probed_at ON public.mikrotik_wan_quality USING btree (probed_at DESC);


--
-- Name: idx_wan_quality_router_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wan_quality_router_time ON public.mikrotik_wan_quality USING btree (router_id, interface_name, probed_at DESC);


--
-- Name: ix_ai_action_idempotency_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_conversation_id ON public.ai_action_idempotency USING btree (conversation_id);


--
-- Name: ix_ai_action_idempotency_execution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_execution_id ON public.ai_action_idempotency USING btree (execution_id);


--
-- Name: ix_ai_action_idempotency_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_ai_action_idempotency_idempotency_key ON public.ai_action_idempotency USING btree (idempotency_key);


--
-- Name: ix_ai_action_idempotency_inbound_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_inbound_message_id ON public.ai_action_idempotency USING btree (inbound_message_id);


--
-- Name: ix_ai_action_idempotency_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_state ON public.ai_action_idempotency USING btree (state);


--
-- Name: ix_ai_action_idempotency_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_tenant_id ON public.ai_action_idempotency USING btree (tenant_id);


--
-- Name: ix_ai_anomalies_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_anomalies_user_created ON public.ai_anomalies USING btree (user_id, created_at);


--
-- Name: ix_ai_budget_reservations_execution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_execution_id ON public.ai_budget_reservations USING btree (execution_id);


--
-- Name: ix_ai_budget_reservations_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_expires_at ON public.ai_budget_reservations USING btree (expires_at);


--
-- Name: ix_ai_budget_reservations_reservation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_ai_budget_reservations_reservation_id ON public.ai_budget_reservations USING btree (reservation_id);


--
-- Name: ix_ai_budget_reservations_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_status ON public.ai_budget_reservations USING btree (status);


--
-- Name: ix_ai_budget_reservations_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_tenant_id ON public.ai_budget_reservations USING btree (tenant_id);


--
-- Name: ix_ai_budget_reservations_tenant_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_tenant_status ON public.ai_budget_reservations USING btree (tenant_id, status);


--
-- Name: ix_ai_budget_reservations_trace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_trace_id ON public.ai_budget_reservations USING btree (trace_id);


--
-- Name: ix_ai_configurations_mode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_configurations_mode ON public.ai_configurations USING btree (mode);


--
-- Name: ix_ai_configurations_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_configurations_user_id ON public.ai_configurations USING btree (user_id);


--
-- Name: ix_ai_control_audit_events_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_control_audit_events_event_type ON public.ai_control_audit_events USING btree (event_type);


--
-- Name: ix_ai_control_audit_events_tenant_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_control_audit_events_tenant_created ON public.ai_control_audit_events USING btree (tenant_id, created_at);


--
-- Name: ix_ai_control_audit_events_trace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_control_audit_events_trace_id ON public.ai_control_audit_events USING btree (trace_id);


--
-- Name: ix_ai_decisions_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_decisions_action ON public.ai_decisions USING btree (action);


--
-- Name: ix_ai_decisions_ai_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_decisions_ai_job_id ON public.ai_decisions USING btree (ai_job_id);


--
-- Name: ix_ai_decisions_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_decisions_category ON public.ai_decisions USING btree (category);


--
-- Name: ix_ai_decisions_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_decisions_conversation_id ON public.ai_decisions USING btree (conversation_id);


--
-- Name: ix_ai_decisions_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_decisions_message_id ON public.ai_decisions USING btree (message_id);


--
-- Name: ix_ai_decisions_trace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_decisions_trace_id ON public.ai_decisions USING btree (trace_id);


--
-- Name: ix_ai_decisions_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_decisions_user_created ON public.ai_decisions USING btree (user_id, created_at);


--
-- Name: ix_ai_decisions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_decisions_user_id ON public.ai_decisions USING btree (user_id);


--
-- Name: ix_ai_execution_traces_ai_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_execution_traces_ai_job_id ON public.ai_execution_traces USING btree (ai_job_id);


--
-- Name: ix_ai_execution_traces_trace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_ai_execution_traces_trace_id ON public.ai_execution_traces USING btree (trace_id);


--
-- Name: ix_ai_execution_traces_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_execution_traces_user_created ON public.ai_execution_traces USING btree (user_id, created_at);


--
-- Name: ix_ai_jobs_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_jobs_conversation_id ON public.ai_jobs USING btree (conversation_id);


--
-- Name: ix_ai_jobs_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_jobs_message_id ON public.ai_jobs USING btree (message_id);


--
-- Name: ix_ai_jobs_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_jobs_status ON public.ai_jobs USING btree (status);


--
-- Name: ix_ai_jobs_status_locked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_jobs_status_locked_at ON public.ai_jobs USING btree (status, locked_at);


--
-- Name: ix_ai_jobs_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_jobs_user_id ON public.ai_jobs USING btree (user_id);


--
-- Name: ix_ai_prompt_versions_user_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_prompt_versions_user_status ON public.ai_prompt_versions USING btree (user_id, status);


--
-- Name: ix_ai_tenant_budgets_budget_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_tenant_budgets_budget_period ON public.ai_tenant_budgets USING btree (budget_period);


--
-- Name: ix_ai_tenant_budgets_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_tenant_budgets_tenant_id ON public.ai_tenant_budgets USING btree (tenant_id);


--
-- Name: ix_ai_tenant_controls_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ai_tenant_controls_tenant_id ON public.ai_tenant_controls USING btree (tenant_id);


--
-- Name: ix_campaign_groups_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_groups_campaign_id ON public.campaign_groups USING btree (campaign_id);


--
-- Name: ix_campaign_groups_campaign_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_groups_campaign_status ON public.campaign_groups USING btree (campaign_id, status);


--
-- Name: ix_campaign_groups_group_jid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_groups_group_jid ON public.campaign_groups USING btree (group_jid);


--
-- Name: ix_campaign_groups_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_groups_status ON public.campaign_groups USING btree (status);


--
-- Name: ix_campaign_metric_snapshots_ts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_metric_snapshots_ts ON public.campaign_metric_snapshots USING btree ("timestamp");


--
-- Name: ix_campaign_rebalance_events_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_rebalance_events_campaign_id ON public.campaign_rebalance_events USING btree (campaign_id);


--
-- Name: ix_campaign_rebalance_events_destination_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_rebalance_events_destination_instance_id ON public.campaign_rebalance_events USING btree (destination_instance_id);


--
-- Name: ix_campaign_rebalance_events_source_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_rebalance_events_source_instance_id ON public.campaign_rebalance_events USING btree (source_instance_id);


--
-- Name: ix_campaign_safety_settings_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_safety_settings_user_id ON public.campaign_safety_settings USING btree (user_id);


--
-- Name: ix_campaign_safety_settings_whatsapp_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_campaign_safety_settings_whatsapp_instance_id ON public.campaign_safety_settings USING btree (whatsapp_instance_id);


--
-- Name: ix_campaign_targets_assigned_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_targets_assigned_instance_id ON public.campaign_targets USING btree (assigned_instance_id);


--
-- Name: ix_campaign_targets_campaign_id_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_targets_campaign_id_status ON public.campaign_targets USING btree (campaign_id, status);


--
-- Name: ix_campaign_targets_campaign_id_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_targets_campaign_id_target_id ON public.campaign_targets USING btree (campaign_id, target_id);


--
-- Name: ix_campaign_targets_delivery_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_targets_delivery_status ON public.campaign_targets USING btree (delivery_status);


--
-- Name: ix_campaign_targets_lease_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_targets_lease_token ON public.campaign_targets USING btree (lease_token);


--
-- Name: ix_campaign_targets_provider_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_targets_provider_message_id ON public.campaign_targets USING btree (provider_message_id);


--
-- Name: ix_campaign_targets_status_next_attempt_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_targets_status_next_attempt_at ON public.campaign_targets USING btree (status, next_attempt_at);


--
-- Name: ix_campaign_targets_status_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaign_targets_status_updated_at ON public.campaign_targets USING btree (status, updated_at);


--
-- Name: ix_campaigns_campaign_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaigns_campaign_type ON public.campaigns USING btree (campaign_type);


--
-- Name: ix_campaigns_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaigns_user_id ON public.campaigns USING btree (user_id);


--
-- Name: ix_campaigns_whatsapp_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_campaigns_whatsapp_instance_id ON public.campaigns USING btree (whatsapp_instance_id);


--
-- Name: ix_ccp_followup_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ccp_followup_due ON public.contact_campaign_progress USING btree (campaign_id, state, next_followup_at);


--
-- Name: ix_collection_targets_collection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_collection_targets_collection_id ON public.collection_targets USING btree (collection_id);


--
-- Name: ix_collection_targets_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_collection_targets_target_id ON public.collection_targets USING btree (target_id);


--
-- Name: ix_collections_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_collections_name ON public.collections USING btree (name);


--
-- Name: ix_collections_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_collections_user_id ON public.collections USING btree (user_id);


--
-- Name: ix_collections_whatsapp_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_collections_whatsapp_instance_id ON public.collections USING btree (whatsapp_instance_id);


--
-- Name: ix_contact_campaign_progress_allocated_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_allocated_group_id ON public.contact_campaign_progress USING btree (allocated_group_id);


--
-- Name: ix_contact_campaign_progress_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_campaign_id ON public.contact_campaign_progress USING btree (campaign_id);


--
-- Name: ix_contact_campaign_progress_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_contact_id ON public.contact_campaign_progress USING btree (contact_id);


--
-- Name: ix_contact_campaign_progress_followup_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_followup_stage ON public.contact_campaign_progress USING btree (followup_stage);


--
-- Name: ix_contact_campaign_progress_followup_stop_reason; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_followup_stop_reason ON public.contact_campaign_progress USING btree (followup_stop_reason);


--
-- Name: ix_contact_campaign_progress_next_followup_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_next_followup_at ON public.contact_campaign_progress USING btree (next_followup_at);


--
-- Name: ix_contact_campaign_progress_next_membership_check_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_next_membership_check_at ON public.contact_campaign_progress USING btree (next_membership_check_at);


--
-- Name: ix_contact_campaign_progress_opening_variant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_opening_variant_id ON public.contact_campaign_progress USING btree (opening_variant_id);


--
-- Name: ix_contact_campaign_progress_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_state ON public.contact_campaign_progress USING btree (state);


--
-- Name: ix_contact_campaign_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contact_campaign_state ON public.contact_campaign_progress USING btree (campaign_id, state);


--
-- Name: ix_contacts_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contacts_external_id ON public.contacts USING btree (external_id);


--
-- Name: ix_contacts_phone_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contacts_phone_number ON public.contacts USING btree (phone_number);


--
-- Name: ix_contacts_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contacts_provider ON public.contacts USING btree (provider);


--
-- Name: ix_contacts_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contacts_user_id ON public.contacts USING btree (user_id);


--
-- Name: ix_contacts_whatsapp_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contacts_whatsapp_instance_id ON public.contacts USING btree (whatsapp_instance_id);


--
-- Name: ix_conversations_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_conversations_contact_id ON public.conversations USING btree (contact_id);


--
-- Name: ix_conversations_conversation_mode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_conversations_conversation_mode ON public.conversations USING btree (conversation_mode);


--
-- Name: ix_conversations_external_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_conversations_external_thread_id ON public.conversations USING btree (external_thread_id);


--
-- Name: ix_conversations_last_message_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_conversations_last_message_at ON public.conversations USING btree (last_message_at);


--
-- Name: ix_conversations_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_conversations_provider ON public.conversations USING btree (provider);


--
-- Name: ix_conversations_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_conversations_status ON public.conversations USING btree (status);


--
-- Name: ix_conversations_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_conversations_user_id ON public.conversations USING btree (user_id);


--
-- Name: ix_conversations_whatsapp_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_conversations_whatsapp_instance_id ON public.conversations USING btree (whatsapp_instance_id);


--
-- Name: ix_daily_system_reports_date_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_daily_system_reports_date_type ON public.daily_system_reports USING btree (report_date, report_type);


--
-- Name: ix_dead_letter_targets_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dead_letter_targets_campaign_id ON public.dead_letter_targets USING btree (campaign_id);


--
-- Name: ix_dead_letter_targets_campaign_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dead_letter_targets_campaign_target_id ON public.dead_letter_targets USING btree (campaign_target_id);


--
-- Name: ix_dead_letter_targets_error_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dead_letter_targets_error_code ON public.dead_letter_targets USING btree (error_code);


--
-- Name: ix_dead_letter_targets_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dead_letter_targets_target_id ON public.dead_letter_targets USING btree (target_id);


--
-- Name: ix_dead_letter_targets_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dead_letter_targets_user_id ON public.dead_letter_targets USING btree (user_id);


--
-- Name: ix_delivery_idempotency_camp_target_attempt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_delivery_idempotency_camp_target_attempt ON public.delivery_idempotency USING btree (campaign_id, campaign_target_id, attempt);


--
-- Name: ix_delivery_idempotency_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_delivery_idempotency_campaign_id ON public.delivery_idempotency USING btree (campaign_id);


--
-- Name: ix_delivery_idempotency_campaign_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_delivery_idempotency_campaign_target ON public.delivery_idempotency USING btree (campaign_id, campaign_target_id);


--
-- Name: ix_delivery_idempotency_campaign_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_delivery_idempotency_campaign_target_id ON public.delivery_idempotency USING btree (campaign_target_id);


--
-- Name: ix_delivery_idempotency_external_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_delivery_idempotency_external_reference ON public.delivery_idempotency USING btree (external_reference);


--
-- Name: ix_delivery_idempotency_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_delivery_idempotency_idempotency_key ON public.delivery_idempotency USING btree (idempotency_key);


--
-- Name: ix_delivery_idempotency_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_delivery_idempotency_status ON public.delivery_idempotency USING btree (status);


--
-- Name: ix_delivery_idempotency_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_delivery_idempotency_target_id ON public.delivery_idempotency USING btree (target_id);


--
-- Name: ix_delivery_idempotency_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_delivery_idempotency_user_id ON public.delivery_idempotency USING btree (user_id);


--
-- Name: ix_execution_logs_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_execution_logs_campaign_id ON public.execution_logs USING btree (campaign_id);


--
-- Name: ix_execution_logs_campaign_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_execution_logs_campaign_target_id ON public.execution_logs USING btree (campaign_target_id);


--
-- Name: ix_execution_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_execution_logs_created_at ON public.execution_logs USING btree (created_at);


--
-- Name: ix_group_invitations_campaign_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_group_invitations_campaign_group_id ON public.group_invitations USING btree (campaign_group_id);


--
-- Name: ix_group_invitations_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_group_invitations_campaign_id ON public.group_invitations USING btree (campaign_id);


--
-- Name: ix_group_invitations_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_group_invitations_contact_id ON public.group_invitations USING btree (contact_id);


--
-- Name: ix_group_invitations_group_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_group_invitations_group_status ON public.group_invitations USING btree (campaign_group_id, status);


--
-- Name: ix_group_invitations_provider_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_group_invitations_provider_message_id ON public.group_invitations USING btree (provider_message_id);


--
-- Name: ix_group_invitations_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_group_invitations_status ON public.group_invitations USING btree (status);


--
-- Name: ix_instance_pacing_states_whatsapp_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_instance_pacing_states_whatsapp_instance_id ON public.instance_pacing_states USING btree (whatsapp_instance_id);


--
-- Name: ix_instance_pacing_transitions_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_instance_pacing_transitions_created_at ON public.instance_pacing_transitions USING btree (created_at);


--
-- Name: ix_instance_pacing_transitions_whatsapp_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_instance_pacing_transitions_whatsapp_instance_id ON public.instance_pacing_transitions USING btree (whatsapp_instance_id);


--
-- Name: ix_instance_rebalance_states_cooldown_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_instance_rebalance_states_cooldown_until ON public.instance_rebalance_states USING btree (cooldown_until);


--
-- Name: ix_instance_rebalance_states_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_instance_rebalance_states_state ON public.instance_rebalance_states USING btree (state);


--
-- Name: ix_instance_risk_profiles_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_instance_risk_profiles_instance_id ON public.instance_risk_profiles USING btree (instance_id);


--
-- Name: ix_instance_risk_profiles_risk_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_instance_risk_profiles_risk_state ON public.instance_risk_profiles USING btree (risk_state);


--
-- Name: ix_instance_state_audit_events_instance_ts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_instance_state_audit_events_instance_ts ON public.instance_state_audit_events USING btree (whatsapp_instance_id, "timestamp");


--
-- Name: ix_instance_state_audit_events_new_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_instance_state_audit_events_new_state ON public.instance_state_audit_events USING btree (new_state);


--
-- Name: ix_instance_state_audit_events_signal_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_instance_state_audit_events_signal_category ON public.instance_state_audit_events USING btree (signal_category);


--
-- Name: ix_instance_state_audit_events_user_ts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_instance_state_audit_events_user_ts ON public.instance_state_audit_events USING btree (user_id, "timestamp");


--
-- Name: ix_messages_client_message_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_client_message_key ON public.messages USING btree (client_message_key);


--
-- Name: ix_messages_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_contact_id ON public.messages USING btree (contact_id);


--
-- Name: ix_messages_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_conversation_id ON public.messages USING btree (conversation_id);


--
-- Name: ix_messages_direction; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_direction ON public.messages USING btree (direction);


--
-- Name: ix_messages_external_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_external_message_id ON public.messages USING btree (external_message_id);


--
-- Name: ix_messages_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_provider ON public.messages USING btree (provider);


--
-- Name: ix_messages_provider_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_provider_external_id ON public.messages USING btree (provider, external_message_id);


--
-- Name: ix_messages_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_status ON public.messages USING btree (status);


--
-- Name: ix_messages_user_client_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_user_client_key ON public.messages USING btree (user_id, client_message_key);


--
-- Name: ix_messages_user_conversation_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_user_conversation_created ON public.messages USING btree (user_id, conversation_id, created_at);


--
-- Name: ix_messages_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_user_id ON public.messages USING btree (user_id);


--
-- Name: ix_messages_whatsapp_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_messages_whatsapp_instance_id ON public.messages USING btree (whatsapp_instance_id);


--
-- Name: ix_quota_reservations_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_quota_reservations_campaign_id ON public.quota_reservations USING btree (campaign_id);


--
-- Name: ix_quota_reservations_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_quota_reservations_user_id ON public.quota_reservations USING btree (user_id);


--
-- Name: ix_recipient_risk_profiles_recipient_jid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_recipient_risk_profiles_recipient_jid ON public.recipient_risk_profiles USING btree (recipient_jid);


--
-- Name: ix_recipient_risk_profiles_risk_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_recipient_risk_profiles_risk_state ON public.recipient_risk_profiles USING btree (risk_state);


--
-- Name: ix_recipient_risk_profiles_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_recipient_risk_profiles_user_id ON public.recipient_risk_profiles USING btree (user_id);


--
-- Name: ix_refresh_tokens_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_refresh_tokens_family_id ON public.refresh_tokens USING btree (family_id);


--
-- Name: ix_refresh_tokens_token_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_refresh_tokens_token_hash ON public.refresh_tokens USING btree (token_hash);


--
-- Name: ix_refresh_tokens_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_refresh_tokens_user_id ON public.refresh_tokens USING btree (user_id);


--
-- Name: ix_risk_decisions_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_decisions_campaign_id ON public.risk_decisions USING btree (campaign_id);


--
-- Name: ix_risk_decisions_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_decisions_created_at ON public.risk_decisions USING btree (created_at);


--
-- Name: ix_risk_decisions_decision; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_decisions_decision ON public.risk_decisions USING btree (decision);


--
-- Name: ix_risk_decisions_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_decisions_instance_id ON public.risk_decisions USING btree (instance_id);


--
-- Name: ix_risk_decisions_recipient_jid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_decisions_recipient_jid ON public.risk_decisions USING btree (recipient_jid);


--
-- Name: ix_risk_decisions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_decisions_user_id ON public.risk_decisions USING btree (user_id);


--
-- Name: ix_risk_signals_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_signals_instance_id ON public.risk_signals USING btree (instance_id);


--
-- Name: ix_risk_signals_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_signals_occurred_at ON public.risk_signals USING btree (occurred_at);


--
-- Name: ix_risk_signals_recipient_jid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_signals_recipient_jid ON public.risk_signals USING btree (recipient_jid);


--
-- Name: ix_risk_signals_signal_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_signals_signal_type ON public.risk_signals USING btree (signal_type);


--
-- Name: ix_risk_signals_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_signals_user_id ON public.risk_signals USING btree (user_id);


--
-- Name: ix_risk_state_transitions_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_state_transitions_created_at ON public.risk_state_transitions USING btree (created_at);


--
-- Name: ix_risk_state_transitions_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_state_transitions_instance_id ON public.risk_state_transitions USING btree (instance_id);


--
-- Name: ix_risk_state_transitions_recipient_jid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_state_transitions_recipient_jid ON public.risk_state_transitions USING btree (recipient_jid);


--
-- Name: ix_risk_state_transitions_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_risk_state_transitions_scope ON public.risk_state_transitions USING btree (scope);


--
-- Name: ix_subscription_events_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_subscription_events_user_id ON public.subscription_events USING btree (user_id);


--
-- Name: ix_subscription_payments_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_subscription_payments_user_id ON public.subscription_payments USING btree (user_id);


--
-- Name: ix_system_metric_snapshots_ts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_system_metric_snapshots_ts ON public.system_metric_snapshots USING btree ("timestamp");


--
-- Name: ix_targets_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_targets_external_id ON public.targets USING btree (external_id);


--
-- Name: ix_targets_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_targets_user_id ON public.targets USING btree (user_id);


--
-- Name: ix_targets_whatsapp_instance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_targets_whatsapp_instance_id ON public.targets USING btree (whatsapp_instance_id);


--
-- Name: ix_usage_events_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_usage_events_campaign_id ON public.usage_events USING btree (campaign_id);


--
-- Name: ix_usage_events_delivery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_usage_events_delivery_id ON public.usage_events USING btree (delivery_id);


--
-- Name: ix_usage_events_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_usage_events_user_id ON public.usage_events USING btree (user_id);


--
-- Name: ix_user_subscriptions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_user_subscriptions_user_id ON public.user_subscriptions USING btree (user_id);


--
-- Name: ix_user_usage_daily_usage_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_usage_daily_usage_date ON public.user_usage_daily USING btree (usage_date);


--
-- Name: ix_user_usage_daily_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_usage_daily_user_id ON public.user_usage_daily USING btree (user_id);


--
-- Name: ix_user_usage_monthly_usage_month; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_usage_monthly_usage_month ON public.user_usage_monthly USING btree (usage_month);


--
-- Name: ix_user_usage_monthly_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_usage_monthly_user_id ON public.user_usage_monthly USING btree (user_id);


--
-- Name: ix_users_telegram_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_users_telegram_user_id ON public.users USING btree (telegram_user_id);


--
-- Name: ix_whatsapp_instance_snapshots_name_ts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_whatsapp_instance_snapshots_name_ts ON public.whatsapp_instance_snapshots USING btree (instance_name, "timestamp");


--
-- Name: ix_whatsapp_instances_instance_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_whatsapp_instances_instance_name ON public.whatsapp_instances USING btree (instance_name);


--
-- Name: ix_whatsapp_instances_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_whatsapp_instances_user_id ON public.whatsapp_instances USING btree (user_id);


--
-- Name: ix_ai_action_idempotency_conversation_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_conversation_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency USING btree (conversation_id);


--
-- Name: ix_ai_action_idempotency_execution_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_execution_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency USING btree (execution_id);


--
-- Name: ix_ai_action_idempotency_inbound_message_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_inbound_message_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency USING btree (inbound_message_id);


--
-- Name: ix_ai_action_idempotency_key; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_ai_action_idempotency_key ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency USING btree (idempotency_key);


--
-- Name: ix_ai_action_idempotency_state; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_state ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency USING btree (state);


--
-- Name: ix_ai_action_idempotency_tenant_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_action_idempotency_tenant_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency USING btree (tenant_id);


--
-- Name: ix_ai_anomalies_user_created; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_anomalies_user_created ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies USING btree (user_id, created_at);


--
-- Name: ix_ai_anomalies_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_anomalies_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies USING btree (user_id);


--
-- Name: ix_ai_budget_reservations_execution_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_execution_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations USING btree (execution_id);


--
-- Name: ix_ai_budget_reservations_expires_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_expires_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations USING btree (expires_at);


--
-- Name: ix_ai_budget_reservations_reservation_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_ai_budget_reservations_reservation_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations USING btree (reservation_id);


--
-- Name: ix_ai_budget_reservations_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations USING btree (status);


--
-- Name: ix_ai_budget_reservations_tenant_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_tenant_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations USING btree (tenant_id);


--
-- Name: ix_ai_budget_reservations_tenant_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_tenant_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations USING btree (tenant_id, status);


--
-- Name: ix_ai_budget_reservations_trace_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_budget_reservations_trace_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations USING btree (trace_id);


--
-- Name: ix_ai_circuit_breakers_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_circuit_breakers_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers USING btree (user_id);


--
-- Name: ix_ai_configurations_mode; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_configurations_mode ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations USING btree (mode);


--
-- Name: ix_ai_configurations_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_configurations_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations USING btree (user_id);


--
-- Name: ix_ai_control_audit_events_actor_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_control_audit_events_actor_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events USING btree (actor_id);


--
-- Name: ix_ai_control_audit_events_event_type; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_control_audit_events_event_type ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events USING btree (event_type);


--
-- Name: ix_ai_control_audit_events_tenant_created; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_control_audit_events_tenant_created ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events USING btree (tenant_id, created_at);


--
-- Name: ix_ai_control_audit_events_tenant_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_control_audit_events_tenant_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events USING btree (tenant_id);


--
-- Name: ix_ai_control_audit_events_trace_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_control_audit_events_trace_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events USING btree (trace_id);


--
-- Name: ix_ai_decisions_action; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_decisions_action ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions USING btree (action);


--
-- Name: ix_ai_decisions_ai_job_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_decisions_ai_job_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions USING btree (ai_job_id);


--
-- Name: ix_ai_decisions_category; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_decisions_category ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions USING btree (category);


--
-- Name: ix_ai_decisions_conversation_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_decisions_conversation_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions USING btree (conversation_id);


--
-- Name: ix_ai_decisions_message_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_decisions_message_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions USING btree (message_id);


--
-- Name: ix_ai_decisions_trace_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_decisions_trace_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions USING btree (trace_id);


--
-- Name: ix_ai_decisions_user_created; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_decisions_user_created ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions USING btree (user_id, created_at);


--
-- Name: ix_ai_decisions_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_decisions_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions USING btree (user_id);


--
-- Name: ix_ai_execution_traces_ai_job_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_execution_traces_ai_job_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces USING btree (ai_job_id);


--
-- Name: ix_ai_execution_traces_conversation_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_execution_traces_conversation_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces USING btree (conversation_id);


--
-- Name: ix_ai_execution_traces_message_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_execution_traces_message_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces USING btree (message_id);


--
-- Name: ix_ai_execution_traces_trace_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_ai_execution_traces_trace_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces USING btree (trace_id);


--
-- Name: ix_ai_execution_traces_user_created; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_execution_traces_user_created ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces USING btree (user_id, created_at);


--
-- Name: ix_ai_execution_traces_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_execution_traces_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces USING btree (user_id);


--
-- Name: ix_ai_jobs_conversation_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_jobs_conversation_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs USING btree (conversation_id);


--
-- Name: ix_ai_jobs_message_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_jobs_message_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs USING btree (message_id);


--
-- Name: ix_ai_jobs_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_jobs_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs USING btree (status);


--
-- Name: ix_ai_jobs_status_locked_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_jobs_status_locked_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs USING btree (status, locked_at);


--
-- Name: ix_ai_jobs_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_jobs_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs USING btree (user_id);


--
-- Name: ix_ai_knowledge_items_knowledge_type; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_knowledge_items_knowledge_type ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items USING btree (knowledge_type);


--
-- Name: ix_ai_knowledge_items_user_active; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_knowledge_items_user_active ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items USING btree (user_id, is_active);


--
-- Name: ix_ai_knowledge_items_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_knowledge_items_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items USING btree (user_id);


--
-- Name: ix_ai_knowledge_items_user_type; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_knowledge_items_user_type ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items USING btree (user_id, knowledge_type);


--
-- Name: ix_ai_policy_versions_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_policy_versions_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions USING btree (user_id);


--
-- Name: ix_ai_prompt_versions_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_prompt_versions_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions USING btree (user_id);


--
-- Name: ix_ai_prompt_versions_user_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_prompt_versions_user_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions USING btree (user_id, status);


--
-- Name: ix_ai_tenant_budgets_budget_period; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_tenant_budgets_budget_period ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets USING btree (budget_period);


--
-- Name: ix_ai_tenant_budgets_tenant_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_tenant_budgets_tenant_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets USING btree (tenant_id);


--
-- Name: ix_ai_tenant_controls_tenant_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_ai_tenant_controls_tenant_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls USING btree (tenant_id);


--
-- Name: ix_campaign_groups_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_groups_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups USING btree (campaign_id);


--
-- Name: ix_campaign_groups_campaign_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_groups_campaign_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups USING btree (campaign_id, status);


--
-- Name: ix_campaign_groups_group_jid; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_groups_group_jid ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups USING btree (group_jid);


--
-- Name: ix_campaign_groups_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_groups_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups USING btree (status);


--
-- Name: ix_campaign_metric_snapshots_instance_name; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_metric_snapshots_instance_name ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots USING btree (instance_name);


--
-- Name: ix_campaign_metric_snapshots_timestamp; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_metric_snapshots_timestamp ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots USING btree ("timestamp");


--
-- Name: ix_campaign_metric_snapshots_ts; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_metric_snapshots_ts ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_metric_snapshots USING btree ("timestamp");


--
-- Name: ix_campaign_rebalance_events_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_rebalance_events_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events USING btree (campaign_id);


--
-- Name: ix_campaign_rebalance_events_destination_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_rebalance_events_destination_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events USING btree (destination_instance_id);


--
-- Name: ix_campaign_rebalance_events_source_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_rebalance_events_source_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events USING btree (source_instance_id);


--
-- Name: ix_campaign_safety_settings_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_safety_settings_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings USING btree (user_id);


--
-- Name: ix_campaign_safety_settings_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_campaign_safety_settings_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings USING btree (whatsapp_instance_id);


--
-- Name: ix_campaign_targets_assigned_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_targets_assigned_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets USING btree (assigned_instance_id);


--
-- Name: ix_campaign_targets_campaign_id_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_targets_campaign_id_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets USING btree (campaign_id, status);


--
-- Name: ix_campaign_targets_campaign_id_target_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_targets_campaign_id_target_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets USING btree (campaign_id, target_id);


--
-- Name: ix_campaign_targets_lease_token; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_targets_lease_token ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets USING btree (lease_token);


--
-- Name: ix_campaign_targets_provider_message_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_targets_provider_message_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets USING btree (provider_message_id);


--
-- Name: ix_campaign_targets_status_next_attempt_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_targets_status_next_attempt_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets USING btree (status, next_attempt_at);


--
-- Name: ix_campaign_targets_status_updated_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaign_targets_status_updated_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets USING btree (status, updated_at);


--
-- Name: ix_campaigns_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaigns_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns USING btree (user_id);


--
-- Name: ix_campaigns_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_campaigns_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns USING btree (whatsapp_instance_id);


--
-- Name: ix_collection_targets_collection_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_collection_targets_collection_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets USING btree (collection_id);


--
-- Name: ix_collection_targets_target_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_collection_targets_target_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets USING btree (target_id);


--
-- Name: ix_collections_name; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_collections_name ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections USING btree (name);


--
-- Name: ix_collections_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_collections_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections USING btree (user_id);


--
-- Name: ix_collections_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_collections_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections USING btree (whatsapp_instance_id);


--
-- Name: ix_contact_campaign_progress_allocated_group_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_allocated_group_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress USING btree (allocated_group_id);


--
-- Name: ix_contact_campaign_progress_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress USING btree (campaign_id);


--
-- Name: ix_contact_campaign_progress_contact_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_contact_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress USING btree (contact_id);


--
-- Name: ix_contact_campaign_progress_state; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contact_campaign_progress_state ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress USING btree (state);


--
-- Name: ix_contact_campaign_state; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contact_campaign_state ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress USING btree (campaign_id, state);


--
-- Name: ix_contacts_external_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contacts_external_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts USING btree (external_id);


--
-- Name: ix_contacts_phone_number; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contacts_phone_number ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts USING btree (phone_number);


--
-- Name: ix_contacts_provider; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contacts_provider ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts USING btree (provider);


--
-- Name: ix_contacts_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contacts_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts USING btree (user_id);


--
-- Name: ix_contacts_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_contacts_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts USING btree (whatsapp_instance_id);


--
-- Name: ix_conversations_contact_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_conversations_contact_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations USING btree (contact_id);


--
-- Name: ix_conversations_conversation_mode; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_conversations_conversation_mode ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations USING btree (conversation_mode);


--
-- Name: ix_conversations_external_thread_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_conversations_external_thread_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations USING btree (external_thread_id);


--
-- Name: ix_conversations_last_message_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_conversations_last_message_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations USING btree (last_message_at);


--
-- Name: ix_conversations_provider; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_conversations_provider ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations USING btree (provider);


--
-- Name: ix_conversations_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_conversations_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations USING btree (status);


--
-- Name: ix_conversations_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_conversations_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations USING btree (user_id);


--
-- Name: ix_conversations_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_conversations_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations USING btree (whatsapp_instance_id);


--
-- Name: ix_daily_system_reports_date_type; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_daily_system_reports_date_type ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.daily_system_reports USING btree (report_date, report_type);


--
-- Name: ix_daily_system_reports_report_date; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_daily_system_reports_report_date ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.daily_system_reports USING btree (report_date);


--
-- Name: ix_dead_letter_targets_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_dead_letter_targets_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets USING btree (campaign_id);


--
-- Name: ix_dead_letter_targets_campaign_target_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_dead_letter_targets_campaign_target_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets USING btree (campaign_target_id);


--
-- Name: ix_dead_letter_targets_error_code; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_dead_letter_targets_error_code ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets USING btree (error_code);


--
-- Name: ix_dead_letter_targets_target_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_dead_letter_targets_target_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets USING btree (target_id);


--
-- Name: ix_dead_letter_targets_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_dead_letter_targets_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets USING btree (user_id);


--
-- Name: ix_delivery_idempotency_camp_target_attempt; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_delivery_idempotency_camp_target_attempt ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency USING btree (campaign_id, campaign_target_id, attempt);


--
-- Name: ix_delivery_idempotency_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_delivery_idempotency_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency USING btree (campaign_id);


--
-- Name: ix_delivery_idempotency_campaign_target; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_delivery_idempotency_campaign_target ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency USING btree (campaign_id, campaign_target_id);


--
-- Name: ix_delivery_idempotency_campaign_target_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_delivery_idempotency_campaign_target_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency USING btree (campaign_target_id);


--
-- Name: ix_delivery_idempotency_external_reference; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_delivery_idempotency_external_reference ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency USING btree (external_reference);


--
-- Name: ix_delivery_idempotency_idempotency_key; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_delivery_idempotency_idempotency_key ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency USING btree (idempotency_key);


--
-- Name: ix_delivery_idempotency_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_delivery_idempotency_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency USING btree (status);


--
-- Name: ix_delivery_idempotency_target_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_delivery_idempotency_target_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency USING btree (target_id);


--
-- Name: ix_delivery_idempotency_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_delivery_idempotency_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency USING btree (user_id);


--
-- Name: ix_execution_logs_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_execution_logs_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs USING btree (campaign_id);


--
-- Name: ix_execution_logs_campaign_target_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_execution_logs_campaign_target_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs USING btree (campaign_target_id);


--
-- Name: ix_execution_logs_created_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_execution_logs_created_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs USING btree (created_at);


--
-- Name: ix_group_invitations_campaign_group_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_group_invitations_campaign_group_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations USING btree (campaign_group_id);


--
-- Name: ix_group_invitations_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_group_invitations_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations USING btree (campaign_id);


--
-- Name: ix_group_invitations_contact_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_group_invitations_contact_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations USING btree (contact_id);


--
-- Name: ix_group_invitations_group_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_group_invitations_group_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations USING btree (campaign_group_id, status);


--
-- Name: ix_group_invitations_idempotency_key; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_group_invitations_idempotency_key ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations USING btree (idempotency_key);


--
-- Name: ix_group_invitations_provider_message_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_group_invitations_provider_message_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations USING btree (provider_message_id);


--
-- Name: ix_group_invitations_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_group_invitations_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations USING btree (status);


--
-- Name: ix_instance_pacing_states_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_instance_pacing_states_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_states USING btree (whatsapp_instance_id);


--
-- Name: ix_instance_pacing_transitions_created_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_pacing_transitions_created_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions USING btree (created_at);


--
-- Name: ix_instance_pacing_transitions_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_pacing_transitions_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions USING btree (whatsapp_instance_id);


--
-- Name: ix_instance_rebalance_states_cooldown_until; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_rebalance_states_cooldown_until ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states USING btree (cooldown_until);


--
-- Name: ix_instance_rebalance_states_state; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_rebalance_states_state ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states USING btree (state);


--
-- Name: ix_instance_rebalance_states_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_instance_rebalance_states_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states USING btree (whatsapp_instance_id);


--
-- Name: ix_instance_risk_profiles_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_instance_risk_profiles_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles USING btree (instance_id);


--
-- Name: ix_instance_risk_profiles_risk_state; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_risk_profiles_risk_state ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles USING btree (risk_state);


--
-- Name: ix_instance_state_audit_events_new_state; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_state_audit_events_new_state ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events USING btree (new_state);


--
-- Name: ix_instance_state_audit_events_signal_category; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_state_audit_events_signal_category ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events USING btree (signal_category);


--
-- Name: ix_instance_state_audit_events_timestamp; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_state_audit_events_timestamp ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events USING btree ("timestamp");


--
-- Name: ix_instance_state_audit_events_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_state_audit_events_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events USING btree (user_id);


--
-- Name: ix_instance_state_audit_events_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_instance_state_audit_events_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events USING btree (whatsapp_instance_id);


--
-- Name: ix_messages_client_message_key; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_client_message_key ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (client_message_key);


--
-- Name: ix_messages_contact_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_contact_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (contact_id);


--
-- Name: ix_messages_conversation_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_conversation_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (conversation_id);


--
-- Name: ix_messages_direction; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_direction ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (direction);


--
-- Name: ix_messages_external_message_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_external_message_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (external_message_id);


--
-- Name: ix_messages_provider; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_provider ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (provider);


--
-- Name: ix_messages_provider_external_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_provider_external_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (provider, external_message_id);


--
-- Name: ix_messages_status; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_status ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (status);


--
-- Name: ix_messages_user_client_key; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_user_client_key ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (user_id, client_message_key);


--
-- Name: ix_messages_user_conversation_created; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_user_conversation_created ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (user_id, conversation_id, created_at);


--
-- Name: ix_messages_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (user_id);


--
-- Name: ix_messages_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_messages_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages USING btree (whatsapp_instance_id);


--
-- Name: ix_quota_reservations_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_quota_reservations_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations USING btree (campaign_id);


--
-- Name: ix_quota_reservations_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_quota_reservations_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations USING btree (user_id);


--
-- Name: ix_recipient_risk_profiles_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_recipient_risk_profiles_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles USING btree (instance_id);


--
-- Name: ix_recipient_risk_profiles_recipient_jid; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_recipient_risk_profiles_recipient_jid ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles USING btree (recipient_jid);


--
-- Name: ix_recipient_risk_profiles_risk_state; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_recipient_risk_profiles_risk_state ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles USING btree (risk_state);


--
-- Name: ix_recipient_risk_profiles_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_recipient_risk_profiles_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles USING btree (user_id);


--
-- Name: ix_refresh_tokens_family_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_refresh_tokens_family_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens USING btree (family_id);


--
-- Name: ix_refresh_tokens_token_hash; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_refresh_tokens_token_hash ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens USING btree (token_hash);


--
-- Name: ix_refresh_tokens_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_refresh_tokens_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens USING btree (user_id);


--
-- Name: ix_risk_decisions_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_decisions_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions USING btree (campaign_id);


--
-- Name: ix_risk_decisions_created_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_decisions_created_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions USING btree (created_at);


--
-- Name: ix_risk_decisions_decision; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_decisions_decision ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions USING btree (decision);


--
-- Name: ix_risk_decisions_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_decisions_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions USING btree (instance_id);


--
-- Name: ix_risk_decisions_recipient_jid; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_decisions_recipient_jid ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions USING btree (recipient_jid);


--
-- Name: ix_risk_decisions_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_decisions_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions USING btree (user_id);


--
-- Name: ix_risk_signals_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_signals_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals USING btree (instance_id);


--
-- Name: ix_risk_signals_occurred_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_signals_occurred_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals USING btree (occurred_at);


--
-- Name: ix_risk_signals_recipient_jid; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_signals_recipient_jid ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals USING btree (recipient_jid);


--
-- Name: ix_risk_signals_signal_type; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_signals_signal_type ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals USING btree (signal_type);


--
-- Name: ix_risk_signals_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_signals_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals USING btree (user_id);


--
-- Name: ix_risk_state_transitions_created_at; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_state_transitions_created_at ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions USING btree (created_at);


--
-- Name: ix_risk_state_transitions_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_state_transitions_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions USING btree (instance_id);


--
-- Name: ix_risk_state_transitions_recipient_jid; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_state_transitions_recipient_jid ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions USING btree (recipient_jid);


--
-- Name: ix_risk_state_transitions_scope; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_risk_state_transitions_scope ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions USING btree (scope);


--
-- Name: ix_subscription_events_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_subscription_events_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_events USING btree (user_id);


--
-- Name: ix_subscription_payments_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_subscription_payments_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_payments USING btree (user_id);


--
-- Name: ix_system_metric_snapshots_timestamp; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_system_metric_snapshots_timestamp ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.system_metric_snapshots USING btree ("timestamp");


--
-- Name: ix_system_metric_snapshots_ts; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_system_metric_snapshots_ts ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.system_metric_snapshots USING btree ("timestamp");


--
-- Name: ix_targets_external_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_targets_external_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets USING btree (external_id);


--
-- Name: ix_targets_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_targets_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets USING btree (user_id);


--
-- Name: ix_targets_whatsapp_instance_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_targets_whatsapp_instance_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets USING btree (whatsapp_instance_id);


--
-- Name: ix_usage_events_campaign_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_usage_events_campaign_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events USING btree (campaign_id);


--
-- Name: ix_usage_events_delivery_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_usage_events_delivery_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events USING btree (delivery_id);


--
-- Name: ix_usage_events_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_usage_events_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events USING btree (user_id);


--
-- Name: ix_user_subscriptions_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_user_subscriptions_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_subscriptions USING btree (user_id);


--
-- Name: ix_user_usage_daily_usage_date; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_user_usage_daily_usage_date ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily USING btree (usage_date);


--
-- Name: ix_user_usage_daily_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_user_usage_daily_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily USING btree (user_id);


--
-- Name: ix_user_usage_monthly_usage_month; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_user_usage_monthly_usage_month ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly USING btree (usage_month);


--
-- Name: ix_user_usage_monthly_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_user_usage_monthly_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly USING btree (user_id);


--
-- Name: ix_users_telegram_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_users_telegram_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.users USING btree (telegram_user_id);


--
-- Name: ix_whatsapp_instance_snapshots_instance_name; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_whatsapp_instance_snapshots_instance_name ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots USING btree (instance_name);


--
-- Name: ix_whatsapp_instance_snapshots_name_ts; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_whatsapp_instance_snapshots_name_ts ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots USING btree (instance_name, "timestamp");


--
-- Name: ix_whatsapp_instance_snapshots_timestamp; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_whatsapp_instance_snapshots_timestamp ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instance_snapshots USING btree ("timestamp");


--
-- Name: ix_whatsapp_instances_instance_name; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE UNIQUE INDEX ix_whatsapp_instances_instance_name ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances USING btree (instance_name);


--
-- Name: ix_whatsapp_instances_user_id; Type: INDEX; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

CREATE INDEX ix_whatsapp_instances_user_id ON test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances USING btree (user_id);


--
-- Name: Chat Chat_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Chat"
    ADD CONSTRAINT "Chat_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Chatwoot Chatwoot_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Chatwoot"
    ADD CONSTRAINT "Chatwoot_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Contact Contact_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Contact"
    ADD CONSTRAINT "Contact_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: DifySetting DifySetting_difyIdFallback_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."DifySetting"
    ADD CONSTRAINT "DifySetting_difyIdFallback_fkey" FOREIGN KEY ("difyIdFallback") REFERENCES evolution."Dify"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: DifySetting DifySetting_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."DifySetting"
    ADD CONSTRAINT "DifySetting_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Dify Dify_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Dify"
    ADD CONSTRAINT "Dify_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: EvoaiSetting EvoaiSetting_evoaiIdFallback_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."EvoaiSetting"
    ADD CONSTRAINT "EvoaiSetting_evoaiIdFallback_fkey" FOREIGN KEY ("evoaiIdFallback") REFERENCES evolution."Evoai"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: EvoaiSetting EvoaiSetting_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."EvoaiSetting"
    ADD CONSTRAINT "EvoaiSetting_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Evoai Evoai_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Evoai"
    ADD CONSTRAINT "Evoai_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: EvolutionBotSetting EvolutionBotSetting_botIdFallback_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."EvolutionBotSetting"
    ADD CONSTRAINT "EvolutionBotSetting_botIdFallback_fkey" FOREIGN KEY ("botIdFallback") REFERENCES evolution."EvolutionBot"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: EvolutionBotSetting EvolutionBotSetting_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."EvolutionBotSetting"
    ADD CONSTRAINT "EvolutionBotSetting_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: EvolutionBot EvolutionBot_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."EvolutionBot"
    ADD CONSTRAINT "EvolutionBot_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: FlowiseSetting FlowiseSetting_flowiseIdFallback_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."FlowiseSetting"
    ADD CONSTRAINT "FlowiseSetting_flowiseIdFallback_fkey" FOREIGN KEY ("flowiseIdFallback") REFERENCES evolution."Flowise"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: FlowiseSetting FlowiseSetting_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."FlowiseSetting"
    ADD CONSTRAINT "FlowiseSetting_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Flowise Flowise_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Flowise"
    ADD CONSTRAINT "Flowise_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: IntegrationSession IntegrationSession_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."IntegrationSession"
    ADD CONSTRAINT "IntegrationSession_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Kafka Kafka_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Kafka"
    ADD CONSTRAINT "Kafka_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Label Label_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Label"
    ADD CONSTRAINT "Label_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Media Media_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Media"
    ADD CONSTRAINT "Media_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Media Media_messageId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Media"
    ADD CONSTRAINT "Media_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES evolution."Message"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: MessageUpdate MessageUpdate_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."MessageUpdate"
    ADD CONSTRAINT "MessageUpdate_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: MessageUpdate MessageUpdate_messageId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."MessageUpdate"
    ADD CONSTRAINT "MessageUpdate_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES evolution."Message"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Message Message_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Message"
    ADD CONSTRAINT "Message_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Message Message_sessionId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Message"
    ADD CONSTRAINT "Message_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES evolution."IntegrationSession"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: N8nSetting N8nSetting_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."N8nSetting"
    ADD CONSTRAINT "N8nSetting_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: N8nSetting N8nSetting_n8nIdFallback_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."N8nSetting"
    ADD CONSTRAINT "N8nSetting_n8nIdFallback_fkey" FOREIGN KEY ("n8nIdFallback") REFERENCES evolution."N8n"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: N8n N8n_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."N8n"
    ADD CONSTRAINT "N8n_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Nats Nats_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Nats"
    ADD CONSTRAINT "Nats_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: OpenaiBot OpenaiBot_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."OpenaiBot"
    ADD CONSTRAINT "OpenaiBot_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: OpenaiBot OpenaiBot_openaiCredsId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."OpenaiBot"
    ADD CONSTRAINT "OpenaiBot_openaiCredsId_fkey" FOREIGN KEY ("openaiCredsId") REFERENCES evolution."OpenaiCreds"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: OpenaiCreds OpenaiCreds_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."OpenaiCreds"
    ADD CONSTRAINT "OpenaiCreds_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: OpenaiSetting OpenaiSetting_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."OpenaiSetting"
    ADD CONSTRAINT "OpenaiSetting_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: OpenaiSetting OpenaiSetting_openaiCredsId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."OpenaiSetting"
    ADD CONSTRAINT "OpenaiSetting_openaiCredsId_fkey" FOREIGN KEY ("openaiCredsId") REFERENCES evolution."OpenaiCreds"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: OpenaiSetting OpenaiSetting_openaiIdFallback_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."OpenaiSetting"
    ADD CONSTRAINT "OpenaiSetting_openaiIdFallback_fkey" FOREIGN KEY ("openaiIdFallback") REFERENCES evolution."OpenaiBot"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Proxy Proxy_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Proxy"
    ADD CONSTRAINT "Proxy_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Pusher Pusher_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Pusher"
    ADD CONSTRAINT "Pusher_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Rabbitmq Rabbitmq_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Rabbitmq"
    ADD CONSTRAINT "Rabbitmq_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Session Session_sessionId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Session"
    ADD CONSTRAINT "Session_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Setting Setting_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Setting"
    ADD CONSTRAINT "Setting_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Sqs Sqs_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Sqs"
    ADD CONSTRAINT "Sqs_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Template Template_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Template"
    ADD CONSTRAINT "Template_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: TypebotSetting TypebotSetting_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."TypebotSetting"
    ADD CONSTRAINT "TypebotSetting_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: TypebotSetting TypebotSetting_typebotIdFallback_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."TypebotSetting"
    ADD CONSTRAINT "TypebotSetting_typebotIdFallback_fkey" FOREIGN KEY ("typebotIdFallback") REFERENCES evolution."Typebot"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Typebot Typebot_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Typebot"
    ADD CONSTRAINT "Typebot_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Webhook Webhook_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Webhook"
    ADD CONSTRAINT "Webhook_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Websocket Websocket_instanceId_fkey; Type: FK CONSTRAINT; Schema: evolution; Owner: -
--

ALTER TABLE ONLY evolution."Websocket"
    ADD CONSTRAINT "Websocket_instanceId_fkey" FOREIGN KEY ("instanceId") REFERENCES evolution."Instance"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ai_action_idempotency ai_action_idempotency_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: ai_action_idempotency ai_action_idempotency_inbound_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_inbound_message_id_fkey FOREIGN KEY (inbound_message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: ai_action_idempotency ai_action_idempotency_outbound_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_outbound_message_id_fkey FOREIGN KEY (outbound_message_id) REFERENCES public.messages(id) ON DELETE SET NULL;


--
-- Name: ai_action_idempotency ai_action_idempotency_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_anomalies ai_anomalies_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_anomalies
    ADD CONSTRAINT ai_anomalies_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_budget_reservations ai_budget_reservations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_budget_reservations
    ADD CONSTRAINT ai_budget_reservations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_circuit_breakers ai_circuit_breakers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_circuit_breakers
    ADD CONSTRAINT ai_circuit_breakers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_configurations ai_configurations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_configurations
    ADD CONSTRAINT ai_configurations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_control_audit_events ai_control_audit_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_control_audit_events
    ADD CONSTRAINT ai_control_audit_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: ai_control_audit_events ai_control_audit_events_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_control_audit_events
    ADD CONSTRAINT ai_control_audit_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_decisions ai_decisions_ai_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_decisions
    ADD CONSTRAINT ai_decisions_ai_job_id_fkey FOREIGN KEY (ai_job_id) REFERENCES public.ai_jobs(id) ON DELETE SET NULL;


--
-- Name: ai_decisions ai_decisions_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_decisions
    ADD CONSTRAINT ai_decisions_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: ai_decisions ai_decisions_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_decisions
    ADD CONSTRAINT ai_decisions_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: ai_decisions ai_decisions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_decisions
    ADD CONSTRAINT ai_decisions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_execution_traces ai_execution_traces_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_execution_traces
    ADD CONSTRAINT ai_execution_traces_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: ai_execution_traces ai_execution_traces_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_execution_traces
    ADD CONSTRAINT ai_execution_traces_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: ai_execution_traces ai_execution_traces_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_execution_traces
    ADD CONSTRAINT ai_execution_traces_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_global_controls ai_global_controls_updated_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_global_controls
    ADD CONSTRAINT ai_global_controls_updated_by_id_fkey FOREIGN KEY (updated_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: ai_jobs ai_jobs_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_jobs
    ADD CONSTRAINT ai_jobs_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: ai_jobs ai_jobs_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_jobs
    ADD CONSTRAINT ai_jobs_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: ai_jobs ai_jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_jobs
    ADD CONSTRAINT ai_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_policy_versions ai_policy_versions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_policy_versions
    ADD CONSTRAINT ai_policy_versions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_prompt_versions ai_prompt_versions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_prompt_versions
    ADD CONSTRAINT ai_prompt_versions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_tenant_budgets ai_tenant_budgets_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tenant_budgets
    ADD CONSTRAINT ai_tenant_budgets_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_tenant_controls ai_tenant_controls_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tenant_controls
    ADD CONSTRAINT ai_tenant_controls_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: campaign_groups campaign_groups_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_groups
    ADD CONSTRAINT campaign_groups_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: campaign_rebalance_events campaign_rebalance_events_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_rebalance_events
    ADD CONSTRAINT campaign_rebalance_events_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: campaign_rebalance_events campaign_rebalance_events_destination_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_rebalance_events
    ADD CONSTRAINT campaign_rebalance_events_destination_instance_id_fkey FOREIGN KEY (destination_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: campaign_rebalance_events campaign_rebalance_events_source_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_rebalance_events
    ADD CONSTRAINT campaign_rebalance_events_source_instance_id_fkey FOREIGN KEY (source_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: campaign_safety_settings campaign_safety_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_safety_settings
    ADD CONSTRAINT campaign_safety_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: campaign_safety_settings campaign_safety_settings_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_safety_settings
    ADD CONSTRAINT campaign_safety_settings_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: campaign_targets campaign_targets_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_targets
    ADD CONSTRAINT campaign_targets_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: campaign_targets campaign_targets_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_targets
    ADD CONSTRAINT campaign_targets_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.targets(id) ON DELETE CASCADE;


--
-- Name: collection_targets collection_targets_collection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_targets
    ADD CONSTRAINT collection_targets_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES public.collections(id) ON DELETE CASCADE;


--
-- Name: collection_targets collection_targets_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_targets
    ADD CONSTRAINT collection_targets_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.targets(id) ON DELETE CASCADE;


--
-- Name: contact_campaign_progress contact_campaign_progress_allocated_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_campaign_progress
    ADD CONSTRAINT contact_campaign_progress_allocated_group_id_fkey FOREIGN KEY (allocated_group_id) REFERENCES public.campaign_groups(id) ON DELETE SET NULL;


--
-- Name: contact_campaign_progress contact_campaign_progress_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_campaign_progress
    ADD CONSTRAINT contact_campaign_progress_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: contact_campaign_progress contact_campaign_progress_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_campaign_progress
    ADD CONSTRAINT contact_campaign_progress_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;


--
-- Name: contacts contacts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: contacts contacts_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: dead_letter_targets dead_letter_targets_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: dead_letter_targets dead_letter_targets_campaign_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_campaign_target_id_fkey FOREIGN KEY (campaign_target_id) REFERENCES public.campaign_targets(id) ON DELETE CASCADE;


--
-- Name: dead_letter_targets dead_letter_targets_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.targets(id) ON DELETE CASCADE;


--
-- Name: dead_letter_targets dead_letter_targets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: delivery_idempotency delivery_idempotency_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: delivery_idempotency delivery_idempotency_campaign_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_campaign_target_id_fkey FOREIGN KEY (campaign_target_id) REFERENCES public.campaign_targets(id) ON DELETE CASCADE;


--
-- Name: delivery_idempotency delivery_idempotency_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.targets(id) ON DELETE CASCADE;


--
-- Name: delivery_idempotency delivery_idempotency_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: execution_logs execution_logs_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_logs
    ADD CONSTRAINT execution_logs_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: execution_logs execution_logs_campaign_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_logs
    ADD CONSTRAINT execution_logs_campaign_target_id_fkey FOREIGN KEY (campaign_target_id) REFERENCES public.campaign_targets(id) ON DELETE CASCADE;


--
-- Name: campaign_targets fk_campaign_targets_assigned_instance_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_targets
    ADD CONSTRAINT fk_campaign_targets_assigned_instance_id FOREIGN KEY (assigned_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: campaigns fk_campaigns_instance_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT fk_campaigns_instance_id FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: campaigns fk_campaigns_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT fk_campaigns_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: collections fk_collections_instance_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT fk_collections_instance_id FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: collections fk_collections_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT fk_collections_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: targets fk_targets_instance_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.targets
    ADD CONSTRAINT fk_targets_instance_id FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: targets fk_targets_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.targets
    ADD CONSTRAINT fk_targets_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_invitations group_invitations_campaign_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT group_invitations_campaign_group_id_fkey FOREIGN KEY (campaign_group_id) REFERENCES public.campaign_groups(id) ON DELETE CASCADE;


--
-- Name: group_invitations group_invitations_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT group_invitations_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: group_invitations group_invitations_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT group_invitations_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;


--
-- Name: instance_pacing_states instance_pacing_states_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_pacing_states
    ADD CONSTRAINT instance_pacing_states_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: instance_pacing_transitions instance_pacing_transitions_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_pacing_transitions
    ADD CONSTRAINT instance_pacing_transitions_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: instance_rebalance_states instance_rebalance_states_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_rebalance_states
    ADD CONSTRAINT instance_rebalance_states_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: instance_risk_profiles instance_risk_profiles_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_risk_profiles
    ADD CONSTRAINT instance_risk_profiles_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: instance_state_audit_events instance_state_audit_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_state_audit_events
    ADD CONSTRAINT instance_state_audit_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: instance_state_audit_events instance_state_audit_events_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instance_state_audit_events
    ADD CONSTRAINT instance_state_audit_events_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: messages messages_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: messages messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages messages_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: mikrotik_wan_usage mikrotik_wan_usage_reading_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mikrotik_wan_usage
    ADD CONSTRAINT mikrotik_wan_usage_reading_id_fkey FOREIGN KEY (reading_id) REFERENCES public.mikrotik_wan_readings(id);


--
-- Name: quota_allocations quota_allocations_billing_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_allocations
    ADD CONSTRAINT quota_allocations_billing_cycle_id_fkey FOREIGN KEY (billing_cycle_id) REFERENCES public.billing_cycles(id) ON DELETE RESTRICT;


--
-- Name: quota_reservations quota_reservations_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_reservations
    ADD CONSTRAINT quota_reservations_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: quota_reservations quota_reservations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quota_reservations
    ADD CONSTRAINT quota_reservations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: recipient_risk_profiles recipient_risk_profiles_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipient_risk_profiles
    ADD CONSTRAINT recipient_risk_profiles_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: recipient_risk_profiles recipient_risk_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipient_risk_profiles
    ADD CONSTRAINT recipient_risk_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: risk_decisions risk_decisions_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_decisions
    ADD CONSTRAINT risk_decisions_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE SET NULL;


--
-- Name: risk_decisions risk_decisions_campaign_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_decisions
    ADD CONSTRAINT risk_decisions_campaign_target_id_fkey FOREIGN KEY (campaign_target_id) REFERENCES public.campaign_targets(id) ON DELETE SET NULL;


--
-- Name: risk_decisions risk_decisions_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_decisions
    ADD CONSTRAINT risk_decisions_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: risk_decisions risk_decisions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_decisions
    ADD CONSTRAINT risk_decisions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: risk_signals risk_signals_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_signals
    ADD CONSTRAINT risk_signals_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: risk_signals risk_signals_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_signals
    ADD CONSTRAINT risk_signals_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: risk_state_transitions risk_state_transitions_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_state_transitions
    ADD CONSTRAINT risk_state_transitions_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: subscription_events subscription_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_events
    ADD CONSTRAINT subscription_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: subscription_payments subscription_payments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_payments
    ADD CONSTRAINT subscription_payments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: usage_events usage_events_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: usage_events usage_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_subscriptions user_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_usage_daily user_usage_daily_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_usage_daily
    ADD CONSTRAINT user_usage_daily_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_usage_monthly user_usage_monthly_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_usage_monthly
    ADD CONSTRAINT user_usage_monthly_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: whatsapp_instances whatsapp_instances_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_instances
    ADD CONSTRAINT whatsapp_instances_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_action_idempotency ai_action_idempotency_conversation_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations(id) ON DELETE CASCADE;


--
-- Name: ai_action_idempotency ai_action_idempotency_inbound_message_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_inbound_message_id_fkey FOREIGN KEY (inbound_message_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages(id) ON DELETE CASCADE;


--
-- Name: ai_action_idempotency ai_action_idempotency_outbound_message_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_outbound_message_id_fkey FOREIGN KEY (outbound_message_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages(id) ON DELETE SET NULL;


--
-- Name: ai_action_idempotency ai_action_idempotency_tenant_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_action_idempotency
    ADD CONSTRAINT ai_action_idempotency_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_anomalies ai_anomalies_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_anomalies
    ADD CONSTRAINT ai_anomalies_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_budget_reservations ai_budget_reservations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_budget_reservations
    ADD CONSTRAINT ai_budget_reservations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_circuit_breakers ai_circuit_breakers_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_circuit_breakers
    ADD CONSTRAINT ai_circuit_breakers_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_configurations ai_configurations_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_configurations
    ADD CONSTRAINT ai_configurations_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_control_audit_events ai_control_audit_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events
    ADD CONSTRAINT ai_control_audit_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE SET NULL;


--
-- Name: ai_control_audit_events ai_control_audit_events_tenant_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_control_audit_events
    ADD CONSTRAINT ai_control_audit_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_decisions ai_decisions_ai_job_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions
    ADD CONSTRAINT ai_decisions_ai_job_id_fkey FOREIGN KEY (ai_job_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs(id) ON DELETE SET NULL;


--
-- Name: ai_decisions ai_decisions_conversation_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions
    ADD CONSTRAINT ai_decisions_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations(id) ON DELETE CASCADE;


--
-- Name: ai_decisions ai_decisions_message_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions
    ADD CONSTRAINT ai_decisions_message_id_fkey FOREIGN KEY (message_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages(id) ON DELETE CASCADE;


--
-- Name: ai_decisions ai_decisions_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_decisions
    ADD CONSTRAINT ai_decisions_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_execution_traces ai_execution_traces_conversation_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces
    ADD CONSTRAINT ai_execution_traces_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations(id) ON DELETE CASCADE;


--
-- Name: ai_execution_traces ai_execution_traces_message_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces
    ADD CONSTRAINT ai_execution_traces_message_id_fkey FOREIGN KEY (message_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages(id) ON DELETE CASCADE;


--
-- Name: ai_execution_traces ai_execution_traces_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_execution_traces
    ADD CONSTRAINT ai_execution_traces_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_global_controls ai_global_controls_updated_by_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_global_controls
    ADD CONSTRAINT ai_global_controls_updated_by_id_fkey FOREIGN KEY (updated_by_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE SET NULL;


--
-- Name: ai_jobs ai_jobs_conversation_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs
    ADD CONSTRAINT ai_jobs_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations(id) ON DELETE CASCADE;


--
-- Name: ai_jobs ai_jobs_message_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs
    ADD CONSTRAINT ai_jobs_message_id_fkey FOREIGN KEY (message_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages(id) ON DELETE CASCADE;


--
-- Name: ai_jobs ai_jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_jobs
    ADD CONSTRAINT ai_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_knowledge_items ai_knowledge_items_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_knowledge_items
    ADD CONSTRAINT ai_knowledge_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_policy_versions ai_policy_versions_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_policy_versions
    ADD CONSTRAINT ai_policy_versions_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_prompt_versions ai_prompt_versions_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_prompt_versions
    ADD CONSTRAINT ai_prompt_versions_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_tenant_budgets ai_tenant_budgets_tenant_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_budgets
    ADD CONSTRAINT ai_tenant_budgets_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: ai_tenant_controls ai_tenant_controls_tenant_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.ai_tenant_controls
    ADD CONSTRAINT ai_tenant_controls_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: campaign_groups campaign_groups_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups
    ADD CONSTRAINT campaign_groups_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: campaign_rebalance_events campaign_rebalance_events_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events
    ADD CONSTRAINT campaign_rebalance_events_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: campaign_rebalance_events campaign_rebalance_events_destination_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events
    ADD CONSTRAINT campaign_rebalance_events_destination_instance_id_fkey FOREIGN KEY (destination_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: campaign_rebalance_events campaign_rebalance_events_source_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_rebalance_events
    ADD CONSTRAINT campaign_rebalance_events_source_instance_id_fkey FOREIGN KEY (source_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: campaign_safety_settings campaign_safety_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings
    ADD CONSTRAINT campaign_safety_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: campaign_safety_settings campaign_safety_settings_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_safety_settings
    ADD CONSTRAINT campaign_safety_settings_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: campaign_targets campaign_targets_assigned_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets
    ADD CONSTRAINT campaign_targets_assigned_instance_id_fkey FOREIGN KEY (assigned_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: campaign_targets campaign_targets_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets
    ADD CONSTRAINT campaign_targets_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: campaign_targets campaign_targets_target_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets
    ADD CONSTRAINT campaign_targets_target_id_fkey FOREIGN KEY (target_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets(id) ON DELETE CASCADE;


--
-- Name: campaigns campaigns_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns
    ADD CONSTRAINT campaigns_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: campaigns campaigns_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns
    ADD CONSTRAINT campaigns_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: collection_targets collection_targets_collection_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets
    ADD CONSTRAINT collection_targets_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections(id) ON DELETE CASCADE;


--
-- Name: collection_targets collection_targets_target_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collection_targets
    ADD CONSTRAINT collection_targets_target_id_fkey FOREIGN KEY (target_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets(id) ON DELETE CASCADE;


--
-- Name: collections collections_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections
    ADD CONSTRAINT collections_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: collections collections_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.collections
    ADD CONSTRAINT collections_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: contact_campaign_progress contact_campaign_progress_allocated_group_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress
    ADD CONSTRAINT contact_campaign_progress_allocated_group_id_fkey FOREIGN KEY (allocated_group_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups(id) ON DELETE SET NULL;


--
-- Name: contact_campaign_progress contact_campaign_progress_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress
    ADD CONSTRAINT contact_campaign_progress_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: contact_campaign_progress contact_campaign_progress_contact_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contact_campaign_progress
    ADD CONSTRAINT contact_campaign_progress_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts(id) ON DELETE CASCADE;


--
-- Name: contacts contacts_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts
    ADD CONSTRAINT contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: contacts contacts_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts
    ADD CONSTRAINT contacts_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_contact_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations
    ADD CONSTRAINT conversations_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations
    ADD CONSTRAINT conversations_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations
    ADD CONSTRAINT conversations_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: dead_letter_targets dead_letter_targets_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: dead_letter_targets dead_letter_targets_campaign_target_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_campaign_target_id_fkey FOREIGN KEY (campaign_target_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets(id) ON DELETE CASCADE;


--
-- Name: dead_letter_targets dead_letter_targets_target_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_target_id_fkey FOREIGN KEY (target_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets(id) ON DELETE CASCADE;


--
-- Name: dead_letter_targets dead_letter_targets_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.dead_letter_targets
    ADD CONSTRAINT dead_letter_targets_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE SET NULL;


--
-- Name: delivery_idempotency delivery_idempotency_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: delivery_idempotency delivery_idempotency_campaign_target_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_campaign_target_id_fkey FOREIGN KEY (campaign_target_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets(id) ON DELETE CASCADE;


--
-- Name: delivery_idempotency delivery_idempotency_target_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_target_id_fkey FOREIGN KEY (target_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets(id) ON DELETE CASCADE;


--
-- Name: delivery_idempotency delivery_idempotency_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.delivery_idempotency
    ADD CONSTRAINT delivery_idempotency_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE SET NULL;


--
-- Name: execution_logs execution_logs_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs
    ADD CONSTRAINT execution_logs_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: execution_logs execution_logs_campaign_target_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.execution_logs
    ADD CONSTRAINT execution_logs_campaign_target_id_fkey FOREIGN KEY (campaign_target_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets(id) ON DELETE CASCADE;


--
-- Name: group_invitations group_invitations_campaign_group_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations
    ADD CONSTRAINT group_invitations_campaign_group_id_fkey FOREIGN KEY (campaign_group_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_groups(id) ON DELETE CASCADE;


--
-- Name: group_invitations group_invitations_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations
    ADD CONSTRAINT group_invitations_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: group_invitations group_invitations_contact_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.group_invitations
    ADD CONSTRAINT group_invitations_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts(id) ON DELETE CASCADE;


--
-- Name: instance_pacing_states instance_pacing_states_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_states
    ADD CONSTRAINT instance_pacing_states_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: instance_pacing_transitions instance_pacing_transitions_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_pacing_transitions
    ADD CONSTRAINT instance_pacing_transitions_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: instance_rebalance_states instance_rebalance_states_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_rebalance_states
    ADD CONSTRAINT instance_rebalance_states_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: instance_risk_profiles instance_risk_profiles_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_risk_profiles
    ADD CONSTRAINT instance_risk_profiles_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: instance_state_audit_events instance_state_audit_events_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events
    ADD CONSTRAINT instance_state_audit_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE SET NULL;


--
-- Name: instance_state_audit_events instance_state_audit_events_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.instance_state_audit_events
    ADD CONSTRAINT instance_state_audit_events_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: messages messages_contact_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages
    ADD CONSTRAINT messages_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.contacts(id) ON DELETE CASCADE;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.conversations(id) ON DELETE CASCADE;


--
-- Name: messages messages_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages
    ADD CONSTRAINT messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: messages messages_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.messages
    ADD CONSTRAINT messages_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: quota_reservations quota_reservations_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations
    ADD CONSTRAINT quota_reservations_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: quota_reservations quota_reservations_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.quota_reservations
    ADD CONSTRAINT quota_reservations_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: recipient_risk_profiles recipient_risk_profiles_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles
    ADD CONSTRAINT recipient_risk_profiles_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: recipient_risk_profiles recipient_risk_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.recipient_risk_profiles
    ADD CONSTRAINT recipient_risk_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: risk_decisions risk_decisions_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions
    ADD CONSTRAINT risk_decisions_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE SET NULL;


--
-- Name: risk_decisions risk_decisions_campaign_target_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions
    ADD CONSTRAINT risk_decisions_campaign_target_id_fkey FOREIGN KEY (campaign_target_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaign_targets(id) ON DELETE SET NULL;


--
-- Name: risk_decisions risk_decisions_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions
    ADD CONSTRAINT risk_decisions_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: risk_decisions risk_decisions_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_decisions
    ADD CONSTRAINT risk_decisions_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: risk_signals risk_signals_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals
    ADD CONSTRAINT risk_signals_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: risk_signals risk_signals_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_signals
    ADD CONSTRAINT risk_signals_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: risk_state_transitions risk_state_transitions_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.risk_state_transitions
    ADD CONSTRAINT risk_state_transitions_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE SET NULL;


--
-- Name: subscription_events subscription_events_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_events
    ADD CONSTRAINT subscription_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: subscription_payments subscription_payments_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.subscription_payments
    ADD CONSTRAINT subscription_payments_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: targets targets_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets
    ADD CONSTRAINT targets_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: targets targets_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.targets
    ADD CONSTRAINT targets_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances(id) ON DELETE CASCADE;


--
-- Name: usage_events usage_events_campaign_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events
    ADD CONSTRAINT usage_events_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.campaigns(id) ON DELETE CASCADE;


--
-- Name: usage_events usage_events_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.usage_events
    ADD CONSTRAINT usage_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: user_subscriptions user_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_subscriptions
    ADD CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: user_usage_daily user_usage_daily_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_daily
    ADD CONSTRAINT user_usage_daily_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: user_usage_monthly user_usage_monthly_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.user_usage_monthly
    ADD CONSTRAINT user_usage_monthly_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- Name: whatsapp_instances whatsapp_instances_user_id_fkey; Type: FK CONSTRAINT; Schema: test_818d3ceb0ced4bb09b0a383c38a9cd7a; Owner: -
--

ALTER TABLE ONLY test_818d3ceb0ced4bb09b0a383c38a9cd7a.whatsapp_instances
    ADD CONSTRAINT whatsapp_instances_user_id_fkey FOREIGN KEY (user_id) REFERENCES test_818d3ceb0ced4bb09b0a383c38a9cd7a.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict a7ZYmexYcEmZmfBXU6crqFhY8PQFK2Qpm1hc5K4lsn6Kp9uEFV93PNgaltzJu6r

