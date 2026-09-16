# Project Memory

## Product Positioning

Apex Promoter is a growth workspace for independent developers and small app teams without a dedicated marketing department. It helps users understand a product, define an audience, create a promotion strategy, produce platform-specific content, schedule distribution, and review results.

Apex is the first real validation customer and a built-in example brand. Product architecture must remain generic enough for customer-owned apps and must not hard-code education-app assumptions into shared workflows.

## Customer Jobs

- Turn technical features into clear user value.
- Identify target users, usage scenarios, objections, and differentiation.
- Plan consistent promotion with limited time and budget.
- Produce native-feeling content for Xiaohongshu, WeChat Official Accounts, Moments, Zhihu, Channels, Douyin, and Kuaishou.
- Track exposure, engagement, link clicks, downloads, and conversion where data is available.
- Learn which product, platform, topic, and creative angle should be repeated or stopped.

## Commercial Model

- Free: use the built-in Apex series products end to end — browse references, generate copy, import media, export packages, schedule into the publishing queue, and record results.
- Premium (one-time, non-consumable): create and promote your own brands and products. Creating a brand or product, and running a promotion project against a self-owned product, requires the unlock.
- The Apex series is Kingtop's own product line, kept in the app for Kingtop's own promotion. Free use of it is intentional, not a trial.
- Entitlement policy lives in `ApexPromoter/Services/ProductAccess.swift`; views never inspect StoreKit transaction details directly.
- Entitlements are verified with StoreKit 2 on launch and whenever the app returns to the foreground. Unconfigured products or no network must surface as `unavailable`, never as fake premium.

## Product Roadmap

1. Brand workspaces and customer-owned product profiles.
2. Audience and market insight records with fact/assumption labeling.
3. Promotion goals: download growth, product launch, and version update.
4. Seven-day and thirty-day plans with batch content generation.
5. Platform publishing workspace with export/share first and official direct APIs only when authorized.
6. Performance review and next-cycle recommendations.

## Current Implementation Status

- Brand workspaces and customer-owned product profiles are implemented.
- Customer products can create promotion projects using their own profile and brand voice.
- Audience and market insights support audience, scenario, pain point, objection, and competitor records.
- Every insight is explicitly marked as verified evidence or a hypothesis to validate, with an optional source URL.
- Promotion goals support download growth, product launches, and version updates, including baseline, target, deadline, and customer action.
- Goal-based projects retain internal KPI context but publish only the customer action; only verified insights are allowed into generated copy.
- Seven-day and thirty-day promotion plans support publishing frequency, multi-platform rotation, optional goal linkage, and scheduled batch project generation.
- Batch projects rotate customer-value angles and enter the existing publishing queue with product, goal, and verified-insight snapshots.
- Performance review covers exposure, engagement, link clicks, downloads, platform comparisons, and content-angle comparisons using user-recorded outcomes.
- Recommendations prioritize downstream results over raw exposure and remain explicitly framed as directions to validate, not guaranteed conclusions.
- Customer products can import their own websites through code/noise cleaning, structured positioning/audience/benefit extraction, editable confirmation, and source snapshot preservation.
- Website imports never overwrite a customer profile until the user explicitly confirms the structured preview; custom project regeneration can re-read the customer website.
- An in-app seven-step guide covers brand setup, website import, customer insight, goals, plans, publishing, and performance review. It opens on first use and remains available from the dashboard.
- Free users get the full workflow on Apex series products; the unlock only gates creating and promoting their own brands and products.
- Next priority: promotion-readiness checks that identify missing product facts, verified customer evidence, goals, and usable media before batch creation.

## Product Principles

- Optimize for customer outcomes, not text generation volume.
- Never collect third-party platform passwords, cookies, or private sessions.
- Preserve sources and distinguish verified facts from inferred marketing suggestions.
- Always provide export/system-share fallback when direct publishing is unavailable.
- Validate every generic capability using Apex before presenting it as customer-ready.
