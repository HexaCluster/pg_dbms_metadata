# pg_dbms_metadata

PostgreSQL extension to extract DDL of database objects in a way compatible to Oracle DBMS_METADATA package.

Information about the Oracle DBMS_metadata package can be found [here](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_METADATA.html)

* [Description](#description)
* [Installation](#installation)
* [Manage the extension](#manage-the-extension)
* [Functions](#functions)
  - [GET_DDL](#get_ddl)
  - [GET_DEPENDENT_DDL](#get_dependent_ddl)
  - [GET_GRANTED_DDL](#get_granted_ddl)
  - [SET_TRANSFORM_PARAM](#set_transform_param)
* [Authors](#authors)
* [License](#license)

## [Description](#description)

This PostgreSQL extension provide compatibility with the DBMS_METADATA Oracle package's API to extract DDL. This extension only supports DDL extraction through GET_xxx functions. Support to FETCH_xxx functions and XML support is not added. As of now, any user can get the ddl of any object in the database. Like Oracle, we have flexibility of omitting schema while trying to get ddl of an object. This will use search_path to find the object and gets required ddl. However when schema is omitted, the current user should atleast have USAGE access on schema in which target object is present. 

The following functions and stored procedures are implemented:

* `GET_DDL()` This function extracts DDL of specified object.  
* `GET_DEPENDENT_DDL()` This function extracts DDL of all dependent objects of specified type for a specified base object.
* `GET_GRANTED_DDL()` This function extracts the SQL statements to recreate granted privileges and roles for a specified grantee.
* `SET_TRANSFORM_PARAM()` This procedure is used to customize DDL through configuring session-level transform params. 

## [Installation](#installation)

To be able to run this extension, your PostgreSQL version must support extensions (>= 9.1).

1. Copy the source code from repository.
2. set pg_config binary location in PATH environment variable
3. Execute following command to install this extension

```
    make
    sudo make install
```

4. Add `pg_dbms_metadata` to `session_preload_libraries` in `postgresql.conf`.
```
# add to postgresql.conf

# required to load default values to pg_dbms_metadata session-level transform params when a session starts
session_preload_libraries = 'pg_dbms_metadata'
```

Test of the extension can be done using:
```
    make installcheck
```

If you just want to try out the extension or if you don't have the privileges to create an extension, you can just import the extension file into the database:
```
psql -d mydb -c "CREATE SCHEMA dbms_metadata;"

psql -d mydb -f sql/pg_dbms_metadata--1.0.0.sql
```
This is especially useful for database in DBaas cloud services. To upgrade just import the extension upgrade files using psql. 

 The C part of the extension was designed to automatically manage default values for the transform params in each session. If you plan to use the extension for a long-term purpose and desire the exact behavior of Oracle, it is recommended to perform a complete installation.

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

This function extracts DDL of database objects. 

Below is list of currently supported object types. To get a ddl of a check constraint, unlike Oracle you need to use CHECK_CONSTRAINT object type. In Oracle, we will use the CONSTRAINT object type to get ddl of a check constraint.
* TABLE 
* VIEW 
* SEQUENCE 
* PROCEDURE 
* FUNCTION 
* TRIGGER
* INDEX 
* CONSTRAINT 
* CHECK_CONSTRAINT
* REF_CONSTRAINT
* TYPE

Syntax:
```
dbms_metadata.get_ddl (
   object_type      IN text,
   name             IN text,
   schema           IN text DEFAULT NULL)
   RETURNS text;
```
Parameters:

- object_type: Object type for which DDL is needed.
- name: Name of object 
- schema: Schema in which object is present. When schema is not provided search_path is used to find the object and get ddl. However schema cannot be NULL for object types TRIGGER, REF_CONSTRAINT.

Example:
```
SELECT dbms_metadata.get_ddl('TABLE','table_all','gdmmm');
```

### [GET_DEPENDENT_DDL](#get_dependent_ddl)

This function extracts DDL of all dependent objects of specified object type for a specified base object. 

Below is the list of currently supported dependent object types
* SEQUENCE
* TRIGGER
* CONSTRAINT
* REF_CONSTRAINT
* INDEX.

Syntax:
```
dbms_metadata.get_dependent_ddl (
   object_type          IN text,
   base_object_name     IN text,
   base_object_schema   IN text DEFAULT NULL)
   RETURNS text;
```
Parameters:

- object_type: Object type of dependent objects for which DDL is needed.
- base_object_name: Name of base object 
- base_object_schema: Schema in which base object is present. When base object schema is not provided search_path is used to find the base object.

Example:
```
SELECT dbms_metadata.get_dependent_ddl('CONSTRAINT','table_all','gdmmm');
```

### [GET_GRANTED_DDL](#get_granted_ddl)

This function extracts the SQL statements to recreate granted privileges and roles for a specified grantee.

Below is the list of currently supported object types
* ROLE_GRANT

Syntax:
```
dbms_metadata.get_granted_ddl (
    object_type  IN text, 
    grantee      IN text)
    RETURNS text;
```
Parameters:

- object_type: Type of grants to retrieve 
- grantee: User/role for whom we need to retrieve grants

Example:
```
SELECT dbms_metadata.get_granted_ddl('ROLE_GRANT','user_test');
```

### [SET_TRANSFORM_PARAM](#set_transform_param)

This procedure is used to configure session-level transform params, with which we can customize the DDL of objects. This only supports session-level transform params, not setting transform params through any other transform handles. GET_DDL, GET_DEPENDENT_DDL inherit these params when they invoke the DDL transform. There is a small change in the procedure signature when compared to the one of Oracle.

Syntax:
```
dbms_metadata.set_transform_param (
   name          IN text,
   value         IN text);

dbms_metadata.set_transform_param (
   name          IN text,
   value         IN boolean);
```
Parameters:

- name: The name of the transform parameter.
- value: The value of the transform.

List of currently supported transform params

| Object types          | Name                                  | Datatype      | Meaning & Notes      
| --------------------- | ------------------------------------- | ------------- | ----------------------------------------------------------------------------------------------------------
| All objects           | SQLTERMINATOR                         | boolean       | If TRUE, append the SQL terminator( ; ) to each DDL statement. Defaults to FALSE.  
| TABLE                 | CONSTRAINTS                           | boolean       | If TRUE, include all non-referential table constraints. If FALSE, omit them. Defaults to TRUE.  
| TABLE                 | REF_CONSTRAINTS                       | boolean       | If TRUE, include all referential constraints (foreign keys). If FALSE, omit them. Defaults to TRUE.  
| TABLE                 | CONSTRAINTS_AS_ALTER (UNSUPPORTED)    | boolean       | If TRUE, include table constraints as separate ALTER TABLE. This is not yet implemented in this extension. Currently all constraints are being given as separate DDL.  
| TABLE                 | PARTITIONING                          | boolean       | If TRUE, include partitioning clauses in the DDL. Defaults to TRUE. Unlike oracle, this extension does not support INDEX object type for this transform param as postgres indexes doesn't got any partitioning clauses.
| TABLE                 | SEGMENT_ATTRIBUTES                    | boolean       | If TRUE, include segment attributes in the DDL. Defaults to TRUE. Currently only logging attribute is supported and only TABLE object type is supported for this transform param.
| All objects           | DEFAULT                               | boolean       | Calling dbms_metadata.set_transform_param with this parameter set to TRUE has the effect of resetting all transform params to their default values. Setting this FALSE has no effect. There is no default.  
| TABLE                 | STORAGE                               | boolean       | If TRUE, include storage parameters in the DDL. Defaults to TRUE. Currently only TABLE object type is supported for this transform param. Index DDL will always retrieved with storage parameters, if there are any.

Example:
```
CALL dbms_metadata.set_transform_param('SQLTERMINATOR',true);
```

## [Authors](#authors)

- Akhil Reddy Banappagari
- Avinash Vallarapu
- Gilles Darold (Reviewer)

## [License](#license)

This extension is free software distributed under the PostgreSQL
License.

    Copyright (c) 2023 HexaCluster Corp.