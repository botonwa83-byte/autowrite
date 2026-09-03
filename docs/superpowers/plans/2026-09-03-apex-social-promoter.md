# Apex Social Promoter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local-first SwiftUI iPhone/iPad workbench for safe, reviewed Xiaohongshu promotion of Apex products.

**Architecture:** SwiftUI + SwiftData, bundled reviewed product fixtures, deterministic content services behind protocols, and explicit manual share/browser handoff for publishing.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-03-apex-social-promoter-design.md`

## Global Constraints

- Target iOS 17 and iPadOS 17.
- Never collect Xiaohongshu passwords, cookies, or session tokens.
- Human approval is required before publish handoff.
- Generated claims must be traceable to bundled product facts.

### Task 1: Xcode project and app shell

**Files:** Create `project.yml`, `ApexPromoter/ApexPromoterApp.swift`, `ApexPromoter/Views/RootView.swift`, `ApexPromoter/Theme/Theme.swift`, and XCTest target files.

- [ ] Define an XcodeGen project with iOS/iPadOS target, SwiftData entitlement-free configuration, and unit/UI test targets.
- [ ] Add a tab/sidebar root with Dashboard, Products, Composer, and Queue destinations.
- [ ] Build and run unit tests on an iPhone simulator.

### Task 2: Product fixtures and SwiftData models

**Files:** Create `ApexPromoter/Models/Models.swift`, `ApexPromoter/Services/ProductCatalog.swift`, `ApexPromoter/Resources/products.json`, and model tests.

- [ ] Define Codable fixture records and SwiftData models for products, drafts, campaigns, review events, and assets.
- [ ] Add reviewed Apex fixtures with product name, audience, claims, store/site URL, and source URL.
- [ ] Load fixtures idempotently on first launch and test IDs, required fields, and duplicate prevention.

### Task 3: Composer and validation pipeline

**Files:** Create `ApexPromoter/Services/ContentGenerator.swift`, `ApexPromoter/Services/ContentValidator.swift`, `ApexPromoter/Views/ComposerView.swift`, and service tests.

- [ ] Implement `ContentGenerating` and a deterministic local generator producing title, body, and tags from a `Product` plus angle/tone.
- [ ] Implement `ContentValidator` findings for unsupported claims, spam/contact language, excessive repetition, and missing source references.
- [ ] Build editable composer UI with generation, findings, and source fact links.

### Task 4: Review, scheduling, and publish handoff

**Files:** Create `ApexPromoter/Services/WorkflowService.swift`, `ApexPromoter/Views/QueueView.swift`, `ApexPromoter/Views/DashboardView.swift`, and workflow/UI tests.

- [ ] Enforce draft states `draft`, `needsReview`, `approved`, `scheduled`, `published` with override notes for blocking findings.
- [ ] Add calendar date/time scheduling, due list, approval history, and publish notes.
- [ ] Implement copy/share handoff for approved content only; never perform background posting.

### Task 5: iPad polish and verification

- [ ] Add regular-width NavigationSplitView layout, Dynamic Type support, accessibility labels, and empty/error states.
- [ ] Run `xcodebuild test` for iPhone and iPad destinations and UI smoke tests.
- [ ] Run `git diff --check` and document the manual Xiaohongshu publishing flow in `README.md`.
