# Compliance release readiness

This document is an operational release gate, not legal advice or a claim of
certification. The product controls implement a useful baseline; each production
operator remains responsible for the facts of its deployment and the laws that
apply to it.

## Before publishing the legal documents

- Replace deployment placeholders with the controller/business legal name,
  address, privacy contact, rights-holder contact, and applicable jurisdictions.
- Have qualified counsel approve the EULA, Privacy Notice, age/guardian rules,
  governing-law terms, liability terms, and any institution-specific education
  or exam rules.
- Inventory every production processor and subprocessor, including hosting,
  Postgres, MongoDB, object/file storage, Qdrant, AI providers, email, PayPal,
  and LiveKit. Record processing purpose, data categories, location, contract,
  retention, and international-transfer mechanism.
- Confirm that product statements about sale, sharing, advertising, sensitive
  data, and encryption match the actual deployment. Update and version the
  notice before enabling analytics, advertising, or a new data use.

## Privacy operations

- Monitor `/admin/privacy` and verify the requester before disclosing,
  correcting, porting, or deleting personal data. Record a clear response and
  any lawful exception; do not mark an access or deletion request complete just
  because it was received.
- Treat the self-service JSON export as a Postgres snapshot. A cross-service
  request must also search the exam MongoDB, Qdrant/vector store, uploaded-file
  storage, backups, live/voice logs, and configured vendors.
- Publish and enforce a table-by-table retention schedule. Include account and
  session data, source files, generated artifacts, exams, integrity records,
  legal evidence, payment records, support records, audit logs, and backups.
- Test deletion using a synthetic learner. Confirm removal or justified
  retention in every service, revoke active sessions and provider tokens, and
  record completion without copying sensitive data into an administrator note.
- Keep the RAG MCP endpoint on a private service network until transport-level
  authentication is added. Configure `QDRANT_API_KEY`, restart the Agent after
  changing it, and test the fail-closed source-deletion retry path.
- Document incident detection, containment, risk assessment, regulator/user
  notification decisions, and evidence preservation. Restrict forwarded IP
  headers to trusted proxies so acceptance evidence cannot be spoofed by a
  client-supplied header.
- Re-run these checks after adding a vendor, data field, generation workflow,
  tracking technology, or new jurisdiction.

## Accessibility release gate

WCAG defines Levels A, AA, and AAA; there is no Level AAAA. The target for this
project is therefore WCAG 2.2 AAA-oriented readiness. W3C advises against using
whole-site Level AAA as a general policy because some AAA criteria cannot apply
to all content. Do not describe the product as conformant until a qualified
manual audit verifies every applicable success criterion on the released
content and documents any exceptions.

For each release:

- Run lint, production builds, component accessibility tests, and browser axe
  scans in English and Arabic at desktop and mobile widths.
- Complete keyboard-only and screen-reader journeys for registration, legal
  acceptance, upload, curriculum, lecture/raise hand, section, exam, feedback,
  privacy requests, and admin pagination.
- Verify 200% and 400% zoom/reflow, text spacing, focus visibility/order,
  44-by-44 CSS-pixel targets, reduced motion, forced colors, error recovery,
  time limits, and contrast (7:1 normal text, 4.5:1 large text, and 3:1
  essential non-text boundaries where the criterion applies).
- Audit prerecorded/live media requirements separately, including captions,
  transcripts, audio description/media alternatives, and sign-language needs.
- Test Arabic reading order and RTL layout while confirming that generated
  lectures, curricula, sections, exam titles/questions/options, and AI answers
  remain explicitly marked as English LTR content islands.
- Record browser, assistive technology, test account, route, result, issue
  owner, and retest evidence in the release report.

Reference baselines:

- WCAG 2.2: <https://www.w3.org/TR/WCAG22/>
- GDPR information for individuals: <https://commission.europa.eu/law/law-topic/data-protection/information-individuals_en>
- California Consumer Privacy Act: <https://oag.ca.gov/privacy/ccpa>
