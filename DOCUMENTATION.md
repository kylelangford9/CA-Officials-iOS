# CA Officials iOS App - Complete Documentation

## Overview

**CA Officials** is one half of a two-app ecosystem designed to connect California government officials directly with their constituents:

| App | Target Users | Purpose |
|-----|-------------|---------|
| **CA Voters** | California voters/constituents | Find representatives, view profiles, follow officials, engage with content |
| **CA Officials** | Elected officials & their staff | Verify identity, manage profile, post updates, track engagement analytics |

This app (CA Officials) is the **official-facing** side of the platform, enabling verified government officials to establish their presence and communicate with constituents.

---

## App Purpose

CA Officials enables California government officials to:

1. **Verify their official status** through multiple secure methods
2. **Manage their public profile** visible in the CA Voters app
3. **Post updates, announcements, events, and polls** to engage constituents
4. **Track analytics** on profile views and engagement
5. **Build direct relationships** with voters without intermediaries

---

## User Roles

The app supports 4 distinct user roles:

### 1. Voter (Default)
- Can follow officials and view profiles
- Can see the Connect social feed
- Can view policy positions and contact information
- Cannot post or access official dashboard

### 2. Official (Primary Focus)
- Must complete identity verification
- Full access to profile management and dashboard
- Can create posts, announcements, events, and polls
- Can track analytics and engagement metrics
- Can manage policy positions
- Can view follower activity

### 3. Delegate (Staff Member)
- Delegated access to help manage an official's profile
- Same permissions as officials with configurable restrictions
- Intended for communications directors, schedulers, etc.

### 4. Admin (Future)
- Full system access for platform management
- Not yet implemented

---

## Core Features

### 1. Verification System

Officials must verify their identity before accessing the full platform. Three methods available:

| Method | Time to Verify | How It Works |
|--------|---------------|--------------|
| **Government Email** | Instant | 6-digit code sent to .gov email address |
| **Website Token** | 1-2 hours | Add verification token to official website meta tag |
| **Document Upload** | 1-3 business days | Upload official documents for manual review |

**Verification Flow:**
1. Search for government office by title/jurisdiction
2. Claim unclaimed office
3. Select verification method
4. Complete verification
5. Access granted to dashboard

### 2. Profile Management

Officials can manage comprehensive profile information:

**Basic Information:**
- Name, title, pronouns
- Party affiliation (Democratic, Republican, Independent, Libertarian, Green, Nonpartisan)
- Profile photo and banner image
- Biography (500 character limit)

**Contact Information:**
- Office phone number
- Office email address
- Physical office address
- Mailing address

**Social Links:**
- Official website
- Twitter/X handle
- Facebook URL
- Instagram handle
- LinkedIn URL
- YouTube channel

**Policy Positions:**
- 20 predefined topics (Education, Healthcare, Environment, Economy, etc.)
- Stance: Support, Oppose, or Neutral
- Summary and detailed position text
- Can be featured and reordered

### 3. Dashboard

The official dashboard provides:

**Quick Stats:**
- Total profile views
- Total followers
- Total engagement
- View trend (% change)

**Quick Actions:**
- Create new post
- Edit profile
- View analytics
- Manage followers
- Schedule event
- Share profile

**Recent Activity Feed:**
- Profile views
- Post likes
- New comments
- New followers
- Post shares

### 4. Connect (Social Feed)

Officials can create various types of content:

| Post Type | Description |
|-----------|-------------|
| **Update** | General text/media posts |
| **Announcement** | Important official announcements |
| **Event** | Events with date, location, and RSVP link |
| **Policy** | Policy discussion posts |
| **Media** | Image/video focused content |
| **Poll** | Multiple choice polls for constituent feedback |

**Post Features:**
- Up to 4 media attachments
- Link previews
- Scheduled posting
- Pin important posts
- Like, comment, share, bookmark interactions

**Feed Filters:**
- For You (algorithm-curated)
- Following (from followed officials only)
- Events (event posts only)
- Polls (polls only)

### 5. Analytics

**Daily Metrics:**
- Profile views
- Search appearances
- Unique voters reached
- Link clicks (website, contact, social)
- Traffic source breakdown

