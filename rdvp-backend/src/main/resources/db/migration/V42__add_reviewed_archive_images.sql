ALTER TABLE review_archive_requests
    ADD COLUMN images_changed BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE archive_device_images (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(64) NOT NULL,
    sort_order SMALLINT NOT NULL,
    content_type VARCHAR(64) NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    image_content BYTEA NOT NULL,
    thumbnail_content BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(64),
    CONSTRAINT fk_archive_device_images_device
        FOREIGN KEY (device_id) REFERENCES archive_devices(id) ON DELETE CASCADE,
    CONSTRAINT ck_archive_device_images_sort_order
        CHECK (sort_order BETWEEN 0 AND 4),
    CONSTRAINT ck_archive_device_images_content_type
        CHECK (content_type = 'image/jpeg'),
    CONSTRAINT ck_archive_device_images_dimensions
        CHECK (width BETWEEN 1 AND 1600 AND height BETWEEN 1 AND 1600),
    CONSTRAINT ck_archive_device_images_size
        CHECK (octet_length(image_content) BETWEEN 1 AND 1500000)
);

CREATE UNIQUE INDEX ux_archive_device_images_device_order
    ON archive_device_images(device_id, sort_order);

CREATE INDEX idx_archive_device_images_device
    ON archive_device_images(device_id);

CREATE TABLE review_archive_request_images (
    id VARCHAR(64) NOT NULL,
    request_id VARCHAR(64) NOT NULL,
    sort_order SMALLINT NOT NULL,
    content_type VARCHAR(64) NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    image_content BYTEA NOT NULL,
    thumbnail_content BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_review_archive_request_images
        PRIMARY KEY (request_id, id),
    CONSTRAINT fk_review_archive_request_images_request
        FOREIGN KEY (request_id) REFERENCES review_archive_requests(id) ON DELETE CASCADE,
    CONSTRAINT ck_review_archive_request_images_sort_order
        CHECK (sort_order BETWEEN 0 AND 4),
    CONSTRAINT ck_review_archive_request_images_content_type
        CHECK (content_type = 'image/jpeg'),
    CONSTRAINT ck_review_archive_request_images_dimensions
        CHECK (width BETWEEN 1 AND 1600 AND height BETWEEN 1 AND 1600),
    CONSTRAINT ck_review_archive_request_images_size
        CHECK (octet_length(image_content) BETWEEN 1 AND 1500000)
);

CREATE UNIQUE INDEX ux_review_archive_request_images_request_order
    ON review_archive_request_images(request_id, sort_order);

