--
-- User information
--
CREATE SCHEMA users;

--
-- Every single person gets an internal user identifier on the system; so-called
-- "native" users are able to authenticate against some sort of central mechanism and
-- are considered to be something other than a "guest" user.
--
-- The "shortName" should be whatever identification users will use to login to
-- the system.
--
CREATE TABLE users.base (
  userId            BIGSERIAL PRIMARY KEY,
  native            BOOLEAN,
  canBeRemoved      BOOLEAN DEFAULT TRUE,
  shortName         CHARACTER VARYING(64) UNIQUE NOT NULL,
  fullName          CHARACTER VARYING(256),
  created           TIMESTAMP WITH TIME ZONE DEFAULT now(),
  modified          TIMESTAMP WITH TIME ZONE DEFAULT now(),
  removeAfter       TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  lastAuth          TIMESTAMP WITH TIME ZONE DEFAULT NULL
);
--
-- Make sure users who can't be removed...well, aren't removed!
--
CREATE RULE "users.base.removalCheck" AS ON DELETE TO users.base
  WHERE OLD.canBeRemoved IS FALSE
  DO INSTEAD NOTHING;


--
-- Native users are those who have an identity within the organization running the
-- system, and can authenticate against some central authority (LDAP, etc).
--
CREATE TABLE users.native (
  userId            BIGINT NOT NULL REFERENCES users.base(userId) ON DELETE CASCADE,
  emplid            CHARACTER VARYING(11) UNIQUE NOT NULL
);

--
-- Guests are those who are external to the hosting organization and thus need
-- authentication information maintained by this system itself.
--
CREATE TABLE users.guest (
  userId            BIGINT NOT NULL REFERENCES users.base(userId) ON DELETE CASCADE,
  password          TEXT,
  md5Password       CHARACTER(32) NOT NULL,
  lastPassword      TEXT,
  passwordChanged   TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  welcomeMsgSent    TIMESTAMP WITH TIME ZONE DEFAULT NULL
);
CREATE OR REPLACE FUNCTION users.passwordChangeDelegate() RETURNS TRIGGER AS $$
BEGIN
  -- Has the password been changed?
  IF NEW.password IS NOT NULL AND (OLD.password IS NULL OR (NEW.password <> OLD.password)) THEN
    NEW.md5Password = md5(NEW.password);
    NEW.lastPassword = OLD.password;
    NEW.passwordChanged = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER updateDelegate BEFORE UPDATE ON users.guest
    FOR EACH ROW EXECUTE PROCEDURE users.passwordChangeDelegate();
--
-- Automagically handle welcome messages:
--
CREATE OR REPLACE RULE "users.guestWelcomeMessageNotification" AS ON INSERT TO users.guest
  DO ALSO SELECT pg_notify('sendGuestWelcomeMessages', NEW.userId::TEXT);

--
-- Simplified guest authentication + last-authentication update:
--
CREATE FUNCTION users.guestUserAuthenticate(CHARACTER VARYING(64),CHARACTER(32)) RETURNS INTEGER AS $$
DECLARE
  aRow      RECORD;
BEGIN
  SELECT userId INTO aRow FROM users.guest WHERE userId = (SELECT userId FROM users.base WHERE shortName ILIKE $1) AND md5Password = $2;
  IF FOUND THEN
    UPDATE users.base SET lastAuth = now()
      WHERE userId = aRow.userId;
    RETURN 1;
  END IF;
  RETURN 0;
END;
$$
LANGUAGE plpgsql;

--
-- Native user last-authentication update plus emplid <=> shortName
-- check
--
CREATE FUNCTION users.nativeUserLogAuthentication(CHARACTER VARYING(64),CHARACTER VARYING(11)) RETURNS INTEGER AS $$
DECLARE
  aRow      RECORD;
BEGIN
  SELECT userId,shortName INTO aRow FROM users.base WHERE userId = (SELECT userId FROM users.native WHERE emplid = $2);
  IF FOUND THEN
    UPDATE users.base SET lastAuth = now()
      WHERE userId = aRow.userId;
    IF LOWER(aRow.shortName) <> LOWER($1) THEN
      UPDATE users.base SET shortName = LOWER($1)
        WHERE userId = aRow.userId;
    END IF;
    RETURN 1;
  END IF;
  RETURN 0;
END;
$$
LANGUAGE plpgsql;

--
-- Are there any native users who aren't using the system?
--
-- Note that anyone who was created and has not logged in for the same duration
-- (his/her lastAuth would be NULL) is caught by this view and will have a NULL in
-- the "inactiveFor" column.
--
CREATE VIEW users.inactiveNatives AS
  SELECT userId,shortName,fullName,(now() - lastAuth) AS inactiveFor FROM users.base
    WHERE
      native = TRUE AND (
        (now() - lastAuth)::INTERVAL > (SELECT duration FROM maintenance.period WHERE key = 'users.native.inactive') OR (lastAuth IS NULL AND (now() - created) > (SELECT duration FROM maintenance.period WHERE key = 'users.native.inactive'))
      );

--
-- Are there any guests who aren't using the system?
--
-- Note that anyone who was created and has not logged in for the same duration
-- (his/her lastAuth would be NULL) is caught by this view and will have a NULL in
-- the "inactiveFor" column.
--
CREATE VIEW users.inactiveGuests AS
  SELECT userId,shortName,fullName,(now() - lastAuth) AS inactiveFor FROM users.base
    WHERE
      native = FALSE AND  (
        (now() - lastAuth)::INTERVAL > (SELECT duration FROM maintenance.period WHERE key = 'users.guests.inactive') OR (lastAuth IS NULL AND (now() - created) > (SELECT duration FROM maintenance.period WHERE key = 'users.guests.inactive'))
      );
