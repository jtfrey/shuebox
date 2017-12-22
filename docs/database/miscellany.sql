--
-- Is user (by id) an administrator of a collaboration?
--
CREATE FUNCTION collaboration.isAdmin(INTEGER, BIGINT) RETURNS BOOLEAN AS $$
DECLARE
  aRow      RECORD;
BEGIN
  SELECT * INTO aRow FROM collaboration.roleMember
    WHERE roleId = (SELECT roleId FROM collaboration.role WHERE shortName = 'administrator' AND collabId = $1)
      AND userId = $2;
  IF FOUND THEN
    RETURN TRUE;
  END IF;
  RETURN FALSE;
END;
$$
LANGUAGE plpgsql;