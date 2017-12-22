--
-- Basic collaboration membership; this is somewhat redundant relative to the
-- "everyone" role that will be created in the collaboration, but it gives us
-- a simple place to check per-collaboration membership.  It also gives us a
-- place to install Postgres RULEs that will automatically maintain the
-- collaboration's roles as members are added and removed (see the role.sql
-- file).
--
CREATE TABLE collaboration.member (
  collabId          INTEGER REFERENCES collaboration.definition(collabId) ON DELETE CASCADE,
  userId            BIGINT REFERENCES users.base(userId) ON DELETE CASCADE
);

--
-- Is user (by shortname) member of a collaboration?
--
CREATE FUNCTION collaboration.isMember(CHARACTER VARYING(32),CHARACTER VARYING(64)) RETURNS INTEGER AS $$
DECLARE
  aRow      RECORD;
BEGIN
  SELECT * INTO aRow FROM collaboration.member
    WHERE collabId = (SELECT collabId FROM collaboration.definition WHERE shortName = $1)
      AND userId = (SELECT userId FROM users.base WHERE shortName = $2);
  IF FOUND THEN
    RETURN 1;
  END IF;
  RETURN 0;
END;
$$
LANGUAGE plpgsql;

--
-- Collaboration memberships for user with given internal id:
--
CREATE FUNCTION collaboration.membershipsWithUserId(BIGINT) RETURNS RECORD AS $$
  SELECT collabId,shortName,description FROM collaboration.definition
    WHERE collabId IN
      (SELECT collabId FROM collaboration.member WHERE userId = $1)
$$
LANGUAGE sql;

--
-- Collaboration memberships for user with given short name:
--
CREATE FUNCTION collaboration.membershipsWithShortName(CHARACTER VARYING(64)) RETURNS RECORD AS $$
  SELECT collaboration.membershipsWithUserId((SELECT userId FROM users.base WHERE shortName = $1))
$$
LANGUAGE sql;




--
-- No better place than now, since we finally have all of the constituent
-- tables and functions setup.
--


--
-- How long has a collaboration been deemed inactive?
--
CREATE FUNCTION collaboration.inactiveDuration(INTEGER) RETURNS INTERVAL AS $$
  SELECT (now() - max(lastAuth)) FROM users.base WHERE userId IN
    (SELECT userId FROM collaboration.member WHERE collabId = $1)
$$
LANGUAGE SQL;

--
-- Now that we've established collaboration memberships, we can define a view
-- that shows collaborations that are deemed inactive due to no users' authenticating
-- on the system.
--
CREATE VIEW collaboration.inactive AS
  SELECT collabId,shortName,description,collaboration.inactiveDuration(collabId) AS inactiveFor FROM collaboration.definition
    WHERE collaboration.inactiveDuration(collabId) > (SELECT duration FROM maintenance.period WHERE key = 'collaboration.inactive');
    