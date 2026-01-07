-- CA Officials - Connect Module Database Schema
-- Migration: 002_connect_tables.sql
-- Description: Creates tables for the Connect (social feed) module
-- Date: 2026-01-07

-- ============================================================================
-- ENUMS (safe creation)
-- ============================================================================

-- Post type enum
DO $$ BEGIN
    CREATE TYPE post_type AS ENUM (
        'update',
        'announcement',
        'event',
        'policy',
        'media',
        'poll'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Interaction type enum
DO $$ BEGIN
    CREATE TYPE interaction_type AS ENUM (
        'like',
        'bookmark',
        'share'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- TABLES
-- ============================================================================

-- Posts Table
-- Official posts/updates
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    official_id UUID REFERENCES officials(id) ON DELETE CASCADE,

    -- Content
    post_type post_type DEFAULT 'update',
    content TEXT NOT NULL,
    media_urls TEXT[] DEFAULT '{}',
    link_url TEXT,
    link_preview JSONB,

    -- Event-specific fields
    event_date TIMESTAMPTZ,
    event_location TEXT,
    event_url TEXT,

    -- Poll-specific fields
    poll_options JSONB,
    poll_ends_at TIMESTAMPTZ,

    -- Engagement metrics (denormalized for performance)
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    share_count INTEGER DEFAULT 0,
    bookmark_count INTEGER DEFAULT 0,

    -- Visibility
    is_pinned BOOLEAN DEFAULT false,
    is_published BOOLEAN DEFAULT true,
    scheduled_for TIMESTAMPTZ,

    -- Metadata
    posted_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Create indexes for posts
CREATE INDEX idx_posts_official_id ON posts(official_id);
CREATE INDEX idx_posts_post_type ON posts(post_type);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_posts_pinned ON posts(is_pinned);
CREATE INDEX idx_posts_published ON posts(is_published);
CREATE INDEX idx_posts_scheduled ON posts(scheduled_for) WHERE scheduled_for IS NOT NULL;

-- Comments Table
-- Comments on posts
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Content
    content TEXT NOT NULL,

    -- Engagement
    like_count INTEGER DEFAULT 0,

    -- Moderation
    is_hidden BOOLEAN DEFAULT false,
    hidden_reason TEXT,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Create indexes for comments
CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_comments_parent_id ON comments(parent_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_created_at ON comments(created_at DESC);

-- Post Interactions Table
-- Likes, bookmarks, shares
CREATE TABLE IF NOT EXISTS post_interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    interaction_type interaction_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- One interaction type per user per post
    CONSTRAINT unique_interaction UNIQUE (post_id, user_id, interaction_type)
);

-- Create indexes for post interactions
CREATE INDEX idx_post_interactions_post_id ON post_interactions(post_id);
CREATE INDEX idx_post_interactions_user_id ON post_interactions(user_id);
CREATE INDEX idx_post_interactions_type ON post_interactions(interaction_type);

-- Comment Likes Table
-- Likes on comments
CREATE TABLE IF NOT EXISTS comment_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- One like per user per comment
    CONSTRAINT unique_comment_like UNIQUE (comment_id, user_id)
);

-- Create indexes for comment likes
CREATE INDEX idx_comment_likes_comment_id ON comment_likes(comment_id);
CREATE INDEX idx_comment_likes_user_id ON comment_likes(user_id);

-- Follows Table
-- User follows official
CREATE TABLE IF NOT EXISTS follows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    follower_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    official_id UUID REFERENCES officials(id) ON DELETE CASCADE,

    -- Notification preferences
    notify_posts BOOLEAN DEFAULT true,
    notify_events BOOLEAN DEFAULT true,
    notify_policy BOOLEAN DEFAULT false,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- One follow per user per official
    CONSTRAINT unique_follow UNIQUE (follower_user_id, official_id)
);

-- Create indexes for follows
CREATE INDEX idx_follows_follower ON follows(follower_user_id);
CREATE INDEX idx_follows_official ON follows(official_id);

-- Poll Votes Table
-- Votes on poll posts
CREATE TABLE IF NOT EXISTS poll_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    option_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- One vote per user per poll
    CONSTRAINT unique_poll_vote UNIQUE (post_id, user_id)
);

-- Create indexes for poll votes
CREATE INDEX idx_poll_votes_post_id ON poll_votes(post_id);
CREATE INDEX idx_poll_votes_user_id ON poll_votes(user_id);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to update post engagement counts
CREATE OR REPLACE FUNCTION update_post_engagement_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.interaction_type = 'like' THEN
            UPDATE posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
        ELSIF NEW.interaction_type = 'bookmark' THEN
            UPDATE posts SET bookmark_count = bookmark_count + 1 WHERE id = NEW.post_id;
        ELSIF NEW.interaction_type = 'share' THEN
            UPDATE posts SET share_count = share_count + 1 WHERE id = NEW.post_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.interaction_type = 'like' THEN
            UPDATE posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.post_id;
        ELSIF OLD.interaction_type = 'bookmark' THEN
            UPDATE posts SET bookmark_count = GREATEST(bookmark_count - 1, 0) WHERE id = OLD.post_id;
        ELSIF OLD.interaction_type = 'share' THEN
            UPDATE posts SET share_count = GREATEST(share_count - 1, 0) WHERE id = OLD.post_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Trigger for engagement counts
