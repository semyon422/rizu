UPDATE OR ROLLBACK chartfiles
SET compute_state = CASE compute_state
	WHEN 'new' THEN 0
	WHEN 'valid' THEN 1
	WHEN 'invalid' THEN 2
	WHEN 0 THEN 0
	WHEN 1 THEN 1
	WHEN 2 THEN 2
	ELSE NULL
END
WHERE typeof(compute_state) != 'integer' OR compute_state NOT IN (0, 1, 2);

UPDATE OR ROLLBACK chartplays
SET compute_state = CASE compute_state
	WHEN 'new' THEN 0
	WHEN 'valid' THEN 1
	WHEN 'invalid' THEN 2
	WHEN 0 THEN 0
	WHEN 1 THEN 1
	WHEN 2 THEN 2
	ELSE NULL
END
WHERE typeof(compute_state) != 'integer' OR compute_state NOT IN (0, 1, 2);
