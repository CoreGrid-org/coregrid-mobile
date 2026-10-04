## Summary

<!-- What does this change and why? One or two sentences is fine. -->

## Requirements

<!-- SRS / mobile-spec references this implements or touches, e.g. FR-059, IF-10, mobile-spec §4.3. -->
<!-- Link the tracking issue: Closes #123 -->

- Requirements:
- Issue:

## Ownership and scope

- [ ] Only touches `lib/features/` folders I own — or the owning maintainer is requested as a reviewer (mobile SRS §10, main SRS §12.2)
- [ ] Capability is Flutter-owned per main SRS §3.4's responsibility boundary (not "React: Yes / Flutter: No")
- [ ] No new state-management pattern outside Riverpod (ADR-004)
- [ ] No new hardware dependency beyond camera without a matching SRS requirement (IF-13)

## Testing

<!-- How was this verified? Tests added, manual golden-path run against a real backend, device/emulator used. -->

- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — passing
- [ ] New or changed behaviour has unit/widget tests (mobile-spec §7)
- [ ] Server-side field errors are surfaced, not just client-side validation (IF-03, AR-1)

## Screenshots

<!-- For UI changes: before/after, light and dark if relevant. Delete if not applicable. -->

## Auth / config (delete if not applicable)

- [ ] No token or secret written to logs or shared preferences (SEC-ID-05, §4.8)
- [ ] Sign-out still clears local state (§4.8)
- [ ] API base URL / ThunderID config changes are reflected in `doc/setup/` and `.env.example`

## Docs

- [ ] `doc/mobile-specification.md` updated if a screen's flow, API calls or routes changed
