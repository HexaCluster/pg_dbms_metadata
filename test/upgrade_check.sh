#!/bin/bash
#
# Test the upgrade of pg_dbms_metadata from every released version (git
# tags v*) to the current default_version: the catalog of the upgraded
# extension must be identical to the one of a fresh installation.
#
# Must be run from the root of a git clone with its tags, after the current
# version has been installed (make install), against a running server
# (usual libpq environment variables: PGHOST, PGPORT, PGUSER...).

set -eu

EXT=pg_dbms_metadata
CUR=$(sed -n "s/^default_version *= *'\(.*\)'/\1/p" $EXT.control)
SHAREDIR="$(pg_config --sharedir)/extension"
SUDO=
[ "$(id -u)" -ne 0 ] && SUDO=sudo
PSQL="psql -X -q -A -t -v ON_ERROR_STOP=1"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Everything that must be the same after an upgrade and after a fresh
# installation: function signatures, parameter names and defaults, return
# types, bodies, privileges, comments and membership of the extension.
CATALOG_QUERY="
SELECT p.oid::regprocedure::text,
       pg_get_function_arguments(p.oid),
       pg_get_function_result(p.oid),
       md5(p.prosrc),
       coalesce(p.proacl::text, '-'),
       coalesce(obj_description(p.oid, 'pg_proc'), '-'),
       (SELECT count(*) FROM pg_depend d
        WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e')
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'dbms_metadata'
ORDER BY 1;
SELECT extversion FROM pg_extension WHERE extname = '$EXT';
"

dump_catalog()
{
	$PSQL -d "$1" -F '|' -c "$CATALOG_QUERY"
}

echo "Current version: $CUR"

# Reference: fresh installation of the current version
dropdb --if-exists ${EXT}_upgrade_ref
createdb ${EXT}_upgrade_ref
$PSQL -d ${EXT}_upgrade_ref -c "CREATE EXTENSION $EXT"
dump_catalog ${EXT}_upgrade_ref > "$TMPDIR/ref.out"

status=0
tested=0
for tag in $(git tag -l 'v*' | sort -V)
do
	ver=${tag#v}
	# Only upgrades from versions older than the current one
	[ "$ver" = "$CUR" ] && continue
	[ "$(printf '%s\n%s\n' "$ver" "$CUR" | sort -V | head -1)" = "$ver" ] || continue

	echo "Testing upgrade from $ver to $CUR"
	if ! git show "$tag:sql/$EXT--$ver.sql" > "$TMPDIR/$EXT--$ver.sql"
	then
		echo "ERROR: cannot extract sql/$EXT--$ver.sql from tag $tag"
		status=1
		continue
	fi
	$SUDO install -m 644 "$TMPDIR/$EXT--$ver.sql" "$SHAREDIR/"

	db=${EXT}_upgrade_from_${ver//./_}
	dropdb --if-exists "$db"
	createdb "$db"
	if ! $PSQL -d "$db" -c "CREATE EXTENSION $EXT VERSION '$ver'" \
		|| ! $PSQL -d "$db" -c "ALTER EXTENSION $EXT UPDATE TO '$CUR'"
	then
		echo "ERROR: upgrade from $ver to $CUR failed"
		status=1
	else
		dump_catalog "$db" > "$TMPDIR/$ver.out"
		if diff -u "$TMPDIR/ref.out" "$TMPDIR/$ver.out"
		then
			echo "OK: upgrade from $ver is identical to a fresh install of $CUR"
		else
			echo "ERROR: upgrade from $ver differs from a fresh install of $CUR (diff above, - fresh / + upgraded)"
			status=1
		fi
	fi
	dropdb --if-exists "$db"
	$SUDO rm -f "$SHAREDIR/$EXT--$ver.sql"
	tested=$((tested + 1))
done

dropdb --if-exists ${EXT}_upgrade_ref

echo "$tested upgrade path(s) tested"
exit $status