CREATE TRIGGER trigger_update_post_engagement
    AFTER INSERT OR DELETE ON post_interactions
    FOR EACH ROW EXECUTE FUNCTION update_post_engagement_count();

-- Function to update comment count
CREATE OR REPLACE FUNCTION update_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE posts SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Trigger for comment count
CREATE TRIGGER trigger_update_comment_count
    AFTER INSERT OR DELETE ON comments
    FOR EACH ROW EXECUTE FUNCTION update_comment_count();

-- Function to update comment like count
CREATE OR REPLACE FUNCTION update_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE comments SET like_count = like_count + 1 WHERE id = NEW.comment_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE comments SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.comment_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Trigger for comment like count
CREATE TRIGGER trigger_update_comment_like_count
    AFTER INSERT OR DELETE ON comment_likes
    FOR EACH ROW EXECUTE FUNCTION update_comment_like_count();

-- Apply updated_at triggers
CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON comments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;

-- Posts Policies
-- Anyone can read published posts from verified officials
CREATE POLICY "Public can read published posts"
    ON posts FOR SELECT
    USING (
        is_published = true
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = posts.official_id
            AND officials.is_active = true
            AND officials.verification_status = 'verified'
        )
    );

-- Officials can manage their own posts
CREATE POLICY "Officials can manage own posts"
    ON posts FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = posts.official_id
            AND officials.user_id = auth.uid()
        )
    );

-- Delegates with post permission can manage posts
CREATE POLICY "Delegates can manage posts"
    ON posts FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM delegated_access
            WHERE delegated_access.official_id = posts.official_id
            AND delegated_access.delegate_user_id = auth.uid()
            AND delegated_access.is_active = true
            AND delegated_access.can_post = true
        )
    );

-- Comments Policies
-- Anyone can read comments on visible posts
CREATE POLICY "Public can read comments"
    ON comments FOR SELECT
    USING (
        is_hidden = false
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1 FROM posts
            WHERE posts.id = comments.post_id
            AND posts.is_published = true
            AND posts.deleted_at IS NULL
        )
    );

-- Authenticated users can create comments
CREATE POLICY "Authenticated users can comment"
    ON comments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own comments
CREATE POLICY "Users can update own comments"
    ON comments FOR UPDATE
    USING (auth.uid() = user_id);

-- Users can delete their own comments (soft delete)
CREATE POLICY "Users can delete own comments"
    ON comments FOR DELETE
    USING (auth.uid() = user_id);

-- Post Interactions Policies
-- Users can manage their own interactions
CREATE POLICY "Users can manage own interactions"
    ON post_interactions FOR ALL
    USING (auth.uid() = user_id);

-- Anyone can see interaction counts (via posts table)

-- Comment Likes Policies
-- Users can manage their own likes
CREATE POLICY "Users can manage own comment likes"
    ON comment_likes FOR ALL
    USING (auth.uid() = user_id);

-- Follows Policies
-- Users can manage their own follows
CREATE POLICY "Users can manage own follows"
    ON follows FOR ALL
    USING (auth.uid() = follower_user_id);

-- Officials can see their followers
CREATE POLICY "Officials can see followers"
    ON follows FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM officials
            WHERE officials.id = follows.official_id
            AND officials.user_id = auth.uid()
        )
    );

-- Poll Votes Policies
-- Users can manage their own votes
CREATE POLICY "Users can manage own poll votes"
    ON poll_votes FOR ALL
    USING (auth.uid() = user_id);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Feed view for efficient querying
CREATE OR REPLACE VIEW feed_view AS
SELECT
    p.id,
    p.official_id,
    p.post_type,
    p.content,
    p.media_urls,
    p.link_url,
    p.link_preview,
    p.event_date,
    p.event_location,
    p.event_url,
    p.poll_options,
    p.poll_ends_at,
    p.like_count,
    p.comment_count,
    p.share_count,
    p.bookmark_count,
    p.is_pinned,
    p.created_at,
    o.name AS official_name,
    o.title AS official_title,
    o.photo_url AS official_photo,
    o.party AS official_party,
    o.verification_status AS official_verification
FROM posts p
JOIN officials o ON p.official_id = o.id
WHERE p.is_published = true
  AND p.deleted_at IS NULL
  AND o.is_active = true
  AND o.verification_status = 'verified'
ORDER BY p.is_pinned DESC, p.created_at DESC;