INSERT INTO archive_device_images (
    id,
    device_id,
    sort_order,
    content_type,
    width,
    height,
    image_content,
    thumbnail_content,
    created_at,
    created_by
)
SELECT
    'archive-image-' || md5(device.id),
    device.id,
    0,
    'image/jpeg',
    240,
    150,
    decode('/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCACWAPADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD9LaKKK1MgooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAoorxr9or9or/AIUF/wAI/wD8U/8A27/a32j/AJffs/leV5X/AEzfdnzfbGO+apJydkS2oq7PZaK+Nf8Ah4p/1T//AMrX/wBz0f8ADxT/AKp//wCVr/7nrT2M+xn7WHc+yqK+Nf8Ah4p/1T//AMrX/wBz0f8ADxT/AKp//wCVr/7no9jPsHtYdz7Kor41/wCHin/VP/8Aytf/AHPR/wAPFP8Aqn//AJWv/uej2M+we1h3PsqivjX/AIeKf9U//wDK1/8Ac9H/AA8U/wCqf/8Ala/+56PYz7B7WHc+yqK+Nf8Ah4p/1T//AMrX/wBz0f8ADxT/AKp//wCVr/7no9jPsHtYdz7Korxr9nX9or/hfv8AwkH/ABT/APYX9k/Z/wDl9+0eb5vm/wDTNNuPK9857Yr2Ws2nF2ZompK6CiiipKCiiigAooooAKKKKACiiigAooooAKKKKACiiigAr41/4KKf80+/7iH/ALbV9lV8a/8ABRT/AJp9/wBxD/22raj8aMavwM+NKKKK9I88KKKKACiiigAooooAKKKKAPsv/gnX/wA1B/7h/wD7c19lV8a/8E6/+ag/9w//ANua+yq82t8bPQpfAgooorE2CiiigAooooAKKKKACiiigAooooAKKKKACiiigAr41/4KKf8ANPv+4h/7bV9lV8a/8FFP+aff9xD/ANtq2o/GjGr8DPjSiiivSPPCiiigAooooAKKKKACiiigD7L/AOCdf/NQf+4f/wC3NfZVfGv/AATr/wCag/8AcP8A/bmvsqvNrfGz0KXwIKKKKxNgooooAKKKKACiiigAooooAKKKKACiiigAooooAK+Nf+Cin/NPv+4h/wC21fZVfGv/AAUU/wCaff8AcQ/9tq2o/GjGr8DPjSiiivSPPCiiigAooooAKKKKACiiigD7L/4J1/8ANQf+4f8A+3NfZVfGv/BOv/moP/cP/wDbmvsqvNrfGz0KXwIKKKKxNgooooAKKKKACiiigAooooAKKKKACiiigAooooAK+Nf+Cin/ADT7/uIf+21fZVcb8Rfg94Q+LH9n/wDCVaR/av8AZ/mfZv8ASZofL37d/wDq3XOdi9c9OO9aU5KMk2Zzi5RaR+TlFfph/wAMefCH/oUf/Klef/HqP+GPPhD/ANCj/wCVK8/+PV1/WInL7CR+Z9Ffph/wx58If+hR/wDKlef/AB6j/hjz4Q/9Cj/5Urz/AOPUfWIh7CR+Z9Ffph/wx58If+hR/wDKlef/AB6j/hjz4Q/9Cj/5Urz/AOPUfWIh7CR+Z9Ffph/wx58If+hR/wDKlef/AB6j/hjz4Q/9Cj/5Urz/AOPUfWIh7CR+Z9Ffph/wx58If+hR/wDKlef/AB6j/hjz4Q/9Cj/5Urz/AOPUfWIh7CR41/wTr/5qD/3D/wD25r7Krjfh18HvCHwn/tD/AIRXSP7K/tDy/tP+kzTeZs3bP9Y7Yxvbpjrz2rsq5KklKTaOqEXGKTCiiiszQKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooA//Z', 'base64'),
    decode('/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCACWAPADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD9LaKKK1MgooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAoorxr9or9or/AIUF/wAI/wD8U/8A27/a32j/AJffs/leV5X/AEzfdnzfbGO+apJydkS2oq7PZaK+Nf8Ah4p/1T//AMrX/wBz0f8ADxT/AKp//wCVr/7nrT2M+xn7WHc+yqK+Nf8Ah4p/1T//AMrX/wBz0f8ADxT/AKp//wCVr/7no9jPsHtYdz7Kor41/wCHin/VP/8Aytf/AHPR/wAPFP8Aqn//AJWv/uej2M+we1h3PsqivjX/AIeKf9U//wDK1/8Ac9H/AA8U/wCqf/8Ala/+56PYz7B7WHc+yqK+Nf8Ah4p/1T//AMrX/wBz0f8ADxT/AKp//wCVr/7no9jPsHtYdz7Korxr9nX9or/hfv8AwkH/ABT/APYX9k/Z/wDl9+0eb5vm/wDTNNuPK9857Yr2Ws2nF2ZompK6CiiipKCiiigAooooAKKKKACiiigAooooAKKKKACiiigAr41/4KKf80+/7iH/ALbV9lV8a/8ABRT/AJp9/wBxD/22raj8aMavwM+NKKKK9I88KKKKACiiigAooooAKKKKAPsv/gnX/wA1B/7h/wD7c19lV8a/8E6/+ag/9w//ANua+yq82t8bPQpfAgooorE2CiiigAooooAKKKKACiiigAooooAKKKKACiiigAr41/4KKf8ANPv+4h/7bV9lV8a/8FFP+aff9xD/ANtq2o/GjGr8DPjSiiivSPPCiiigAooooAKKKKACiiigD7L/AOCdf/NQf+4f/wC3NfZVfGv/AATr/wCag/8AcP8A/bmvsqvNrfGz0KXwIKKKKxNgooooAKKKKACiiigAooooAKKKKACiiigAooooAK+Nf+Cin/NPv+4h/wC21fZVfGv/AAUU/wCaff8AcQ/9tq2o/GjGr8DPjSiiivSPPCiiigAooooAKKKKACiiigD7L/4J1/8ANQf+4f8A+3NfZVfGv/BOv/moP/cP/wDbmvsqvNrfGz0KXwIKKKKxNgooooAKKKKACiiigAooooAKKKKACiiigAooooAK+Nf+Cin/ADT7/uIf+21fZVcb8Rfg94Q+LH9n/wDCVaR/av8AZ/mfZv8ASZofL37d/wDq3XOdi9c9OO9aU5KMk2Zzi5RaR+TlFfph/wAMefCH/oUf/Klef/HqP+GPPhD/ANCj/wCVK8/+PV1/WInL7CR+Z9Ffph/wx58If+hR/wDKlef/AB6j/hjz4Q/9Cj/5Urz/AOPUfWIh7CR+Z9Ffph/wx58If+hR/wDKlef/AB6j/hjz4Q/9Cj/5Urz/AOPUfWIh7CR+Z9Ffph/wx58If+hR/wDKlef/AB6j/hjz4Q/9Cj/5Urz/AOPUfWIh7CR+Z9Ffph/wx58If+hR/wDKlef/AB6j/hjz4Q/9Cj/5Urz/AOPUfWIh7CR41/wTr/5qD/3D/wD25r7Krjfh18HvCHwn/tD/AIRXSP7K/tDy/tP+kzTeZs3bP9Y7Yxvbpjrz2rsq5KklKTaOqEXGKTCiiiszQKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooA//Z', 'base64'),
    NOW(),
    device.updated_by
FROM archive_devices device
WHERE device.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM archive_device_images image
      WHERE image.device_id = device.id
  );

ALTER TABLE archive_devices
    DROP COLUMN image_uri;
