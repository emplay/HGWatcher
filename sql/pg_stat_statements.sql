SELECT COUNT
	( * ) 
FROM
	pg_catalog.pg_extension e
	LEFT JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace
	LEFT JOIN pg_catalog.pg_description C ON C.objoid = e.oid 
	AND C.classoid = 'pg_catalog.pg_extension' :: pg_catalog.regclass 
WHERE
	e.extname = 'pg_stat_statements';
