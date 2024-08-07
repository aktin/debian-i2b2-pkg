UPDATE i2b2pm.pm_cell_data
SET url = REPLACE(url, 'localhost', 'wildfly')
WHERE url like '%localhost%';