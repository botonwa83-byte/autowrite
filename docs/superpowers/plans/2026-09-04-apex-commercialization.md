# Apex Commercialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local-first paid creation workflow with project persistence, StoreKit 2 entitlement state, and share/export adapters for seven public platforms.

**Architecture:** Keep SwiftUI/SwiftData and isolate purchase state behind `EntitlementStore`, project CRUD behind SwiftData models, and platform behavior behind `PublishAdapter`. Existing generator and validator remain the content core; UI gates creation/export based on entitlement.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, StoreKit 2, UIKit share sheet, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-04-apex-commercialization-design.md`

## Global Constraints

- Target iOS/iPadOS 17.
- Free users can browse but cannot save/export custom projects.
- Paid users unlock project creation, persistence, export, system sharing, and restore purchases.
- Platforms: 小红书、微信公众号、微信朋友圈、知乎、视频号、抖音、快手.
- Never collect platform credentials; direct publishing is optional and adapter-gated.

### Task 1: Entitlement Service

**Files:** Create `ApexPromoter/Services/EntitlementStore.swift`; modify `ApexPromoter/ApexPromoterApp.swift`; test `ApexPromoterTests/EntitlementStoreTests.swift`.

- [ ] Add `EntitlementState` (`free`, `premium`, `loading`, `unavailable`) and injectable `EntitlementStore` with product ID, `refresh()`, `purchase()`, and `restore()`.
- [ ] Use StoreKit 2 transaction updates and `Transaction.currentEntitlements`; keep a deterministic preview/test initializer.
- [ ] Add tests for free default, premium update, restore failure preservation, and unavailable product configuration.
- [ ] Inject the store into the SwiftUI environment from the app entry point.

### Task 2: Project Persistence Models

**Files:** Modify `ApexPromoter/Models/Models.swift`; modify app model container setup; test `ApexPromoterTests/ProjectModelTests.swift`.

- [ ] Add `PromotionProject`, `ProjectAsset`, and `PublishAttempt` SwiftData models with UUID, title, product ID, content type, target platform, timestamps, status, and failure note fields.
- [ ] Add Codable enums for content type, platform, and publish state; preserve existing `ContentDraft` compatibility.
- [ ] Register all models in the app model container and test insert/fetch/update/delete round trips in an in-memory container.

### Task 3: Platform Adapter and Export Contracts

**Files:** Create `ApexPromoter/Services/PublishAdapters.swift`; modify existing platform enum; test `ApexPromoterTests/PublishAdapterTests.swift`.

- [ ] Define all seven `PublishPlatform` cases and metadata (`isVideo`, title/body/tag limits, supported media types).
- [ ] Define `PublishAdapter` returning `PublishPlan` actions for copy text, export media, system share, and optional direct publish.
- [ ] Implement a local adapter registry with platform-specific formatting and graceful unsupported-action errors.
- [ ] Test every platform has metadata, formatting respects limits, and direct publishing is disabled by default.

### Task 4: Project List and Composer Gating

**Files:** Modify `ApexPromoter/Views/RootView.swift`; create focused `ApexPromoter/Views/ProjectsView.swift` and `ApexPromoter/Views/PaywallView.swift`; test UI flows where practical.

- [ ] Add “我的项目” navigation and project list backed by SwiftData.
- [ ] Add paywall with purchase and restore actions; show locked state for free users.
- [ ] Gate project creation, save, export, and queue insertion on premium entitlement.
- [ ] Move composer save logic into a project-aware flow while preserving existing generation and validation behavior.

### Task 5: Preview, Export, Share History

**Files:** Create `ApexPromoter/Views/PlatformPreviewView.swift`; modify composer and queue views; test export/attempt recording.

- [ ] Add platform picker for the seven platforms and render adapter-provided preview limits.
- [ ] Provide copy, export, and system share actions for text/image/video; record each attempt and failure message.
- [ ] Preserve generated project on share failure and expose retry.

### Task 6: Verification and Release Hygiene

**Files:** Modify `.gitignore`, tests, and release documentation as needed.

- [ ] Run `git diff --check` and all XCTest targets.
- [ ] Run an iOS build with code signing disabled.
- [ ] Verify no credential fields or private login automation exist.
- [ ] Document StoreKit product configuration and platform API prerequisites.
