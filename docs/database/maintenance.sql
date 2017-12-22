--
-- $Id: maintenance.sql 3 2008-10-17 18:26:49Z frey $
--


--
-- Anything associated with system maintenance goes in this schema.
--
CREATE SCHEMA maintenance;

--
-- Rather than define specific time intervals programmatically in the
-- context of the code or in headers, the maintenance.period table
-- should be used to provide a centralized store for simple time
-- interval values.
--
CREATE TABLE maintenance.period (
  periodId          SERIAL PRIMARY KEY,
  key               CHARACTER VARYING(128),
  description       TEXT,
  duration          INTERVAL NOT NULL
);

INSERT INTO maintenance.period (key,description,duration)
  VALUES (
    'users.guests.inactive',
    'Length of time after which a guest will be removed for inactivity.',
    '3 months'
  );
INSERT INTO maintenance.period (key,description,duration)
  VALUES (
    'users.native.inactive',
    'Length of time after which a native user will be removed for inactivity.',
    '1 year'
  );
INSERT INTO maintenance.period (key,description,duration)
  VALUES (
    'collaboration.inactive',
    'Length of time after which a collaboration will be marked for removal due to inactivity.',
    '6 months'
  );

--
-- There are a lot of things that the system will need to be doing on
-- a periodic basis in terms of maintaining the state of collaborations,
-- checking how much quota each collaboration is utilizing, etc.  This
-- table provides a key-based mechanism for managing the periodicity of
-- the tasks.  In addition, the inclusion of the "description" field
-- allows us to present an abstracted "system tasks" panel to indicate
-- the event description, last time it happened, and the next time it 
-- should happen.
--
CREATE TABLE maintenance.task (
  taskId            SERIAL PRIMARY KEY,
  key               CHARACTER VARYING(128) UNIQUE NOT NULL,
  description       TEXT,
  period            INTERVAL DEFAULT NULL,
  notification      CHARACTER VARYING(128) DEFAULT NULL,
  isEnabled         BOOLEAN DEFAULT TRUE,
  inProgress        TIMESTAMP WITH TIME ZONE,
  performedAt       TIMESTAMP WITH TIME ZONE DEFAULT now()
);

INSERT INTO maintenance.task (key,description,notification)
  VALUES (
    'collaboration.provision','Provision newly-created collaborations.','collaborationCreated'
  );
INSERT INTO maintenance.task (key,description,notification)
  VALUES (
    'repository.provision','Provision newly-created repositories.','repositoryCreated'
  );
INSERT INTO maintenance.task (key,description,notification)
  VALUES (
    'collaboration.quota-update','Update collaboration quota limit.','collaborationQuotaChange'
  );
INSERT INTO maintenance.task (key,description,period)
  VALUES (
    'collaboration.remove','Remove collaborations that have expired.','1 day'
  );
INSERT INTO maintenance.task (key,description,period)
  VALUES (
    'collaboration.quota-check','Update collaborations'' quota usage.','1 hour'
  );
INSERT INTO maintenance.task (key,description,period)
  VALUES (
    'repository.remove','Remove repositories that have expired.','2 hours'
  );
INSERT INTO maintenance.task (key,description,period)
  VALUES (
    'users.remove','Remove users that have expired.','1 week'
  );
INSERT INTO maintenance.task (key,description,period)
  VALUES (
    'users.guests.inactivity-check','Check for guest users that have not used the system in an eon.','1 week'
  );
INSERT INTO maintenance.task (key,description,period)
  VALUES (
    'collaboration.inactivity-check','Check for collaborations that have not been used in an eon.','1 month'
  );

--
-- We use a rule to automatically get Postgres to do a NOTIFY when the task
-- table is modified:
--
CREATE RULE "maintenance.task.update" AS ON UPDATE TO maintenance.task DO ALSO NOTIFY "maintenanceTaskUpdate";
CREATE RULE "maintenance.task.insert" AS ON INSERT TO maintenance.task DO ALSO NOTIFY "maintenanceTaskUpdate";

--
-- Given a key, turn it into a task id.
--
CREATE FUNCTION maintenance.taskIdWithKey(CHARACTER VARYING(128)) RETURNS INTEGER AS $$
  SELECT taskId FROM maintenance.task WHERE key = $1
$$
LANGUAGE sql;

--
-- Given a task id, what is the timestamp for the next time that the task
-- should be performed?
--
CREATE FUNCTION maintenance.nextTimeForTaskById(INTEGER) RETURNS TIMESTAMP WITH TIME ZONE AS $$
  SELECT (performedAt + period)::TIMESTAMP WITH TIME ZONE FROM maintenance.task
    WHERE taskId = $1
$$
LANGUAGE sql;

--
-- Attempt to begin doing a task:
--
CREATE OR REPLACE FUNCTION maintenance.taskWithIdAcquireLock(INTEGER) RETURNS BOOLEAN AS $$
DECLARE
  aRow      RECORD;
BEGIN
  SELECT inProgress INTO aRow FROM maintenance.task WHERE taskId = $1 FOR UPDATE;
  IF FOUND THEN
    IF aRow.inProgress IS NULL THEN
      UPDATE maintenance.task SET inProgress = now() WHERE taskId = $1;
      RETURN TRUE;
    END IF;
  END IF;
  RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

--
-- Finish doing a task:
--
CREATE OR REPLACE FUNCTION maintenance.taskWithIdReleaseLock(INTEGER) RETURNS BOOLEAN AS $$
DECLARE
  aRow      RECORD;
BEGIN
  SELECT inProgress INTO aRow FROM maintenance.task WHERE taskId = $1;
  IF FOUND THEN
    IF aRow.inProgress IS NOT NULL THEN
      UPDATE maintenance.task SET inProgress = NULL,performedAt = now() WHERE taskId = $1;
      RETURN TRUE;
    END IF;
  END IF;
  RETURN FALSE;
END;
$$
LANGUAGE plpgsql;
