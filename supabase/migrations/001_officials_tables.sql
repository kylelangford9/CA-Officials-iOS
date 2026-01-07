-- CA Officials Database Schema
-- Migration: 001_officials_tables.sql
-- Description: Creates tables for the Officials module
-- Date: 2026-01-07
--
-- NOTE: This migration builds on existing CA Voters schema:
--   - Reuses: update_updated_at_column() function
--   - Reuses: political_party enum
--   - Reuses: representative_level enum (mapped to office_level)
--   - References: representatives table for linking

-- ============================================================================
-- ENUMS (only new ones not in existing schema)
-- ============================================================================

-- Verification status enum (safe creation)
DO $$ BEGIN
    CREATE TYPE verification_status AS ENUM (
        'unverified',
        'pending',
        'verified',
        'rejected',
        'expired'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Verification method enum (safe creation)
DO $$ BEGIN
    CREATE TYPE verification_method AS ENUM (
        'government_email',
        'website_token',
        'document_upload'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Note: Using existing representative_level enum for office levels
-- Values: 'federal', 'state', 'county', 'local', 'special'
-- Note: Using existing political_party enum for party affiliation
-- Values: 'democratic', 'republican', 'independent', 'libertarian',
--         'green', 'other', 'nonpartisan', 'unknown'

-- ============================================================================
-- TABLES
-- ============================================================================

-- Government Offices Table
-- Stores all government positions in California
-- Uses existing representative_level enum from CA Voters schema
CREATE TABLE IF NOT EXISTS government_offices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    level representative_level NOT NULL,  -- Reuse existing enum
    jurisdiction TEXT NOT NULL,
    district TEXT,
    incumbent_name TEXT,
    is_claimed BOOLEAN DEFAULT false,
    claimed_by UUID,
    term_start DATE,
    term_end DATE,
    website_url TEXT,

    -- Link to existing representatives table (optional)
    representative_id UUID REFERENCES representatives(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure unique office per jurisdiction/district
    CONSTRAINT unique_office UNIQUE (title, jurisdiction, district)
);

-- Create indexes for searching offices
CREATE INDEX idx_government_offices_level ON government_offices(level);
CREATE INDEX idx_government_offices_jurisdiction ON government_offices(jurisdiction);
CREATE INDEX idx_government_offices_claimed ON government_offices(is_claimed);
CREATE INDEX idx_government_offices_representative ON government_offices(representative_id);

-- Officials Table
-- Stores official profiles
-- Uses existing political_party enum from CA Voters schema
CREATE TABLE IF NOT EXISTS officials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    office_id UUID REFERENCES government_offices(id),

    -- Link to existing representatives table (bidirectional sync)
    representative_id UUID REFERENCES representatives(id) ON DELETE SET NULL,

    -- Basic Info
    name TEXT NOT NULL,
    title TEXT,
    bio TEXT,
    pronouns TEXT,
    party political_party DEFAULT 'unknown',  -- Reuse existing enum

    -- Media
    photo_url TEXT,
    banner_url TEXT,

    -- Verification
    verification_status verification_status DEFAULT 'unverified',
    verified_at TIMESTAMPTZ,
    verification_method verification_method,

    -- Contact Info (JSONB for flexibility)
    contact_info JSONB DEFAULT '{
        "office_phone": null,
        "office_email": null,
        "office_address": null,
        "mailing_address": null
    }'::jsonb,

    -- Social Links (JSONB for flexibility)
    social_links JSONB DEFAULT '{
        "website_url": null,
        "twitter_handle": null,
        "facebook_url": null,
        "instagram_handle": null,
        "linkedin_url": null,
        "youtube_url": null
    }'::jsonb,

    -- Metadata
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- One official per user
    CONSTRAINT unique_user_official UNIQUE (user_id)
);

-- Create indexes for officials
CREATE INDEX idx_officials_user_id ON officials(user_id);
CREATE INDEX idx_officials_office_id ON officials(office_id);
CREATE INDEX idx_officials_representative_id ON officials(representative_id);
CREATE INDEX idx_officials_verification_status ON officials(verification_status);
CREATE INDEX idx_officials_party ON officials(party);
CREATE INDEX idx_officials_active ON officials(is_active);

-- Update government_offices.claimed_by foreign key
ALTER TABLE government_offices
    ADD CONSTRAINT fk_claimed_by
    FOREIGN KEY (claimed_by) REFERENCES officials(id) ON DELETE SET NULL;

