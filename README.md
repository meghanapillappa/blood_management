# Blood Bank Coordination (Next.js + MySQL + MongoDB)

**SQL:** MySQL 8 holds the schema in `db/schema.sql` (tables, views, triggers, stored procedures `sp_RegisterDonation` / `sp_ConfirmMatch`).
**NoSQL:** MongoDB stores an append-only audit trail of every change (`bloodbank_nosql.audit_log`).

## Run
1. `mysql -u root -p < db/schema.sql`  (recreates `blood_bank_system` with sample data)
2. Start MongoDB locally (optional; the app works without it, the Audit trail tab just shows a notice)
3. `cp .env.example .env.local` and fill in your MySQL password
4. `npm install && npm run dev` then open http://localhost:3000

## What each screen does
- Overview: live stock bags, critical requests, expiring units, donors ready to give again
- Inventory: stock by hospital, unit status changes, discard expired units
- Requests & matching: create requests, find compatible units (ABO/Rh rules), propose, confirm (calls `sp_ConfirmMatch`), fulfil, cancel (releases reserved units)
- Donors, Camps, Hospitals, Users: add / edit / delete (users store bcrypt hashes)
- Donations: calls `sp_RegisterDonation`; checks latest eligibility and the 56-day gap first
- Eligibility: record checks and full-text search remarks (`MATCH ... AGAINST`)
- Audit trail: reads from MongoDB
