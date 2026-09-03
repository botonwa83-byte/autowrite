# Apex Social Promoter Design

## Goal

Build an iPhone/iPad SwiftUI app that helps commercial teams turn Apex product materials into reviewed Xiaohongshu promotion drafts and a recurring publishing calendar, without collecting Xiaohongshu passwords or simulating private login flows.

## Scope

The first release is an internal, local-first workbench. It imports product facts and links from the sibling Apex projects and `kingtop-education-site`, generates editable Xiaohongshu-style drafts from those facts, runs basic compliance checks, tracks human approval, and hands the approved draft to the user for manual publication through the system share sheet or browser. It does not promise automatic Xiaohongshu publishing until an approved official API is available.

## Architecture

- SwiftUI app targeting iOS 17 and iPadOS 17, with adaptive navigation for compact and regular width.
- Local persistence using SwiftData: `Product`, `ContentDraft`, `Campaign`, `ReviewEvent`, and `Asset`.
- A deterministic content pipeline separates source facts, draft templates, validation, and UI. AI generation is an injectable service; the first implementation includes a local template generator and leaves a protocol for a future server-backed provider.
- Product facts are bundled as reviewed JSON generated from the sibling Apex websites/projects. The app never reads arbitrary filesystem paths at runtime.
- Publishing is an explicit user action using `ShareLink`/`UIActivityViewController` and a deep link/browser handoff where supported. Credentials remain in the platform app/browser.

## Safety and compliance

- No password, cookie, session token, or device fingerprint collection.
- Every draft records source product IDs and generation time.
- Validation flags missing claims, unsupported numerical promises, contact-spam language, and duplicate text; flagged drafts cannot be marked ready without an explicit override note.
- Human approval is required before a draft enters the publish queue.
- Scheduling creates reminders and queue entries; it does not silently post in the background.

## Initial screens

1. Dashboard: campaigns due, drafts awaiting review, and Apex product shortcuts.
2. Products: searchable product facts and approved assets.
3. Composer: choose product, audience, angle, and tone; generate and edit title/body/tags; see validation findings.
4. Calendar/Queue: schedule, approval status, publish handoff, and result notes.

## Testing and acceptance

- Unit tests cover product fixture integrity, deterministic generation, validation rules, duplicate detection, and approval state transitions.
- UI smoke tests cover creating a draft, editing it, approving it, and invoking the publish handoff.
- Acceptance: app builds for iPhone and iPad simulators; no credential fields exist; an approved draft can be copied/shared; blocked validation is visible and actionable.