**Aggregate Metrics:**
- Total lifetime views
- Unique visitors
- Follower count
- Post performance
- Engagement rate

**Activity Tracking:**
- Profile views
- Post interactions
- New followers/unfollows
- Poll votes
- Event RSVPs

### 6. Settings

**Account Management:**
- Account details
- Change password
- Sign out (clears all cached data)

**Team Management:**
- Staff access management
- Permission controls (can post, can edit)
- Invite new staff members

**Notifications:**
- Push notification preferences
- Weekly email digest toggle

**Privacy:**
- Privacy settings
- Blocked accounts

---

## Technical Architecture

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | SwiftUI (iOS 15+) |
| **Backend** | Supabase (PostgreSQL + Auth + Storage) |
| **State Management** | Combine + SwiftUI property wrappers |
| **Architecture** | MVVM + Singleton Services |

### Project Structure

```
CAOfficialsIOS/
├── Config/
│   ├── DesignSystem.swift      # Colors, typography, spacing, components
│   └── SupabaseConfig.swift    # Supabase connection settings
│
├── Core/
│   ├── Core_RoleManager.swift  # User role and auth state management
│   └── Core_UserRole.swift     # Role enum definitions
│
├── Officials/
│   ├── Models/
│   │   ├── Officials_Official.swift           # Official profile model
│   │   ├── Officials_GovernmentOffice.swift   # Office/position model
│   │   ├── Officials_PolicyPosition.swift     # Policy stance model
│   │   ├── Officials_ProfileAnalytics.swift   # Analytics models
│   │   ├── Officials_Activity.swift           # Activity feed model
│   │   └── Officials_VerificationState.swift  # Verification state machine
│   │
│   ├── Services/
│   │   ├── Officials_ProfileService.swift        # Profile CRUD
│   │   ├── Officials_VerificationService.swift   # Verification flow
│   │   ├── Officials_OfficeSearchService.swift   # Office search/claim
│   │   └── Officials_AnalyticsService.swift      # Analytics tracking
│   │
│   ├── ViewModels/
│   │   ├── Officials_DashboardViewModel.swift
│   │   ├── Officials_ProfileEditorViewModel.swift
│   │   ├── Officials_VerificationViewModel.swift
│   │   └── Officials_AnalyticsViewModel.swift
│   │
│   └── Views/
│       ├── Onboarding/
│       │   └── Officials_WelcomeView.swift     # Sign in/up screens
│       ├── Verification/
│       │   ├── Officials_VerificationFlowView.swift
│       │   ├── Officials_EmailVerifyView.swift
│       │   └── Officials_DocumentUploadView.swift
│       ├── Dashboard/
│       │   └── Officials_DashboardView.swift
│       ├── Profile/
│       │   └── Officials_ProfileEditorView.swift
│       ├── Analytics/
│       │   └── Officials_AnalyticsView.swift
│       └── Settings/
│           └── Officials_SettingsView.swift
│
├── Connect/
│   ├── Models/
│   │   ├── Connect_Post.swift       # Post model with all types
│   │   ├── Connect_Comment.swift    # Comment model
│   │   └── Connect_Follow.swift     # Follow relationship model
│   │
│   ├── Services/
│   │   ├── Connect_FeedService.swift     # Feed fetching/filtering
│   │   ├── Connect_PostService.swift     # Post CRUD, interactions
│   │   └── Connect_FollowService.swift   # Follow/unfollow
│   │
│   ├── ViewModels/
│   │   ├── Connect_FeedViewModel.swift
│   │   └── Connect_ComposeViewModel.swift
│   │
│   └── Views/
│       ├── Connect_FeedView.swift        # Main social feed
│       ├── Connect_PostCard.swift        # Post display component
│       ├── Connect_ComposeSheet.swift    # Create post UI
│       ├── Connect_CommentsSheet.swift   # Comments view
│       └── Connect_OfficialProfileView.swift
│
└── Shared/
    ├── Managers/
    │   └── HapticManager.swift    # Haptic feedback
    └── Utilities/
        └── AppLogger.swift        # Debug logging
```

