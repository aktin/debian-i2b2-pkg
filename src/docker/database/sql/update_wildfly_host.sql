--
-- Change url of i2b2.war to wildfly docker
--

UPDATE i2b2pm.pm_cell_data
SET url = REPLACE(url, 'localhost', 'wildfly')
WHERE url like '%localhost%';
