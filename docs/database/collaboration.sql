--
-- Global collaboration stuff:
--
CREATE SCHEMA collaboration;


--
-- Reserved names: don't allow a collaboration to use
-- any of these as its short-name:
--
CREATE TABLE collaboration.reservedCollaborationShortName (
  shortName         CHARACTER VARYING(32) UNIQUE NOT NULL
);
INSERT INTO collaboration.reservedCollaborationShortName VALUES ('help');
INSERT INTO collaboration.reservedCollaborationShortName VALUES ('__USERDATA__');
INSERT INTO collaboration.reservedCollaborationShortName VALUES ('__METADATA__');
INSERT INTO collaboration.reservedCollaborationShortName VALUES ('css');
INSERT INTO collaboration.reservedCollaborationShortName VALUES ('js');
INSERT INTO collaboration.reservedCollaborationShortName VALUES ('images');
CREATE FUNCTION collaboration.isReservedCollaborationShortName(CHARACTER VARYING(32)) RETURNS BOOLEAN AS $$
DECLARE
  aRow      RECORD;
BEGIN
  SELECT COUNT(*) AS rowCount INTO aRow FROM collaboration.reservedCollaborationShortName
                WHERE shortName = $1;
  IF ( aRow.rowCount > 0 ) THEN
    RETURN TRUE;
  END IF;
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

--
-- Reserved names: don't allow a repository to use
-- any of these as its short-name:
--
CREATE TABLE collaboration.reservedRepositoryShortName (
  shortName         CHARACTER VARYING(32) UNIQUE NOT NULL
);
INSERT INTO collaboration.reservedRepositoryShortName VALUES ('__METADATA__');
CREATE FUNCTION collaboration.isReservedRepositoryShortName(CHARACTER VARYING(32)) RETURNS BOOLEAN AS $$
DECLARE
  aRow      RECORD;
BEGIN
  SELECT COUNT(*) AS rowCount INTO aRow FROM collaboration.reservedRepositoryShortName
                WHERE shortName = $1;
  IF ( aRow.rowCount > 0 ) THEN
    RETURN TRUE;
  END IF;
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

--
-- Primary table for holding the information that defines a collaboration.
--
CREATE TABLE collaboration.definition (
  collabId              SERIAL PRIMARY KEY,
  shortName             CHARACTER VARYING(32) UNIQUE NOT NULL
                         CHECK ( NOT collaboration.isReservedCollaborationShortName(shortName) ),
  description           TEXT NOT NULL,

  -- Quota and reservation (use 0 for no limit on either):
  megabytesQuota        INTEGER DEFAULT 10240,
  megabytesReserved     INTEGER DEFAULT 0,

  -- Use compression?
  compressionIsEnabled  BOOLEAN DEFAULT TRUE,

  -- Where is it rooted on disk?
  homeDirectory         TEXT NOT NULL,

  -- Temporal tracking:
  created               TIMESTAMP WITH TIME ZONE DEFAULT now(),
  modified              TIMESTAMP WITH TIME ZONE DEFAULT now(),
  provisioned           TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  removeAfter           TIMESTAMP WITH TIME ZONE DEFAULT NULL
);

--
-- Automatically send a notification when a new collaboration is added:
--
CREATE RULE "collaboration.definition.creationNotify" AS ON INSERT TO collaboration.definition DO ALSO
  SELECT pg_notify('collaborationCreated', NEW.shortName);

--
-- Any collaborations needing provisioning?
--
CREATE VIEW collaboration.provision AS
  SELECT collabId,shortName FROM collaboration.definition WHERE provisioned IS NULL;

--
-- Any collaborations needing removal?
--
CREATE VIEW collaboration.remove AS
  SELECT collabId,shortName FROM collaboration.definition WHERE removeAfter <= now();



--
-- Each of the repository types is represented by a row in this table.
-- Currently, only the WebDAV and Subversion modules are included.
-- Eventually, I'd love to add CalDAV to that list.
--
CREATE TABLE collaboration.repositoryType (
  repoTypeId        SERIAL PRIMARY KEY,
  description       CHARACTER VARYING(64) NOT NULL,
  className         CHARACTER VARYING(64) NOT NULL
);
INSERT INTO collaboration.repositoryType (description,className) VALUES ('WebDAV','SHUEBoxDAVRepository');
INSERT INTO collaboration.repositoryType (description,className) VALUES ('Subversion','SHUEBoxSVNRepository');
INSERT INTO collaboration.repositoryType (description,className,systemOwned) VALUES ('Web Site','SHUEBoxWebRepository',TRUE);


