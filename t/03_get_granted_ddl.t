use Test::Simple tests => 2;

$ENV{LANG}='C';

$ret = `psql -d regress_dbms_metadata -f test/sql/get_granted_ddl/get_granted_ddl_role.sql > results/get_granted_ddl/get_granted_ddl_role.out 2>&1`;
ok( $? == 0, "test for retrieving granted roles ddl");

$ret = `diff results/get_granted_ddl/get_granted_ddl_role.out test/expected/get_granted_ddl/get_granted_ddl_role.out 2>&1`;
ok( $? == 0, "diff for retrieving granted roles ddl");