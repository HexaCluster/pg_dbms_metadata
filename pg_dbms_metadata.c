#include "postgres.h"
#include "utils/guc.h"

PG_MODULE_MAGIC;

/* Declaring transform params */
bool sqlterminator;
bool constraints;
bool ref_constraints;

/* Default values to gucs */
bool sqlterminator_default = false;
bool constraints_default = true;
bool ref_constraints_default = true;

/* Declaring functions */
void _PG_init(void);
void set_default_gucs(void);
Datum set_default_transform_params(PG_FUNCTION_ARGS);

PG_FUNCTION_INFO_V1(set_default_transform_params);

/* This function will be called when a session starts as we are configuring session_preload_libraries param */
void _PG_init(void) 
{
    set_default_gucs();
}

/*
 * CREATE FUNCTION dbms_metadata.set_default_transform_params()
 * RETURNS void
 */
Datum set_default_transform_params(PG_FUNCTION_ARGS) {
    SetConfigOption("dbms_metadata.sqlterminator", 
                    (sqlterminator_default == true) ? "true" : "false", 
                    PGC_USERSET, 
                    PGC_S_SESSION);
    SetConfigOption("dbms_metadata.constraints", 
                    (constraints_default == true) ? "true" : "false", 
                    PGC_USERSET, 
                    PGC_S_SESSION);
    SetConfigOption("dbms_metadata.ref_constraints", 
                    (ref_constraints_default == true) ? "true" : "false", 
                    PGC_USERSET, 
                    PGC_S_SESSION);
    PG_RETURN_NULL();
}

/* initializes all transform params with default values */
void set_default_gucs(void)
{
    DefineCustomBoolVariable("dbms_metadata.sqlterminator", 
                            "If true, Append a SQL terminator",
                            NULL,
                            &sqlterminator, 
                            sqlterminator_default, 
                            PGC_USERSET,
                            0, 
                            NULL, 
                            NULL, 
                            NULL);

    DefineCustomBoolVariable("dbms_metadata.constraints", 
                            "If true, include all non-referential table constraints",
                            NULL,
                            &constraints, 
                            constraints_default, 
                            PGC_USERSET,
                            0, 
                            NULL, 
                            NULL, 
                            NULL);
                            
    DefineCustomBoolVariable("dbms_metadata.ref_constraints", 
                            "If true, include all referential constraints",
                            NULL,
                            &ref_constraints, 
                            ref_constraints_default, 
                            PGC_USERSET,
                            0, 
                            NULL, 
                            NULL, 
                            NULL);
}
