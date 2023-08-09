use Test::Simple tests => 2;

$ENV{LANG}='C';

$ret = `psql -d regress_dbms_metadata -f test/sql/get_dependent_ddl.sql > results/get_dependent_ddl.out 2>&1`;
ok( $? == 0, "test for fetching dependent ddl");

$ret = `diff results/get_dependent_ddl.out test/expected/get_dependent_ddl.out 2>&1`;
ok( $? == 0, "diff for fetching dependent ddl");