-- Verification Requests Table
-- Tracks verification submissions
CREATE TABLE IF NOT EXISTS verification_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    official_id UUID REFERENCES officials(id) ON DELETE CASCADE,
    office_id UUID REFERENCES government_offices(id),

    -- Method details
    method verification_method NOT NULL,
    status verification_status DEFAULT 'pending',

    -- Email verification
    verification_code TEXT,
    code_expires_at TIMESTAMPTZ,
    verification_email TEXT,

    -- Website verification
    website_token TEXT,
    website_url TEXT,

    -- Document verification
    document_urls TEXT[] DEFAULT '{}',
    document_types TEXT[] DEFAULT '{}',

    -- Review
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewer_id UUID,
    reviewer_notes TEXT,
    rejection_reason TEXT,

    -- Metadata
    attempt_count INTEGER DEFAULT 1,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for verification requests
CREATE INDEX idx_verification_requests_official_id ON verification_requests(official_id);
CREATE INDEX idx_verification_requests_status ON verification_requests(status);
CREATE INDEX idx_verification_requests_method ON verification_requests(method);
CREATE INDEX idx_verification_requests_submitted_at ON verification_requests(submitted_at);

-- Policy Positions Table
-- Stores official policy stances
CREATE TABLE IF NOT EXISTS policy_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    official_id UUID REFERENCES officials(id) ON DELETE CASCADE,

    topic TEXT NOT NULL,
    stance TEXT,
    summary TEXT,
    detailed_position TEXT,

    -- Metadata
    is_featured BOOLEAN DEFAULT false,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Unique topic per official
    CONSTRAINT unique_official_topic UNIQUE (official_id, topic)
);

-- Create indexes for policy positions
CREATE INDEX idx_policy_positions_official_id ON policy_positions(official_id);
CREATE INDEX idx_policy_positions_topic ON policy_positions(topic);
CREATE INDEX idx_policy_positions_featured ON policy_positions(is_featured);

-- Official Analytics Table
-- Tracks profile views and engagement
CREATE TABLE IF NOT EXISTS official_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    official_id UUID REFERENCES officials(id) ON DELETE CASCADE,

    -- Time period
    date DATE NOT NULL,

    -- Metrics
    profile_views INTEGER DEFAULT 0,
    search_appearances INTEGER DEFAULT 0,
    unique_voters INTEGER DEFAULT 0,
    link_clicks INTEGER DEFAULT 0,
    contact_clicks INTEGER DEFAULT 0,
    social_clicks INTEGER DEFAULT 0,

    -- Source breakdown (JSONB)
    source_breakdown JSONB DEFAULT '{
        "ca_voters_app": 0,
        "direct": 0,
        "search": 0,
        "shared_link": 0
    }'::jsonb,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- One record per official per day
    CONSTRAINT unique_official_date UNIQUE (official_id, date)
);

-- Create indexes for analytics
CREATE INDEX idx_official_analytics_official_id ON official_analytics(official_id);
CREATE INDEX idx_official_analytics_date ON official_analytics(date);

-- Profile Edits Table (Audit Trail)
-- Tracks changes to official profiles
CREATE TABLE IF NOT EXISTS profile_edits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    official_id UUID REFERENCES officials(id) ON DELETE CASCADE,

    -- Change details
    field_name TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,

    -- Who made the change
    edited_by UUID REFERENCES auth.users(id),
    edit_reason TEXT,

    -- Metadata
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for profile edits
CREATE INDEX idx_profile_edits_official_id ON profile_edits(official_id);
CREATE INDEX idx_profile_edits_field ON profile_edits(field_name);
CREATE INDEX idx_profile_edits_created_at ON profile_edits(created_at);

-- Delegated Access Table (Staff Access)
-- Allows officials to grant access to staff members
CREATE TABLE IF NOT EXISTS delegated_access (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    official_id UUID REFERENCES officials(id) ON DELETE CASCADE,
    delegate_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Permissions
    can_edit_profile BOOLEAN DEFAULT true,
    can_post BOOLEAN DEFAULT true,
    can_view_analytics BOOLEAN DEFAULT true,
    can_respond_messages BOOLEAN DEFAULT false,
    can_manage_staff BOOLEAN DEFAULT false,

    -- Metadata
    granted_by UUID REFERENCES auth.users(id),
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,

    -- Unique delegate per official
    CONSTRAINT unique_delegation UNIQUE (official_id, delegate_user_id)
);

-- Create indexes for delegated access
CREATE INDEX idx_delegated_access_official_id ON delegated_access(official_id);
CREATE INDEX idx_delegated_access_delegate_user_id ON delegated_access(delegate_user_id);
CREATE INDEX idx_delegated_access_active ON delegated_access(is_active);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Note: update_updated_at_column() function already exists in CA Voters schema
-- Apply triggers for updated_at using existing function
CREATE TRIGGER update_government_offices_updated_at
    BEFORE UPDATE ON government_offices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_officials_updated_at
    BEFORE UPDATE ON officials
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_verification_requests_updated_at
    BEFORE UPDATE ON verification_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_policy_positions_updated_at
    BEFORE UPDATE ON policy_positions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_official_analytics_updated_at
    BEFORE UPDATE ON official_analytics
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE government_offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE officials ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE official_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_edits ENABLE ROW LEVEL SECURITY;
ALTER TABLE delegated_access ENABLE ROW LEVEL SECURITY;

