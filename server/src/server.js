import bcrypt from 'bcryptjs';
import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import pg from 'pg';

dotenv.config();

const app = express();
const port = Number(process.env.PORT ?? 3000);
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});

app.use(cors());
app.use(express.json());

app.get('/health', (_request, response) => {
  response.json({ok: true});
});

app.post('/auth/register', async (request, response) => {
  const fullName = String(request.body.fullName ?? '').trim();
  const email = String(request.body.email ?? '').trim().toLowerCase();
  const password = String(request.body.password ?? '');

  if (fullName.length < 2 || !email.includes('@') || password.length < 8) {
    return response.status(400).json({message: 'Please complete all fields correctly.'});
  }

  const passwordHash = await bcrypt.hash(password, 12);

  try {
    const result = await pool.query(
      `INSERT INTO accounts (full_name, email, password_hash, auth_provider)
       VALUES ($1, $2, $3, 'password')
       RETURNING id, full_name, email`,
      [fullName, email, passwordHash],
    );

    return response.status(201).json({account: toAccount(result.rows[0])});
  } catch (error) {
    if (error.code === '23505') {
      return response.status(409).json({message: 'An account already exists for this email.'});
    }

    console.error(error);
    return response.status(500).json({message: 'Could not create account.'});
  }
});

app.post('/auth/social-signup', async (request, response) => {
  const provider = String(request.body.provider ?? '').trim().toLowerCase();
  const fullName = String(request.body.displayName ?? '').trim();
  const email = String(request.body.email ?? '').trim().toLowerCase();

  if (!['google', 'apple'].includes(provider) || fullName.length < 2 || !email.includes('@')) {
    return response.status(400).json({message: 'Social sign up details are invalid.'});
  }

  try {
    const existing = await pool.query(
      `SELECT id, full_name, email
       FROM accounts
       WHERE email = $1
       LIMIT 1`,
      [email],
    );

    if (existing.rows[0]) {
      return response.json({account: toAccount(existing.rows[0])});
    }

    const result = await pool.query(
      `INSERT INTO accounts (full_name, email, auth_provider, provider_subject)
       VALUES ($1, $2, $3, $4)
       RETURNING id, full_name, email`,
      [fullName, email, provider, `${provider}:${email}`],
    );

    return response.status(201).json({account: toAccount(result.rows[0])});
  } catch (error) {
    console.error(error);
    return response.status(500).json({message: 'Could not create social account.'});
  }
});

app.post('/auth/login', async (request, response) => {
  const identifier = String(request.body.identifier ?? '').trim().toLowerCase();
  const password = String(request.body.password ?? '');

  if (identifier.length === 0 || password.length < 8) {
    return response.status(400).json({message: 'Enter your login details.'});
  }

  const result = await pool.query(
    `SELECT id, full_name, email, password_hash
     FROM accounts
     WHERE email = $1 OR username = $1
     LIMIT 1`,
    [identifier],
  );

  const account = result.rows[0];
  if (!account || !account.password_hash || !(await bcrypt.compare(password, account.password_hash))) {
    return response.status(401).json({message: 'Invalid email, username, or password.'});
  }

  return response.json({account: toAccount(account)});
});

function toAccount(row) {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
  };
}

app.listen(port, () => {
  console.log(`HowBuddy auth API listening on http://localhost:${port}`);
});
