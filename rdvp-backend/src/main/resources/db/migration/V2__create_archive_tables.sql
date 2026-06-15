CREATE TABLE IF NOT EXISTS devices (
    id VARCHAR(64) PRIMARY KEY,
    device_code VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(128) NOT NULL,
    model VARCHAR(128),
    manufacturer VARCHAR(128),
    status VARCHAR(32) NOT NULL,
    address VARCHAR(255),
    longitude NUMERIC(10, 7),
    latitude NUMERIC(10, 7),
    last_verification_time TIMESTAMPTZ,
    remark TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    created_by VARCHAR(64),
    updated_at TIMESTAMPTZ NOT NULL,
    updated_by VARCHAR(64),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(status);
CREATE INDEX IF NOT EXISTS idx_devices_name ON devices(name);
CREATE INDEX IF NOT EXISTS idx_devices_model ON devices(model);
CREATE INDEX IF NOT EXISTS idx_devices_location ON devices(longitude, latitude);

CREATE TABLE IF NOT EXISTS device_archive_requests (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(64) NOT NULL REFERENCES devices(id),
    applicant_id VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    previous_device_status VARCHAR(32) NOT NULL,
    reason TEXT NOT NULL,
    changes JSONB NOT NULL,
    reviewer_id VARCHAR(64),
    review_comment TEXT,
    reviewed_at TIMESTAMPTZ,
    freeze_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    created_by VARCHAR(64) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    updated_by VARCHAR(64)
);

CREATE INDEX IF NOT EXISTS idx_device_archive_requests_device_status ON device_archive_requests(device_id, status);
CREATE INDEX IF NOT EXISTS idx_device_archive_requests_freeze_until ON device_archive_requests(freeze_until);
CREATE UNIQUE INDEX IF NOT EXISTS ux_device_archive_requests_pending_device
    ON device_archive_requests(device_id)
    WHERE status = 'PENDING_REVIEW';

CREATE TABLE IF NOT EXISTS device_qrcodes (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(64) NOT NULL REFERENCES devices(id),
    version INTEGER NOT NULL,
    nonce VARCHAR(128) NOT NULL UNIQUE,
    signature_hash VARCHAR(255) NOT NULL,
    status VARCHAR(32) NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    created_by VARCHAR(64)
);

CREATE INDEX IF NOT EXISTS idx_device_qrcodes_device_id ON device_qrcodes(device_id);
CREATE INDEX IF NOT EXISTS idx_device_qrcodes_status ON device_qrcodes(status);
CREATE INDEX IF NOT EXISTS idx_device_qrcodes_expires_at ON device_qrcodes(expires_at);

INSERT INTO devices (
    id,
    device_code,
    name,
    model,
    manufacturer,
    status,
    address,
    longitude,
    latitude,
    last_verification_time,
    created_at,
    updated_at
) VALUES
    (
        'device-local-0001',
        'RDVP-DEVICE-0001',
        'Cooling Pump A-01',
        'CP-1000',
        'North Equipment',
        'NORMAL',
        'Plant 1 Power Area',
        114.1694000,
        22.3193000,
        '2026-05-28T09:30:00Z',
        '2026-05-29T00:00:00Z',
        '2026-05-29T00:00:00Z'
    ),
    (
        'device-local-0002',
        'RDVP-DEVICE-0002',
        'Conveyor Line B-02',
        'CL-2200',
        'South Automation',
        'NORMAL',
        'Plant 2 Packaging Area',
        114.1721000,
        22.3188000,
        '2026-05-27T15:20:00Z',
        '2026-05-29T00:00:00Z',
        '2026-05-29T00:00:00Z'
    ),
    (
        'device-local-0003',
        'RDVP-DEVICE-0003',
        'Energy Cabinet C-03',
        'ES-500',
        'East Energy',
        'NORMAL',
        'Plant 3 Energy Storage Area',
        114.1662000,
        22.3210000,
        '2026-05-26T11:10:00Z',
        '2026-05-29T00:00:00Z',
        '2026-05-29T00:00:00Z'
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO device_archive_requests (
    id,
    device_id,
    applicant_id,
    status,
    previous_device_status,
    reason,
    changes,
    created_at,
    created_by,
    updated_at
) VALUES (
    'DCR-LOCAL-0002',
    'device-local-0002',
    'usr-field-operator',
    'PENDING_REVIEW',
    'NORMAL',
    'Site marker location requires archive correction.',
    '{"location.address":{"oldValue":"Plant 2 Packaging Area","newValue":"Plant 2 Packaging Area Section A"}}'::jsonb,
    '2026-05-29T10:10:00Z',
    'usr-field-operator',
    '2026-05-29T10:10:00Z'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO device_qrcodes (
    id,
    device_id,
    version,
    nonce,
    signature_hash,
    status,
    issued_at,
    expires_at,
    created_at
) VALUES
    (
        'qrcode-local-0001',
        'device-local-0001',
        1,
        'nonce-rdvp-device-0001',
        'f36d5f8b2a520071a5955968704a6dd4017a01e6457f573527867e47813c2807',
        'ACTIVE',
        '2026-05-29T00:00:00Z',
        '2027-05-29T00:00:00Z',
        '2026-05-29T00:00:00Z'
    ),
    (
        'qrcode-local-0002',
        'device-local-0002',
        1,
        'nonce-rdvp-device-0002',
        'c5fb24d08793ff6e3b4a7422874c765e2455d4f6dee7aca680b246b4222f8a37',
        'ACTIVE',
        '2026-05-29T00:00:00Z',
        '2027-05-29T00:00:00Z',
        '2026-05-29T00:00:00Z'
    ),
    (
        'qrcode-local-0003',
        'device-local-0003',
        1,
        'nonce-rdvp-device-0003',
        '6efde5c2594d434cf9294cc04dccd765eb9debd1fc7ec081f13fbe54e7bc6c97',
        'ACTIVE',
        '2026-05-29T00:00:00Z',
        '2027-05-29T00:00:00Z',
        '2026-05-29T00:00:00Z'
    )
ON CONFLICT (id) DO NOTHING;
