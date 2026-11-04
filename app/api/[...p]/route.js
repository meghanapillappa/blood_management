import { q, audit, audits } from '@/lib/db';
import bcrypt from 'bcryptjs';
export const dynamic = 'force-dynamic';

// table config for generic CRUD: [table, primary key, writable columns, allow create]
const T = {
  donors: ['Donor', 'donor_id', ['name', 'gender', 'dob', 'phone', 'email', 'address', 'blood_group_id'], 1],
  hospitals: ['Hospital', 'hospital_id', ['name', 'address', 'city', 'phone', 'email', 'license_no'], 1],
  camps: ['DonationCamp', 'camp_id', ['camp_name', 'location', 'organizer', 'camp_date', 'start_time', 'end_time'], 1],
  eligibility: ['EligibilityCheck', 'eligibility_id', ['donor_id', 'check_date', 'hemoglobin_level', 'weight_kg', 'blood_pressure', 'is_eligible', 'remarks'], 1],
  requests: ['BloodRequest', 'request_id', ['hospital_id', 'patient_name', 'blood_group_id', 'units_required', 'request_date', 'urgency_level'], 1],
  units: ['BloodUnit', 'unit_id', ['status', 'storage_location'], 0],
  matches: ['Matching', 'match_id', ['request_id', 'unit_id'], 1],
  users: ['UserAccount', 'user_id', ['email', 'role', 'hospital_id', 'donor_id', 'is_active'], 0],
};
const L = {
  donors: 'SELECT d.*, bg.group_name FROM Donor d JOIN BloodGroup bg USING(blood_group_id) ORDER BY donor_id DESC',
  hospitals: 'SELECT * FROM Hospital ORDER BY hospital_id',
  camps: 'SELECT * FROM DonationCamp ORDER BY camp_date DESC',
  eligibility: 'SELECT e.*, d.name donor FROM EligibilityCheck e JOIN Donor d USING(donor_id) ORDER BY check_date DESC, eligibility_id DESC',
  requests: `SELECT r.*, h.name hospital, bg.group_name FROM BloodRequest r JOIN Hospital h USING(hospital_id) JOIN BloodGroup bg USING(blood_group_id)
    ORDER BY FIELD(r.status,'Pending','Matched','Fulfilled','Cancelled'), FIELD(r.urgency_level,'Critical','High','Medium','Low'), request_id`,
  units: `SELECT u.*, bg.group_name, h.name hospital FROM BloodUnit u JOIN BloodGroup bg USING(blood_group_id) JOIN Hospital h USING(hospital_id) ORDER BY unit_id DESC`,
  donations: `SELECT dn.*, d.name donor, h.name hospital, c.camp_name FROM Donation dn JOIN Donor d USING(donor_id)
    LEFT JOIN Hospital h USING(hospital_id) LEFT JOIN DonationCamp c USING(camp_id) ORDER BY donation_id DESC`,
  matches: `SELECT m.*, r.patient_name, bg.group_name request_group, ug.group_name unit_group, h.name unit_hospital
    FROM Matching m JOIN BloodRequest r USING(request_id) JOIN BloodGroup bg ON bg.blood_group_id=r.blood_group_id
    JOIN BloodUnit u USING(unit_id) JOIN BloodGroup ug ON ug.blood_group_id=u.blood_group_id JOIN Hospital h ON h.hospital_id=u.hospital_id ORDER BY match_id DESC`,
  users: 'SELECT user_id,email,role,hospital_id,donor_id,is_active,created_at FROM UserAccount ORDER BY user_id',
  critical: 'SELECT * FROM vw_PendingCriticalRequests',
  history: 'SELECT * FROM vw_DonorDonationHistory ORDER BY total_donations DESC, donor_id',
};
const READY = `SELECT d.donor_id, d.name, bg.group_name, MAX(dn.donation_date) last_donation FROM Donor d
  JOIN BloodGroup bg USING(blood_group_id) LEFT JOIN Donation dn ON dn.donor_id=d.donor_id GROUP BY d.donor_id, d.name, bg.group_name
  HAVING last_donation IS NULL OR last_donation <= DATE_SUB(CURDATE(), INTERVAL 56 DAY)`;
