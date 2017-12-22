--
-- Dictionary, a simple key-value table
--
CREATE SCHEMA dictionary;

CREATE TABLE dictionary.keystore (
  key               TEXT UNIQUE NOT NULL,
  value             TEXT
);

CREATE FUNCTION dictionary.namespace(TEXT) RETURNS TEXT AS $$
  SELECT split_part($1, '::', 1);
$$ LANGUAGE sql;

CREATE FUNCTION dictionary.key(TEXT) RETURNS TEXT AS $$
  SELECT split_part($1, '::', 2);
$$ LANGUAGE sql;

INSERT INTO keystore VALUES ('quota:critical-threshold', '96.0');
INSERT INTO keystore VALUES ('quota:warning-threshold', '90.0');
INSERT INTO keystore VALUES ('system:base-uri-authority', 'https://shuebox.nss.udel.edu');
INSERT INTO keystore VALUES ('system:base-uri-path', '/');
INSERT INTO keystore VALUES ('auth:entropic-secret', 'b8fe1a14004fde480179819713badeca');
INSERT INTO keystore VALUES ('system:admin-email-address', 'shuebox@udel.edu');
INSERT INTO keystore VALUES ('system:base-confirm-uri', 'https://shuebox.nss.udel.edu/__CONFIRM__');