-- Government Offices Policies
-- Anyone can read offices (public directory)
CREATE POLICY "Public can read government offices"
    ON government_offices FOR SELECT
    USING (true);

-- Only service role can modify offices
CREATE POLICY "Service role can manage government offices"
    ON government_offices FOR ALL
    USING (auth.role() = 'service_role');

-- Officials Policies
-- Anyone can read active, verified officials
CREATE POLICY "Public can read verified officials"
    ON officials FOR SELECT
    USING (is_active = true AND verification_status = 'verified');

-- Users can read their own profile (even if not verified)
CREATE POLICY "Users can read own official profile"
    ON officials FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own profile
CREATE POLICY "Users can create own official profile"
    ON officials FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own official profile"
    ON officials FOR UPDATE
    USING (auth.uid() = user_id);

-- Delegated users can update official profile
CREATE POLICY "Delegates can update official profile"
    ON officials FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM delegated_access
            WHERE delegated_access.official_id = officials.id
            AND delegated_access.delegate_user_id = auth.uid()
            AND delegated_access.is_active = true
            AND delegated_access.can_edit_profile = true
            AND (delegated_access.expires_at IS NULL OR delegated_access.expires_at > NOW())
        )
    );

-- Verification Requests Policies
-- Users can read their own verification requests
CREATE POLICY "Users can read own verification requests"
    ON verification_requests FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = verification_requests.official_id
            AND officials.user_id = auth.uid()
        )
    );

-- Users can create verification requests for their profile
CREATE POLICY "Users can create verification requests"
    ON verification_requests FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = verification_requests.official_id
            AND officials.user_id = auth.uid()
        )
    );

-- Service role can manage verification requests
CREATE POLICY "Service role can manage verification requests"
    ON verification_requests FOR ALL
    USING (auth.role() = 'service_role');

-- Policy Positions Policies
-- Anyone can read policy positions of verified officials
CREATE POLICY "Public can read policy positions"
    ON policy_positions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = policy_positions.official_id
            AND officials.is_active = true
            AND officials.verification_status = 'verified'
        )
    );

-- Users can manage their own policy positions
CREATE POLICY "Users can manage own policy positions"
    ON policy_positions FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = policy_positions.official_id
            AND officials.user_id = auth.uid()
        )
    );

-- Delegates can manage policy positions
CREATE POLICY "Delegates can manage policy positions"
    ON policy_positions FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM delegated_access
            WHERE delegated_access.official_id = policy_positions.official_id
            AND delegated_access.delegate_user_id = auth.uid()
            AND delegated_access.is_active = true
            AND delegated_access.can_edit_profile = true
        )
    );

-- Official Analytics Policies
-- Users can read their own analytics
CREATE POLICY "Users can read own analytics"
    ON official_analytics FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = official_analytics.official_id
            AND officials.user_id = auth.uid()
        )
    );

-- Delegates with analytics permission can read
CREATE POLICY "Delegates can read analytics"
    ON official_analytics FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM delegated_access
            WHERE delegated_access.official_id = official_analytics.official_id
            AND delegated_access.delegate_user_id = auth.uid()
            AND delegated_access.is_active = true
            AND delegated_access.can_view_analytics = true
        )
    );

-- Service role can manage analytics
CREATE POLICY "Service role can manage analytics"
    ON official_analytics FOR ALL
    USING (auth.role() = 'service_role');

-- Profile Edits Policies
-- Users can read their own profile edits
CREATE POLICY "Users can read own profile edits"
    ON profile_edits FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = profile_edits.official_id
            AND officials.user_id = auth.uid()
        )
    );

-- Service role can manage profile edits
CREATE POLICY "Service role can manage profile edits"
    ON profile_edits FOR ALL
    USING (auth.role() = 'service_role');

-- Delegated Access Policies
-- Users can read delegations for their official profile
CREATE POLICY "Officials can read delegations"
    ON delegated_access FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = delegated_access.official_id
            AND officials.user_id = auth.uid()
        )
    );

-- Delegates can read their own delegation
CREATE POLICY "Delegates can read own delegation"
    ON delegated_access FOR SELECT
    USING (delegate_user_id = auth.uid());

-- Officials can manage delegations
CREATE POLICY "Officials can manage delegations"
    ON delegated_access FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = delegated_access.official_id
            AND officials.user_id = auth.uid()
        )
    );

-- ============================================================================
-- INITIAL DATA
-- ============================================================================

-- This will be populated with CA government offices
-- See: 002_seed_government_offices.sql
