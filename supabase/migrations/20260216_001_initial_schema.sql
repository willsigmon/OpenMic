-- OpenMic Freemium Schema
-- Initial migration: usage tracking, quotas, subscriptions

-- Voice session usage tracking
CREATE TABLE IF NOT EXISTS usage_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users,
    device_id TEXT NOT NULL,
    session_id UUID,
    provider TEXT NOT NULL,
    tier TEXT NOT NULL,
    duration_seconds INTEGER,
    tokens_consumed INTEGER,
    cost_cents INTEGER,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Per-user quotas (monthly reset)
CREATE TABLE IF NOT EXISTS user_quotas (
    user_id UUID PRIMARY KEY REFERENCES auth.users,
    tier TEXT DEFAULT 'free',
    free_minutes_remaining INTEGER DEFAULT 10,
    paid_credits_cents INTEGER DEFAULT 0,
    monthly_reset_at TIMESTAMPTZ DEFAULT (date_trunc('month', now()) + interval '1 month'),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Subscription records (synced from App Store)
CREATE TABLE IF NOT EXISTS user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users DEFAULT auth.uid(),
    product_id TEXT NOT NULL,
    tier TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    expires_at TIMESTAMPTZ,
    original_transaction_id TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_usage_events_user_id ON usage_events(user_id);
CREATE INDEX IF NOT EXISTS idx_usage_events_device_id ON usage_events(device_id);
CREATE INDEX IF NOT EXISTS idx_usage_events_created_at ON usage_events(created_at);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON user_subscriptions(user_id);

-- Row Level Security
ALTER TABLE usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can only read their own usage events
CREATE POLICY "Users read own usage" ON usage_events
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own usage events
CREATE POLICY "Users insert own usage" ON usage_events
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Users can read their own quota
CREATE POLICY "Users read own quota" ON user_quotas
    FOR SELECT USING (auth.uid() = user_id);

-- Users can read their own subscriptions
CREATE POLICY "Users read own subscriptions" ON user_subscriptions
    FOR SELECT USING (auth.uid() = user_id);

-- Users can upsert their own subscriptions (synced from StoreKit)
CREATE POLICY "Users upsert own subscriptions" ON user_subscriptions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own subscriptions" ON user_subscriptions
    FOR UPDATE USING (auth.uid() = user_id);

-- Function to merge anonymous usage into authenticated account
CREATE OR REPLACE FUNCTION merge_anonymous_usage(
    p_device_id TEXT,
    p_user_id UUID
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    -- Transfer usage events from device-only to authenticated user
    UPDATE usage_events
    SET user_id = p_user_id
    WHERE device_id = p_device_id
      AND user_id IS NULL;

    -- Create quota record if it doesn't exist
    INSERT INTO user_quotas (user_id, tier, free_minutes_remaining)
    VALUES (p_user_id, 'free', 10)
    ON CONFLICT (user_id) DO NOTHING;
END;
$$;

-- Function to reset monthly quotas (called by cron)
CREATE OR REPLACE FUNCTION reset_monthly_quotas()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    UPDATE user_quotas
    SET free_minutes_remaining = CASE tier
            WHEN 'free' THEN 10
            WHEN 'standard' THEN 120
            WHEN 'premium' THEN 120
            ELSE free_minutes_remaining
        END,
        monthly_reset_at = date_trunc('month', now()) + interval '1 month',
        updated_at = now()
    WHERE monthly_reset_at <= now();
END;
$$;
