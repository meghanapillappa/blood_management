import mysql from 'mysql2/promise';
import { MongoClient } from 'mongodb';
const g = globalThis;
export const pool = (g._pool ??= mysql.createPool({
  host: process.env.MYSQL_HOST || 'localhost', user: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || '', database: process.env.MYSQL_DATABASE || 'blood_bank_system',
  dateStrings: true, connectionLimit: 10 }));
export const q = async (s, p) => (await pool.query(s, p))[0];
// MongoDB (NoSQL): append-only audit trail of every change made through the API
const col = () => (g._mongo ??= new MongoClient(process.env.MONGODB_URI || 'mongodb://localhost:27017',
  { serverSelectionTimeoutMS: 1500 }).connect().then(c => c.db('bloodbank_nosql').collection('audit_log')));
export const audit = async d => { try { await (await col()).insertOne({ ...d, at: new Date() }); } catch { g._mongo = null; } };
export const audits = async () => { try { return await (await col()).find().sort({ at: -1 }).limit(100).toArray(); } catch { g._mongo = null; return null; } };
