use Test::Simple tests => 6;

$ENV{LANG}='C';

$ret = `psql -qAtX -d regress_dbms_metadata -f test/sql/get_dependent_ddl/get_dependent_ddl_index_constraint.sql > results/get_dependent_ddl_index_constraint.out 2>&1`;
ok( $? == 0, "test for retrieving dependent index constraint ddl");

$ret = `psql -qAtX -d regress_dbms_metadata -f test/sql/get_dependent_ddl/get_dependent_ddl_sequence.sql > results/get_dependent_ddl_sequence.out 2>&1`;
ok( $? == 0, "test for retrieving dependent sequence ddl");

$ret = `psql -qAtX -d regress_dbms_metadata -f test/sql/get_dependent_ddl/get_dependent_ddl_trigger.sql > results/get_dependent_ddl_trigger.out 2>&1`;
ok( $? == 0, "test for retrieving dependent trigger ddl");

$ret = `diff results/get_dependent_ddl_index_constraint.out test/expected/get_dependent_ddl/get_dependent_ddl_index_constraint.out 2>&1`;
ok( $? == 0, "diff for retrieving dependent index constraint ddl");

$ret = `diff results/get_dependent_ddl_sequence.out test/expected/get_dependent_ddl/get_dependent_ddl_sequence.out 2>&1`;
ok( $? == 0, "diff for retrieving dependent sequence ddl");

$ret = `diff results/get_dependent_ddl_trigger.out test/expected/get_dependent_ddl/get_dependent_ddl_trigger.out 2>&1`;
ok( $? == 0, "diff for retrieving dependent trigger ddl");
