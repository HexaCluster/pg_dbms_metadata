# pg_dbms_metadata

PostgreSQL extension to extract DDL of database objects in a way compatible to Oracle DBMS_METADATA package.

Information about the Oracle DBMS_metadata package can be found [here](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_METADATA.html)

* [Description](#description)
* [Installation](#installation)
* [Manage the extension](#manage-the-extension)
* [Functions](#functions)
  - [GET_DDL](#get_ddl)
  - [GET_DEPENDENT_DDL](#get_dependent_ddl)
* [Authors](#authors)
* [License](#license)

## [Description](#description)

This PostgreSQL extension provide compatibility with the DBMS_METADATA Oracle package's API to extract DDL. This extension only supports DDL extraction through GET_xxx functions. Support to FETCH_xxx functions and XML support is not added. The following stored procedures are implemented:

* `GET_DDL()` Extracts DDL of specified object.  
* `GET_DEPENDENT_DDL()` Extracts DDL of all dependent objects of specified type for a specified base object.

## [Installation](#installation)

To be able to run this extension, your PostgreSQL version must support extensions (>= 9.1)

To install the extension execute
```
    make
    sudo make install
```
Test of the extension can be done using:
```
    make installcheck
```
## [Manage the extension](#manage-the-extension)

Each database that needs to use `pg_dbms_metadata` must creates the extension:
```
    psql -d mydb -c "CREATE EXTENSION pg_dbms_metadata"
```

To upgrade to a new version execute:
```
    psql -d mydb -c 'ALTER EXTENSION pg_dbms_metadata UPDATE TO "1.1.0"'
```

If you doesn't have the privileges to create an extension, you can just import the extension
file into the database, for example:

    psql -d mydb -f sql/pg_dbms_metadata--1.0.0.sql

This is especially useful for database in DBaas cloud services. To upgrade just import the extension upgrade files using psql.

## [Functions](#functions)

### [GET_DDL](#get_ddl)

This function extracts DDL of database objects. Currently the supported object types are TABLE, VIEW, SEQUENCE, PROCEDURE, FUNCTION, INDEX, CONSTRAINT. For TABLE type, the function extracts a basic table DDL without constraints and indexes. DDL will include list of columns of the table, along with datatypes, DEFAULT values and NOT NULL constraints, in the order of the attnum. DDL will also include comments on table and columns if any.

Syntax:
```
dbms_metadata.get_ddl (
   object_type      IN text,
   name             IN text,
   schema           IN text);
```
Parameters:

- object_type: Object type for which DDL is needed.
- name: Name of object 
- schema: Schema in which object is present

Example:
```
SELECT dbms_metadata.get_ddl('TABLE','table_all','gdmmm');
```

### [GET_DEPENDENT_DDL](#get_dependent_ddl)

This function extracts DDL of all dependent objects of specified object type for a specified base object. Currently the supported dependent object types are SEQUENCE, CONSTRAINT, INDEX.

Syntax:
```
dbms_metadata.get_dependent_ddl (
   object_type          IN text,
   base_object_name     IN text,
   base_object_schema   IN text);
```
Parameters:

- object_type: Object type of dependent objects for which DDL is needed.
- base_object_name: Name of base object 
- base_object_schema: Schema in which base object is present

Example:
```
SELECT dbms_metadata.get_dependent_ddl('CONSTRAINT','table_all','gdmmm');
```

## [Authors](#authors)

- Akhil Reddy Banappagari
- Avinash Vallarapu
- Gilles Darold (Reviewer)

## [License](#license)

This extension is free software distributed under the PostgreSQL
License.

    Copyright (c) 2023 HexaCluster Corp.