### Database Schema (Supabase)

**Core Tables:**

```sql
-- Official profiles
officials (
  id, user_id, office_id, name, title, pronouns, party,
  photo_url, banner_url, bio, verification_status,
  verified_at, verification_method, contact_info, social_links,
  is_active, created_at, updated_at
)

-- Government positions
government_offices (
  id, title, level, jurisdiction, district,
  incumbent_name, is_claimed, claimed_by,
  term_start, term_end, website_url
)

-- Policy positions
policy_positions (
  id, official_id, topic, stance, summary,
  detailed_position, is_featured, display_order
)

-- Social posts
posts (
  id, official_id, post_type, content, media_urls,
  link_url, link_preview, event_date, event_location,
  poll_options, poll_ends_at, like_count, comment_count,
  share_count, is_pinned, is_published, scheduled_for
)

-- Comments
comments (
  id, post_id, parent_id, user_id, content,
  like_count, is_hidden, hidden_reason
)

-- Follow relationships
follows (
  id, follower_user_id, official_id,
  notify_posts, notify_events, notify_policy
)

-- Verification requests
verification_requests (
  id, official_id, office_id, method, status,
  verification_code, code_expires_at, website_token,
  document_urls, reviewed_at, reviewer_notes
)

-- Analytics
official_analytics (daily stats)
official_profile_analytics (aggregates)
official_activity (event log)
```

### Design System

The app uses a comprehensive, accessibility-compliant design system:

**Spacing Scale:** 4pt increments (xs: 4pt → xxxxxl: 48pt)

**Typography:** 26+ semantic font styles

**Color Palettes:**
- Content colors (primary, secondary, tertiary)
- Surface colors (base, elevated, floating)
- Brand colors (primary blue, tints, shades)
- Party colors (Democratic blue, Republican red, etc.)
- Status colors (success, warning, error, info)

**Accessibility:**
- WCAG 2.2 AA compliant (4.5:1 contrast minimum)
- Dynamic Type support
- Reduce Motion support
- High Contrast mode support

---

## Implementation Status

### Fully Implemented
- Authentication flow (sign up/sign in UI)
- Role management system
- 3-method verification system
- Office search and claiming
- Profile management with all fields
- Policy positions CRUD
- All 6 post types
- Comment system with replies
- Like, bookmark, share interactions
- Poll voting
- Follow/unfollow system
- Analytics display
- Activity feed
- Dashboard with stats
- Complete design system
- Haptic feedback throughout
- Form validation
- Error handling
- Loading states with shimmer animations

### Simulated (Ready for Backend Integration)
- Supabase Auth calls (currently 2-second delays)
- Email sending for verification codes
- Website token verification
- Image uploads to Supabase Storage

### Not Yet Implemented
- Real Supabase Auth integration
- Edge Functions for emails
- Push notifications
- Admin dashboard
- Delegate role management UI
- Real-time updates (WebSocket)

---

## Security Features

- Row Level Security (RLS) on all database tables
- Verification codes expire in 15 minutes
- Soft deletes for audit trail
- Hidden comment tracking with reasons
- Attempt limiting on verification
- Cache clearing on sign out

---

## Related Apps

This app is designed to work alongside:

- **CA Voters** - The voter-facing app where constituents discover and follow officials
- Shares the same Supabase backend
- Officials' profiles and posts appear in both apps

---

## File Statistics

- **56 Swift files**
- **~17,600 lines of code**
- **4 modules** (Core, Officials, Connect, Shared)
- **7 services** handling backend operations
- **9+ major views** for user flows
- **1,690 lines** for design system alone

---

## Getting Started (Development)

1. Clone the repository
2. Open `CAOfficials.xcodeproj` in Xcode
3. Configure Supabase credentials in `SupabaseConfig.swift`
4. Run database migrations from `supabase/migrations/`
5. Build and run on iOS Simulator or device

---

## Version

- **Current Version:** 1.0.0 (1)
- **iOS Target:** 15.0+
- **Swift Version:** 5.0+

---

*Last Updated: January 2026*