// which donor groups can safely give to each recipient group
const COMPAT = { 'A+': ['A+', 'A-', 'O+', 'O-'], 'A-': ['A-', 'O-'], 'B+': ['B+', 'B-', 'O+', 'O-'], 'B-': ['B-', 'O-'],
  'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], 'AB-': ['A-', 'B-', 'AB-', 'O-'], 'O+': ['O+', 'O-'], 'O-': ['O-'] };
const clean = (c, b) => c.filter(k => k in b).map(k => [k, b[k] === '' ? null : b[k]]);

async function run(m, r, id, a, b, sp) {
  const t = T[r];
  if (m === 'GET') {
    if (r === 'lookups') return {
      groups: await q('SELECT * FROM BloodGroup'), hospitals: await q('SELECT hospital_id, name FROM Hospital ORDER BY name'),
      donors: await q('SELECT donor_id, name, blood_group_id FROM Donor ORDER BY name'), camps: await q('SELECT camp_id, camp_name FROM DonationCamp ORDER BY camp_date DESC') };
    if (r === 'stats') return {
      totals: (await q(`SELECT (SELECT COUNT(*) FROM Donor) donors, (SELECT COUNT(*) FROM Hospital) hospitals,
        (SELECT COUNT(*) FROM BloodRequest WHERE status='Pending') pending, (SELECT COUNT(*) FROM Donation) donations,
        (SELECT COUNT(*) FROM BloodUnit WHERE status='Available') available`))[0],
      byGroup: await q('SELECT group_name, CAST(SUM(units_available) AS UNSIGNED) units FROM vw_AvailableInventory GROUP BY group_name ORDER BY group_name'),
      expiring: await q(`SELECT u.unit_id, bg.group_name, h.name hospital, u.expiry_date FROM BloodUnit u JOIN BloodGroup bg USING(blood_group_id)
        JOIN Hospital h USING(hospital_id) WHERE u.status='Available' AND u.expiry_date <= DATE_ADD(CURDATE(), INTERVAL 7 DAY) ORDER BY expiry_date`),
      critical: await q(L.critical), ready: await q(READY) };
    if (r === 'inventory') return q(`SELECT * FROM vw_AvailableInventory ${sp.get('hospital') ? 'WHERE hospital_id=?' : ''} ORDER BY hospital_name, group_name`, [sp.get('hospital')]);
    if (r === 'ready') return q(READY);
    if (r === 'audit') return (await audits()) ?? { offline: true };
    if (r === 'eligibility' && sp.get('search'))
      return q(`SELECT e.*, d.name donor FROM EligibilityCheck e JOIN Donor d USING(donor_id) WHERE MATCH(remarks) AGAINST (? IN NATURAL LANGUAGE MODE)`, [sp.get('search')]);
    if (r === 'requests' && a === 'suggest') {
      const [rq] = await q('SELECT r.hospital_id, bg.group_name FROM BloodRequest r JOIN BloodGroup bg USING(blood_group_id) WHERE request_id=?', [id]);
      return q(`SELECT u.unit_id, u.expiry_date, u.storage_location, bg.group_name, h.name hospital, h.city FROM BloodUnit u
        JOIN BloodGroup bg USING(blood_group_id) JOIN Hospital h USING(hospital_id)
        WHERE u.status='Available' AND u.expiry_date >= CURDATE() AND bg.group_name IN (?) AND u.unit_id NOT IN (SELECT unit_id FROM Matching WHERE request_id=?)
        ORDER BY (u.hospital_id=?) DESC, (bg.group_name=?) DESC, u.expiry_date`, [COMPAT[rq.group_name], id, rq.hospital_id, rq.group_name]);
    }
    if (L[r]) return q(L[r]);
  }
  if (m === 'POST') {
    if (r === 'donations') {
      const [d] = await q('SELECT blood_group_id FROM Donor WHERE donor_id=?', [b.donor_id]);
      if (!d) throw new Error('Donor not found');
      const [e] = await q('SELECT is_eligible FROM EligibilityCheck WHERE donor_id=? ORDER BY check_date DESC, eligibility_id DESC LIMIT 1', [b.donor_id]);
      if (e && !e.is_eligible) throw new Error('Latest eligibility check says this donor is not eligible');
      const [l] = await q('SELECT DATEDIFF(CURDATE(), MAX(donation_date)) days FROM Donation WHERE donor_id=?', [b.donor_id]);
      if (l.days !== null && l.days < 56) throw new Error(`Donor gave blood ${l.days} days ago; wait at least 56 days`);
      await q('CALL sp_RegisterDonation(?,?,?,?,?,?,?)', [b.donor_id, b.camp_id || null, b.hospital_id, b.quantity_ml, b.staff_name || null, d.blood_group_id, b.expiry_days || 42]);
      return { ok: 1 };
    }
    if (r === 'units' && id === 'discard-expired') {
      const x = await q(`UPDATE BloodUnit SET status='Discarded', storage_location='Disposal-Bin' WHERE status='Available' AND expiry_date < CURDATE()`);
      await q(`UPDATE Matching m JOIN BloodUnit u USING(unit_id) SET m.status='Rejected' WHERE u.status='Discarded' AND m.status='Proposed'`);
      return { discarded: x.affectedRows };
    }
    if (r === 'matches' && a === 'confirm') { await q('CALL sp_ConfirmMatch(?)', [id]); return { ok: 1 }; }
    if (r === 'matches' && a === 'reject') { await q(`UPDATE Matching SET status='Rejected' WHERE match_id=?`, [id]); return { ok: 1 }; }
    if (r === 'users') {
      if (!b.password) throw new Error('Password is required');
      const x = await q('INSERT INTO UserAccount (email,password_hash,role,hospital_id,donor_id) VALUES (?,?,?,?,?)',
        [b.email, await bcrypt.hash(b.password, 10), b.role, b.hospital_id || null, b.donor_id || null]);
      return { id: x.insertId };
    }
    if (t?.[3]) {
      const f = clean(t[2], b);
      const x = await q(`INSERT INTO ${t[0]} (${f.map(e => e[0])}) VALUES (${f.map(() => '?')})`, f.map(e => e[1]));
      return { id: x.insertId };
    }
  }
  if ((m === 'PUT' || m === 'PATCH') && t) {
    if (r === 'requests' && b.status) {  // request lifecycle keeps blood units in sync
      if (b.status === 'Fulfilled') await q(`UPDATE BloodUnit SET status='Used' WHERE unit_id IN (SELECT unit_id FROM Matching WHERE request_id=? AND status='Confirmed')`, [id]);
      if (b.status === 'Cancelled') {
        await q(`UPDATE BloodUnit SET status='Available' WHERE status='Reserved' AND unit_id IN (SELECT unit_id FROM Matching WHERE request_id=? AND status='Confirmed')`, [id]);
        await q(`UPDATE Matching SET status='Rejected' WHERE request_id=? AND status IN ('Proposed','Confirmed')`, [id]);
      }
      await q('UPDATE BloodRequest SET status=? WHERE request_id=?', [b.status, id]);
      return { ok: 1 };
    }
    const f = clean(t[2], b);
    if (f.length) await q(`UPDATE ${t[0]} SET ${f.map(e => e[0] + '=?')} WHERE ${t[1]}=?`, [...f.map(e => e[1]), id]);
    return { ok: 1 };
  }
  if (m === 'DELETE' && t) { await q(`DELETE FROM ${t[0]} WHERE ${t[1]}=?`, [id]); return { ok: 1 }; }
  throw new Error('Unknown endpoint');
}

async function handle(req, { params }, m) {
  const [r, id, a] = params.p;
  const b = m === 'GET' || m === 'DELETE' ? {} : await req.json().catch(() => ({}));
  try {
    const out = await run(m, r, id, a, b, new URL(req.url).searchParams);
    if (m !== 'GET') await audit({ method: m, path: params.p.join('/'), body: { ...b, password: undefined } });
    return Response.json(out);
  } catch (e) { return Response.json({ error: e.sqlMessage || e.message }, { status: 400 }); }
}
export const GET = (r, c) => handle(r, c, 'GET');
export const POST = (r, c) => handle(r, c, 'POST');
export const PUT = (r, c) => handle(r, c, 'PUT');
export const PATCH = (r, c) => handle(r, c, 'PATCH');
export const DELETE = (r, c) => handle(r, c, 'DELETE');