--
-- Collaborations are composed of one or more "repositories"; this is a departure from
-- the original idea for SHUEBox where a collaboration mapped to a single fixed-type
-- backing type.  This current revision to the system allows collaboration admins to
-- partition their resources as they see fit:  perhaps a programming team would like
-- to have a SVN repository for their source code PLUS a WebDAV share in which to store
-- their documentation, for example.
--
CREATE TABLE collaboration.repository (
  collabId          INTEGER REFERENCES collaboration.definition(collabId) ON DELETE CASCADE,
  reposId           SERIAL PRIMARY KEY,
  shortName         CHARACTER VARYING(32) NOT NULL
                      CHECK ( shortName ~ '^[A-Za-z][A-Za-z0-9_.-]*$' AND NOT collaboration.isReservedRepositoryShortName(shortName) ),
  description       TEXT,
  repositoryType    INTEGER REFERENCES collaboration.repositoryType(repoTypeId),
  canBeRemoved      BOOLEAN DEFAULT TRUE,

  -- Temporal tracking:
  created           TIMESTAMP WITH TIME ZONE DEFAULT now(),
  modified          TIMESTAMP WITH TIME ZONE DEFAULT now(),
  provisioned       TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  removeAfter       TIMESTAMP WITH TIME ZONE DEFAULT NULL,

  UNIQUE (collabId, shortName)
);

--
-- Automatically send a notification when a new repository is added:
--
CREATE OR REPLACE RULE "collaboration.repository.creationNotify" AS ON INSERT TO collaboration.repository DO ALSO
  SELECT pg_notify('repositoryCreated', (SELECT reposId FROM collaboration.repository WHERE collabId = NEW.collabId AND shortName = NEW.shortName)::TEXT);

--
-- Any repositories needing provisioning?
--
CREATE VIEW collaboration.newRepository AS
  SELECT collabId,shortName FROM collaboration.repository WHERE provisioned IS NULL;

--
-- Any repositories needing removal?
--
CREATE VIEW collaboration.expiredRepository AS
  SELECT collabId,shortName FROM collaboration.repository WHERE removeAfter <= now();

--
-- Once a collaboration is provisioned, automatically add a web
-- repository
--
CREATE OR REPLACE FUNCTION collaboration.wasProvisioned (INTEGER, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) RETURNS VOID AS $$
DECLARE
  aRow        RECORD;
BEGIN
  IF ( $2 IS NULL AND $3 IS NOT NULL ) THEN
    SELECT * INTO aRow FROM collaboration.repository WHERE collabId = $1 AND repositoryType = (SELECT repoTypeId FROM collaboration.repositoryType WHERE className = 'SHUEBoxWebRepository');
    IF NOT FOUND THEN
      INSERT INTO collaboration.repository
        (collabId, shortName, description, repositoryType, canBeRemoved)
        VALUES (
          $1, 'web-resources', 'Web site resources',
          (SELECT repoTypeId FROM collaboration.repositoryType WHERE className = 'SHUEBoxWebRepository'),
          FALSE
         );
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE RULE "collaboration.definition.wasProvisioned" AS ON UPDATE TO
  collaboration.definition DO ALSO
    SELECT collaboration.wasProvisioned(NEW.collabId, OLD.provisioned, NEW.provisioned);

--
-- Automatically send quota change notifications:
--
CREATE OR REPLACE FUNCTION collaboration.quotaOrReservationDidChange (INTEGER, TEXT, INTEGER, INTEGER, INTEGER, INTEGER) RETURNS VOID AS $$
DECLARE
  aRow        RECORD;
BEGIN
  IF ( ($3 <> $4) OR ($5 <> $6) ) THEN
    SELECT pg_notify('collaborationQuotaChange', $2);
  END IF;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE RULE "collaboration.definition.quotaOrReservationDidChange" AS ON UPDATE TO
  collaboration.definition DO ALSO
    SELECT collaboration.quotaOrReservationDidChange(NEW.collabId, NEW.shortName, OLD.megabytesQuota, NEW.megabytesQuota, OLD.megabytesReserved, NEW.megabytesReserved);

