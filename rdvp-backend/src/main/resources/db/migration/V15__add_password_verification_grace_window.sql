ALTER TABLE password_verification_attempts
    ADD COLUMN IF NOT EXISTS verified_until TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_password_verification_attempts_verified_until
    ON password_verification_attempts(verified_until);
