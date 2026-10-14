-- PowerSync replicates the tables in this publication (architecture §5).
-- It starts empty: each migration that adds a synced table also adds it here (from P2).
create publication powersync;
