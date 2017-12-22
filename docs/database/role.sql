--
-- All access control is role-based on the system.  Collaborations can have any number of
-- roles defined, but there will always be _at least_ the "everyone" role.
--
-- Roles are flat beasties -- membership is restricted to users only, not other roles.
--
CREATE TABLE collaboration.role (
  collabId          INTEGER REFERENCES collaboration.definition(collabId) ON DELETE CASCADE,
  roleId            SERIAL PRIMARY KEY,
  shortName         CHARACTER VARYING(32) NOT NULL
                    CHECK (shortName ~ '^[A-Za-z][A-Za-z0-9_ .-]*$'),
  description       TEXT,
  locked            BOOLEAN DEFAULT FALSE,
  systemOwned       BOOLEAN DEFAULT FALSE,
  
  UNIQUE (collabId, shortName)
);

--
-- Self-explanatory.
--
CREATE TABLE collaboration.roleMember (
  roleId            INTEGER REFERENCES collaboration.role(roleId) ON DELETE CASCADE,
  userId            BIGINT REFERENCES users.base(userId) ON DELETE CASCADE
);

--
-- We may or may not need this, but basically let's present a list that
-- "merges" the key properties from the role definition and membership
-- tables:
--
CREATE VIEW collaboration.userToRole AS
  SELECT r.collabId,r.roleId,m.userId
    FROM collaboration.role r,collaboration.roleMember m
    WHERE
      r.roleId = m.roleId;

--
-- When a new collaboration is created, automagically add a "everyone" and "administrator"
-- role.
--
CREATE OR REPLACE RULE "collaboration.role.addEveryone" AS ON INSERT TO collaboration.definition DO ALSO
  INSERT INTO collaboration.role
    (collabId,shortName,description,locked,systemOwned)
    VALUES
    (
      (SELECT collabId FROM collaboration.definition WHERE shortName = NEW.shortName),
      'everyone',
      'All users of the collaboration.',
      TRUE,
      TRUE
    );
CREATE OR REPLACE RULE "collaboration.role.addAdministrator" AS ON INSERT TO collaboration.definition DO ALSO
  INSERT INTO collaboration.role
    (collabId,shortName,description,locked,systemOwned)
    VALUES
    (
      (SELECT collabId FROM collaboration.definition WHERE shortName = NEW.shortName),
      'administrator',
      'Administrators of the collaboration.',
      FALSE,
      TRUE
    );

--
-- If a user is deleted from the collaboration membership, then let's also delete
-- all of his/her role memberships in that collaboration:
--
CREATE RULE "collaboration.role.removeMember" AS ON DELETE TO collaboration.member DO ALSO
  DELETE FROM collaboration.roleMember WHERE
    roleId IN (SELECT roleId FROM collaboration.role WHERE collabId = OLD.collabId) AND
    userId = OLD.userId;

--
-- If a user is added to a collaboration membership, then also add him/her to that
-- collaboration's "everyone" role:
--
CREATE RULE "collaboration.role.addToEveryone" AS ON INSERT TO collaboration.member DO ALSO
  INSERT INTO collaboration.roleMember
    (roleId,userId)
    VALUES
    (
      (SELECT roleId FROM collaboration.role WHERE collabId = NEW.collabId AND shortName = 'everyone'),
      NEW.userId
    );


--
-- At this point we don't have FULL ACLs for the repository trees.  The
-- best we'll do is lock-down access to individual repositories -- and
-- the ACL is darn simple, if a tuple is present grant, if not deny!
--
CREATE TABLE collaboration.repositoryACL (
  reposId         INTEGER REFERENCES collaboration.repository(reposId) ON DELETE CASCADE,
  roleId          INTEGER REFERENCES collaboration.role(roleId) ON DELETE CASCADE
);

--
-- When a repository is created, let's automatically grant access to
-- "everyone":
--
CREATE RULE "collaboration.repository.initialACL" AS ON INSERT TO collaboration.repository DO ALSO
  INSERT INTO collaboration.repositoryACL
    (reposId,roleId)
    VALUES
    (
      (SELECT reposId FROM collaboration.repository WHERE collabId = NEW.collabID AND shortName = NEW.shortName),
      (SELECT roleId FROM collaboration.role WHERE collabId = NEW.collabID AND shortName = 'everyone')
    );

--
-- Check for access to a repository:
--
CREATE FUNCTION collaboration.checkReposAccess(CHARACTER VARYING(32),CHARACTER VARYING(32),CHARACTER VARYING(64)) RETURNS INTEGER AS $$
DECLARE
  aRow      RECORD;
  cId       INTEGER;
BEGIN
  SELECT collabId INTO aRow FROM collaboration.definition WHERE shortName = $1;
  IF FOUND THEN
    cId := aRow.collabId;
    SELECT * INTO aRow FROM collaboration.repositoryACL WHERE
      roleId IN (SELECT roleId FROM collaboration.userToRole WHERE
        userId = (SELECT userID FROM users.base WHERE shortName = $3) AND
        collabId = cId
      ) AND
      reposId = (SELECT reposId FROM collaboration.repository WHERE shortName = $2 AND
        collabId = cId
      );
    IF FOUND THEN
      RETURN 1;
    END IF;
  END IF;
  RETURN 0;
END;
$$
LANGUAGE plpgsql;

--
-- Is user (by shortname) an administrator of a collaboration?
--
CREATE FUNCTION collaboration.isAdministrator(CHARACTER VARYING(32),CHARACTER VARYING(64)) RETURNS INTEGER AS $$
DECLARE
  aRow      RECORD;
BEGIN
  SELECT * INTO aRow FROM collaboration.roleMember
    WHERE roleId = (SELECT roleId FROM collaboration.role WHERE
      shortName = 'administrator'
      AND collabId = (SELECT collabId FROM collaboration.definition WHERE shortName = $1)
    )
    AND userId = (SELECT userId FROM users.base WHERE shortName = $2);
  IF FOUND THEN
    RETURN 1;
  END IF;
  RETURN 0;
END;
$$
LANGUAGE plpgsql;