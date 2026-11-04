'use client';
import { useEffect, useState, useCallback, createContext, useContext } from 'react';

const api = async (path, method = 'GET', body) => {
  const r = await fetch('/api/' + path, { method, headers: { 'content-type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error);
  return j;
};
const Ctx = createContext({});
const BADGE = new Set(['status', 'urgency_level', 'role']);
const YN = new Set(['is_eligible', 'is_active']);
const cell = (k, v) => v == null || v === '' ? '—' : YN.has(k) ? (v ? 'Yes' : 'No') : BADGE.has(k) ? <span className={'b ' + v}>{v}</span> : String(v);

function Table({ cols, rows, actions }) {
  if (!rows.length) return <p className="empty">Nothing here yet.</p>;
  return <table><thead><tr>{cols.map(c => <th key={c[0]}>{c[1]}</th>)}{actions && <th />}</tr></thead>
    <tbody>{rows.map((r, i) => <tr key={i}>{cols.map(c => <td key={c[0]}>{cell(c[0], r[c[0]])}</td>)}{actions && <td><div className="row">{actions(r)}</div></td>}</tr>)}</tbody></table>;
}

function Field({ f, v, set }) {
  const { lk } = useContext(Ctx);
  const [n, l, t, o, opt] = f;
  const opts = t !== 'select' ? [] : (o === 'groups' ? lk.groups?.map(g => [g.blood_group_id, g.group_name]) : o === 'hospitals' ? lk.hospitals?.map(h => [h.hospital_id, h.name])
    : o === 'donors' ? lk.donors?.map(d => [d.donor_id, d.name]) : o === 'camps' ? lk.camps?.map(c => [c.camp_id, c.camp_name]) : o)?.map(x => Array.isArray(x) ? x : [x, x]);
  return <label>{l}{opt ? ' (optional)' : ''}
    {t === 'select' ? <select value={v ?? ''} required={!opt} onChange={e => set(e.target.value)}><option value="">Select…</option>{opts?.map(x => <option key={x[0]} value={x[0]}>{x[1]}</option>)}</select>
      : t === 'check' ? <input type="checkbox" checked={!!v} onChange={e => set(e.target.checked)} />
      : <input type={t} step={t === 'number' ? 'any' : undefined} value={v ?? ''} required={!opt} onChange={e => set(e.target.value)} />}</label>;
}

// Generic list + add/edit/delete screen driven by a small config
function Resource({ res, pk, cols, fields, add = 'Add', canEdit = true, canDel = true, canAdd = true, extra, onChange, toolbar, query = '' }) {
  const { toast, reloadLk } = useContext(Ctx);
  const [rows, setRows] = useState([]); const [s, setS] = useState(''); const [form, setForm] = useState(null);
  const load = useCallback(() => api(res + query).then(setRows).catch(e => toast(e.message, 1)), [res, query]);
  useEffect(() => { load(); }, [load]);
  const done = m => { toast(m); setForm(null); load(); reloadLk(); onChange?.(); };
  const save = async e => { e.preventDefault(); try { await api(form.id ? `${res}/${form.id}` : res, form.id ? 'PUT' : 'POST', form.v); done('Saved'); } catch (x) { toast(x.message, 1); } };
  const del = async r => { if (!confirm('Delete this record? This cannot be undone.')) return; try { await api(`${res}/${r[pk]}`, 'DELETE'); done('Deleted'); } catch (x) { toast(x.message, 1); } };
  const shown = rows.filter(r => JSON.stringify(r).toLowerCase().includes(s.toLowerCase()));
  return <div className="panel">
    <div className="bar"><input className="grow" placeholder="Search this list" aria-label="Search" value={s} onChange={e => setS(e.target.value)} />{toolbar?.(load)}
      {canAdd && <button className="btn p" onClick={() => setForm({ v: Object.fromEntries(fields.filter(f => f[2] === 'check').map(f => [f[0], true])) })}>{add}</button>}</div>
    <Table cols={cols} rows={shown} actions={r => <>{extra?.(r, done)}{canEdit && <button className="btn sm" onClick={() => setForm({ id: r[pk], v: { ...r } })}>Edit</button>}{canDel && <button className="btn sm d" onClick={() => del(r)}>Delete</button>}</>} />
    {form && <div className="modal" onClick={e => e.target === e.currentTarget && setForm(null)}><form onSubmit={save}>
      <h3>{form.id ? 'Edit record' : add}</h3>
      {fields.filter(f => form.id ? !f[5] : true).map(f => <Field key={f[0]} f={f} v={form.v[f[0]]} set={x => setForm({ ...form, v: { ...form.v, [f[0]]: x } })} />)}
      <div className="row"><button type="button" className="btn" onClick={() => setForm(null)}>Cancel</button><button className="btn p">Save</button></div></form></div>}
  </div>;
}

function Bags({ rows }) {
  const max = Math.max(8, ...rows.map(r => r.units));
  return <div className="bags">{rows.map(r => <div key={r.group_name} className={'bag' + (r.units < 2 ? ' low' : '')} title={`${r.units} units of ${r.group_name}`}>
    <i style={{ height: Math.max(r.units / max * 100, 4) + '%' }} /><div><b>{r.group_name}</b><span>{r.units} units</span></div></div>)}</div>;
}

function Overview() {
  const [s, setS] = useState(); const { toast } = useContext(Ctx);
  useEffect(() => { api('stats').then(setS).catch(e => toast(e.message, 1)); }, []);
  if (!s) return <p className="empty">Loading…</p>;
  const t = s.totals;
  return <>
    <div className="stats">{[['Available units', t.available], ['Pending requests', t.pending], ['Donors', t.donors], ['Donations', t.donations], ['Hospitals', t.hospitals]].map(x => <div key={x[0]}><b>{x[1]}</b><span>{x[0]}</span></div>)}</div>
    <div className="panel"><h3>Blood in stock across all hospitals</h3><Bags rows={s.byGroup} /></div>
    <div className="two">
      <div className="panel"><h3>High and critical requests waiting</h3><Table cols={[['patient_name', 'Patient'], ['hospital_name', 'Hospital'], ['group_name', 'Group'], ['units_required', 'Units'], ['urgency_level', 'Urgency']]} rows={s.critical} /></div>
      <div className="panel"><h3>Units expiring within 7 days</h3><Table cols={[['unit_id', 'Unit'], ['group_name', 'Group'], ['hospital', 'Hospital'], ['expiry_date', 'Expires']]} rows={s.expiring} /></div>
    </div>
    <div className="panel"><h3>Donors ready to give again (56+ days since last donation)</h3><Table cols={[['name', 'Donor'], ['group_name', 'Group'], ['last_donation', 'Last donation']]} rows={s.ready} /></div>
  </>;
}

function Inventory() {
  const { lk, toast } = useContext(Ctx); const [h, setH] = useState(''); const [rows, setRows] = useState([]); const [tick, setTick] = useState(0);
  useEffect(() => { api('inventory' + (h ? '?hospital=' + h : '')).then(setRows).catch(e => toast(e.message, 1)); }, [h, tick]);
  const byG = Object.values(rows.reduce((a, r) => ((a[r.group_name] ??= { group_name: r.group_name, units: 0 }).units += r.units_available, a), {})).sort((a, b) => a.group_name.localeCompare(b.group_name));
  const setStatus = async (u, status, done) => { try { await api('units/' + u.unit_id, 'PUT', { status }); done('Unit updated'); setTick(x => x + 1); } catch (x) { toast(x.message, 1); } };
  const sweep = async load => { try { const r = await api('units/discard-expired', 'POST'); toast(`${r.discarded} expired unit(s) discarded`); load(); setTick(x => x + 1); } catch (x) { toast(x.message, 1); } };
  return <>
    <div className="panel"><div className="bar"><label>Hospital <select value={h} onChange={e => setH(e.target.value)}><option value="">All hospitals</option>{lk.hospitals?.map(x => <option key={x.hospital_id} value={x.hospital_id}>{x.name}</option>)}</select></label></div><Bags rows={byG} /></div>
    <h3 style={{ margin: '0 0 10px' }}>Blood units</h3>
    <Resource key={tick} res="units" pk="unit_id" canAdd={false} canDel={false} canEdit={false}
      cols={[['unit_id', 'Unit'], ['group_name', 'Group'], ['hospital', 'Hospital'], ['collection_date', 'Collected'], ['expiry_date', 'Expires'], ['status', 'Status'], ['storage_location', 'Storage']]}
      toolbar={load => <button className="btn" onClick={() => sweep(load)}>Discard expired units</button>}
      extra={(u, done) => <select aria-label="Change status" value={u.status} onChange={e => setStatus(u, e.target.value, done)}>{['Available', 'Reserved', 'Used', 'Discarded'].map(x => <option key={x}>{x}</option>)}</select>} fields={[]} />
  </>;
}

function Requests() {
  const { toast } = useContext(Ctx); const [sel, setSel] = useState(null); const [sug, setSug] = useState([]); const [tick, setTick] = useState(0);
  useEffect(() => { sel ? api(`requests/${sel.request_id}/suggest`).then(setSug).catch(e => toast(e.message, 1)) : setSug([]); }, [sel, tick]);
  const act = async (fn, msg) => { try { await fn(); toast(msg); setTick(x => x + 1); } catch (x) { toast(x.message, 1); } };
  const F = [['hospital_id', 'Hospital', 'select', 'hospitals'], ['patient_name', 'Patient name', 'text'], ['blood_group_id', 'Blood group needed', 'select', 'groups'], ['units_required', 'Units required', 'number'], ['request_date', 'Needed on', 'date'], ['urgency_level', 'Urgency', 'select', ['Low', 'Medium', 'High', 'Critical']]];
  return <>
    <Resource key={'r' + tick} res="requests" pk="request_id" add="New request" onChange={() => setTick(x => x + 1)} fields={F}
      cols={[['request_id', '#'], ['patient_name', 'Patient'], ['hospital', 'Hospital'], ['group_name', 'Group'], ['units_required', 'Units'], ['request_date', 'Needed on'], ['urgency_level', 'Urgency'], ['status', 'Status']]}
      extra={(r, done) => <>{['Pending', 'Matched'].includes(r.status) && <button className="btn sm" onClick={() => setSel(r)}>Find units</button>}
        {r.status === 'Matched' && <button className="btn sm" onClick={() => api('requests/' + r.request_id, 'PATCH', { status: 'Fulfilled' }).then(() => done('Request fulfilled')).catch(e => toast(e.message, 1))}>Mark fulfilled</button>}
        {['Pending', 'Matched'].includes(r.status) && <button className="btn sm d" onClick={() => api('requests/' + r.request_id, 'PATCH', { status: 'Cancelled' }).then(() => done('Request cancelled')).catch(e => toast(e.message, 1))}>Cancel</button>}</>} />
    {sel && <div className="panel"><div className="bar"><h3 className="grow" style={{ margin: 0 }}>Compatible units for {sel.patient_name} ({sel.group_name}, {sel.units_required} needed)</h3><button className="btn" onClick={() => setSel(null)}>Close</button></div>
      <Table cols={[['unit_id', 'Unit'], ['group_name', 'Group'], ['hospital', 'Hospital'], ['city', 'City'], ['expiry_date', 'Expires'], ['storage_location', 'Storage']]} rows={sug}
        actions={u => <button className="btn sm p" onClick={() => act(() => api('matches', 'POST', { request_id: sel.request_id, unit_id: u.unit_id }), 'Match proposed')}>Propose match</button>} /></div>}
    <h3 style={{ margin: '0 0 10px' }}>Matches</h3>
    <Resource key={'m' + tick} res="matches" pk="match_id" canAdd={false} canEdit={false} fields={[]}
      cols={[['match_id', '#'], ['patient_name', 'Patient'], ['request_group', 'Needs'], ['unit_id', 'Unit'], ['unit_group', 'Unit group'], ['unit_hospital', 'Held at'], ['status', 'Status']]}
      extra={m => m.status === 'Proposed' && <><button className="btn sm p" onClick={() => act(() => api(`matches/${m.match_id}/confirm`, 'POST'), 'Match confirmed; unit reserved')}>Confirm</button>
        <button className="btn sm" onClick={() => act(() => api(`matches/${m.match_id}/reject`, 'POST'), 'Match rejected')}>Reject</button></>} />
  </>;
}

function Eligibility() {
  const [q, setQ] = useState(''); const [go, setGo] = useState('');
  return <><div className="panel"><form className="bar" onSubmit={e => { e.preventDefault(); setGo(q.trim()); }}>
    <input className="grow" placeholder="Search remarks, e.g. anemia hemoglobin" aria-label="Full-text search in remarks" value={q} onChange={e => setQ(e.target.value)} />
    <button className="btn">Search remarks</button>{go && <button type="button" className="btn" onClick={() => { setQ(''); setGo(''); }}>Clear</button>}</form></div>
    <Resource key={go} res="eligibility" query={go ? '?search=' + encodeURIComponent(go) : ''} pk="eligibility_id" add="Record check"
      cols={[['donor', 'Donor'], ['check_date', 'Date'], ['hemoglobin_level', 'Hb g/dL'], ['weight_kg', 'Weight kg'], ['blood_pressure', 'BP'], ['is_eligible', 'Eligible'], ['remarks', 'Remarks']]}
      fields={[['donor_id', 'Donor', 'select', 'donors', 0, 1], ['check_date', 'Check date', 'date'], ['hemoglobin_level', 'Hemoglobin (g/dL)', 'number', 0, 1], ['weight_kg', 'Weight (kg)', 'number', 0, 1], ['blood_pressure', 'Blood pressure (e.g. 120/80)', 'text', 0, 1], ['is_eligible', 'Eligible to donate', 'check'], ['remarks', 'Remarks', 'text', 0, 1]].map(f => f[0] === 'donor_id' ? [f[0], f[1], f[2], f[3], 0, 1] : f)} /></>;
}

function Audit() {
  const [d, setD] = useState(null);
  useEffect(() => { api('audit').then(setD); }, []);
  if (!d) return <p className="empty">Loading…</p>;
  if (d.offline) return <div className="panel"><p>MongoDB isn’t reachable, so the audit trail is paused. Start MongoDB or set MONGODB_URI in .env.local.</p></div>;
  return <div className="panel"><Table cols={[['at', 'When'], ['method', 'Action'], ['path', 'Endpoint'], ['body', 'Data']]} rows={d.map(x => ({ ...x, body: JSON.stringify(x.body) }))} /></div>;
}

const G = 'groups', H = 'hospitals';
const TABS = {
  'Overview': () => <Overview />,
  'Inventory': () => <Inventory />,
  'Requests & matching': () => <Requests />,
  'Donors': () => <Resource res="donors" pk="donor_id" add="Register donor"
    cols={[['donor_id', '#'], ['name', 'Name'], ['group_name', 'Group'], ['gender', 'Gender'], ['dob', 'Born'], ['phone', 'Phone'], ['address', 'Address']]}
    fields={[['name', 'Full name', 'text'], ['gender', 'Gender', 'select', [['M', 'Male'], ['F', 'Female'], ['O', 'Other']]], ['dob', 'Date of birth', 'date'], ['phone', 'Phone', 'text'], ['email', 'Email', 'text', 0, 1], ['address', 'Address', 'text', 0, 1], ['blood_group_id', 'Blood group', 'select', G]]} />,
  'Donations': () => <Resource res="donations" pk="donation_id" add="Record donation" canEdit={false} canDel={false}
    cols={[['donation_id', '#'], ['donor', 'Donor'], ['donation_date', 'Date'], ['quantity_ml', 'ml'], ['camp_name', 'Camp'], ['hospital', 'Stored at'], ['staff_name', 'Staff']]}
    fields={[['donor_id', 'Donor', 'select', 'donors'], ['hospital_id', 'Store blood at hospital', 'select', H], ['camp_id', 'Donation camp', 'select', 'camps', 1], ['quantity_ml', 'Quantity (200–550 ml)', 'number'], ['staff_name', 'Collected by', 'text', 0, 1], ['expiry_days', 'Shelf life in days (default 42)', 'number', 0, 1]]} />,
  'Eligibility': () => <Eligibility />,
  'Camps': () => <Resource res="camps" pk="camp_id" add="Add camp"
    cols={[['camp_name', 'Camp'], ['location', 'Location'], ['organizer', 'Organizer'], ['camp_date', 'Date'], ['start_time', 'Starts'], ['end_time', 'Ends']]}
    fields={[['camp_name', 'Camp name', 'text'], ['location', 'Location', 'text'], ['organizer', 'Organizer', 'text', 0, 1], ['camp_date', 'Date', 'date'], ['start_time', 'Start time', 'time', 0, 1], ['end_time', 'End time', 'time', 0, 1]]} />,
  'Hospitals': () => <Resource res="hospitals" pk="hospital_id" add="Add hospital"
    cols={[['name', 'Hospital'], ['city', 'City'], ['address', 'Address'], ['phone', 'Phone'], ['email', 'Email'], ['license_no', 'License']]}
    fields={[['name', 'Name', 'text'], ['address', 'Address', 'text'], ['city', 'City', 'text'], ['phone', 'Phone', 'text'], ['email', 'Email', 'text', 0, 1], ['license_no', 'License number', 'text']]} />,
  'Users': () => <Resource res="users" pk="user_id" add="Add user"
    cols={[['email', 'Email'], ['role', 'Role'], ['hospital_id', 'Hospital #'], ['donor_id', 'Donor #'], ['is_active', 'Active'], ['created_at', 'Created']]}
    fields={[['email', 'Email', 'text'], ['password', 'Password (new users only)', 'password', 0, 0, 1], ['role', 'Role', 'select', ['Admin', 'HospitalStaff', 'Donor']], ['hospital_id', 'Hospital (for staff)', 'select', H, 1], ['donor_id', 'Donor (for donors)', 'select', 'donors', 1], ['is_active', 'Active', 'check']]} />,
  'Audit trail': () => <Audit />,
};

export default function Home() {
  const [tab, setTab] = useState('Overview'); const [lk, setLk] = useState({}); const [t, setT] = useState(null);
  const reloadLk = useCallback(() => api('lookups').then(setLk).catch(() => {}), []);
  useEffect(() => { reloadLk(); }, []);
  const toast = (m, err) => { setT({ m, err }); setTimeout(() => setT(null), 3500); };
  return <Ctx.Provider value={{ lk, toast, reloadLk }}><div className="app">
    <nav><h1>Blood Bank Coordination</h1>{Object.keys(TABS).map(k => <button key={k} className={tab === k ? 'on' : ''} onClick={() => setTab(k)}>{k}</button>)}</nav>
    <main><header><h2>{tab}</h2></header><div key={tab}>{TABS[tab]()}</div></main>
    {t && <div className={'toast' + (t.err ? ' err' : '')} role="status">{t.m}</div>}
  </div></Ctx.Provider>;
}
