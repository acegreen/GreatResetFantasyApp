# Future Feature Ideas

## User-created polls with admin approval

**Summary:** Allow any logged-in user to create polls via a + toolbar item in PollsView. Polls are stored with `status = 'pending'` and only appear in the main feed after an admin approves them. Admins see a "Polls needing approval" section in the Admin panel (above "Create poll") to approve or reject.

### Implementation outline (when building)

- **Schema:** Add `polls.status` (`'pending' | 'approved'`), default `'pending'`. Migrate existing rows to `'approved'`. RLS: public sees only `status = 'approved'`; admins see all; users can INSERT only with `status = 'pending'`; admins can UPDATE status.
- **PollsView:** + toolbar item when logged in → sheet with PollCreationView in "user" mode (creates pending).
- **PollCreationView:** Parameter e.g. `approvedImmediately: Bool` — from Admin pass `true` (creates approved), from PollsView pass `false` (creates pending).
- **PollService:** `fetchPolls()` filter by `status = 'approved'`; add `fetchPendingPolls()`, `approvePoll(id)` (or `updatePollStatus`); `createPoll(..., status:)`.
- **AdminView:** New section above "Create poll": "Polls needing approval" list with Approve (and optionally Reject/Delete).
- **Models:** Add `status` to `Poll` and `PollInsert`.

### References

- Current poll schema: `Supabase/schema.sql` (polls, poll_options, RLS).
- Poll creation: `AdminViews/PollCreationView.swift`, `Services/PollService.swift`.
- Admin UI: `AdminViews/AdminView.swift`.
- Main feed: `PollsView.swift`, `PollService.fetchPolls()`.
