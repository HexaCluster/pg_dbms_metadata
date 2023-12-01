use Test::Simple tests => 3;

$ENV{LANG}='C';

# Cleanup garbage from previous regression test runs
`rm -rf results/ 2>/dev/null`;

`mkdir results 2>/dev/null`;

# First drop the test database and users
`psql -qAtX -c "DROP DATABASE regress_dbms_metadata" 2>/dev/null`;

# Create the test database
$ret = `psql -qAtX -c "CREATE DATABASE regress_dbms_metadata"`;
ok( $? == 0, "Create test regression database: regress_dbms_metadata");

$ret = `psql -qAtX -d regress_dbms_metadata -c "CREATE EXTENSION pg_dbms_metadata" > /dev/null 2>&1`;
ok( $? == 0, "Create extension pg_dbms_metadata");

$ret = `psql -qAtX -d regress_dbms_metadata -f test/sql/sample_db_objects.sql > /dev/null 2>&1`;
ok( $? == 0, "Create sample db objects");
