-- Email verification + password reset (idempotent)

-- Users: add EmailVerifiedAt column
ALTER TABLE IF EXISTS users
  ADD COLUMN IF NOT EXISTS emailverifiedat TIMESTAMPTZ;

-- Email verification tokens
CREATE TABLE IF NOT EXISTS emailverificationtokens (
  emailverificationtokenid SERIAL PRIMARY KEY,
  userid INT NOT NULL,
  tokenhash VARCHAR(64) NOT NULL UNIQUE,
  expiresat TIMESTAMPTZ NOT NULL,
  usedat TIMESTAMPTZ,
  createdat TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (userid) REFERENCES users(userid) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ix_emailverificationtokens_userid ON emailverificationtokens(userid);

-- Password reset tokens
CREATE TABLE IF NOT EXISTS passwordresettokens (
  passwordresettokenid SERIAL PRIMARY KEY,
  userid INT NOT NULL,
  tokenhash VARCHAR(64) NOT NULL UNIQUE,
  expiresat TIMESTAMPTZ NOT NULL,
  usedat TIMESTAMPTZ,
  createdat TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (userid) REFERENCES users(userid) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ix_passwordresettokens_userid ON passwordresettokens(userid);
