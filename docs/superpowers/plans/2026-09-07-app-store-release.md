# App Store Release Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare Apex 宣传台 for App Store submission with a one-time premium unlock while keeping the bundled Apex product catalog free for observation and promotion.

**Architecture:** Keep the local-first SwiftData workflow. Treat bundled Apex products as read-only showcase data, and gate creation/export of user-owned product lines behind the existing StoreKit non-consumable product `com.kingtop.apexpromoter.premium`. Release metadata and privacy declarations live in the app target configuration and App Store Connect checklist.

**Tech Stack:** SwiftUI, SwiftData, StoreKit 2, UserNotifications, XcodeGen, XCTest and XCUITest.

**Spec:** Commercial model confirmed in conversation on 2026-09-07: one-time in-app unlock; bundled Apex products are free to browse and demonstrate the app.

## Global Constraints

- Deployment target remains iOS 17.0.
- Premium product type is non-consumable, not auto-renewable subscription.
- Bundled Apex products remain browseable without purchase.
- User-created product lines and their export/share workflow require premium entitlement.
- Release builds must not force premium state or seed test-only data.
- No platform credentials are stored or submitted by the app.

### Task 1: Release Configuration Baseline

**Files:**
- Modify: `ApexPromoter/Info.plist`
- Modify: `project.yml`
- Modify: `ApexPromoter/ApexPromoterApp.swift`
- Test: `ApexPromoterTests/ContentTests.swift`

- [ ] Set explicit marketing version and incrementing build number for the first submission.
- [ ] Add release-safe app metadata: support URL, privacy policy URL, and category values supplied to App Store Connect.
- [ ] Add a test asserting Debug premium is enabled only by `--ui-testing-premium` and normal Debug starts non-premium/loading.
- [ ] Remove any release-path behavior that inserts showcase data solely for UI testing.
- [ ] Regenerate the Xcode project with `xcodegen generate` and compile the Release configuration.

### Task 2: StoreKit One-Time Unlock

**Files:**
- Modify: `ApexPromoter/Services/EntitlementStore.swift`
- Modify: `ApexPromoter/Views/PaywallView.swift`
- Modify: `ApexPromoter/Views/BrandCenterView.swift`
- Modify: `ApexPromoter/Views/ProjectsView.swift`
- Create: `ApexPromoter/Configuration.storekit`
- Test: `ApexPromoterTests/ContentTests.swift`

- [ ] Define `com.kingtop.apexpromoter.premium` as a non-consumable StoreKit product with localized display name and price for local testing.
- [ ] Keep entitlement restoration based on `Transaction.currentEntitlements` and finish verified transactions.
- [ ] Add a transaction listener so purchases made outside the current view update entitlement state.
- [ ] Show clear one-time purchase wording; do not use subscription terms such as “monthly” or “renewal”.
- [ ] Keep bundled Apex catalog browsing free; gate only user-owned product creation and export/share actions.
- [ ] Add tests covering free showcase access and premium-gated user workflow.

### Task 3: Privacy and Permission Compliance

**Files:**
- Modify: `ApexPromoter/Info.plist`
- Create: `ApexPromoter/PrivacyInfo.xcprivacy`
- Modify: `ApexPromoter/Services/ContentValidator.swift`
- Modify: `ApexPromoter/Views/RootView.swift`

- [ ] Declare photo library usage text explaining image import for promotion materials.
- [ ] Document notification permission purpose and ensure denial leaves the project usable.
- [ ] Add a privacy manifest describing local SwiftData storage, network website fetches, StoreKit transactions, and no tracking.
- [ ] Verify App Privacy answers match actual behavior: user content and purchase history are not sold or used for tracking.

### Task 4: Product Catalog and Showcase Copy

**Files:**
- Modify: `ApexPromoter/Services/ProductCatalog.swift`
- Modify: `ApexPromoter/Views/RootView.swift`
- Modify: `ApexPromoter/Views/HelpView.swift`
- Test: `ApexPromoterTests/ContentTests.swift`

- [ ] Ensure all products with valid App Store URLs display as released, including customer-created products.
- [ ] Label bundled Apex products as free showcase examples without implying they are paid features of the promoter app.
- [ ] Verify the official site links and App Store IDs against `https://botonwa83-byte.github.io/`.
- [ ] Add tests for released status, invalid URL fallback, and free showcase visibility without entitlement.

### Task 5: Release Verification and TestFlight

**Files:**
- Modify: `ApexPromoterUITests/ApexPromoterUITests.swift`
- Create: `docs/release/app-store-checklist.md`

- [ ] Run unit tests on a concrete iOS 17+ simulator.
- [ ] Run XCUITest on iPhone 17 Pro Max: launch, browse Apex products, create brand, attempt premium action, purchase in StoreKit test, restore purchase, import photo, generate content, share, schedule notification, record metrics.
- [ ] Archive a Release build with signing enabled and upload to TestFlight.
- [ ] Complete App Store Connect metadata: screenshots, description, keywords, support URL, privacy policy URL, age rating, review notes, and in-app purchase submission.
- [ ] Test a clean install and an upgrade install before App Store review.
- [ ] Tag the submitted commit and retain the archive and dSYM for rollback.

### Task 6: Submission Gate

**Files:**
- Create: `docs/release/app-store-checklist.md`

- [ ] Confirm the non-consumable product is approved or submitted with the app version.
- [ ] Confirm no debug flags, test URLs, placeholder copy, or forced premium state exist in the Release archive.
- [ ] Confirm screenshots show the usable product workflow, not only a marketing page.
- [ ] Submit for review with concise notes explaining that bundled Apex products are free examples and premium unlocks user-owned promotion workspaces.

