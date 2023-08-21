#include "postgres.h"
#include "utils/guc.h"

PG_MODULE_MAGIC;

// declaring transform params
bool sqlterminator = false;
bool constraints = false;
bool ref_constraints = false;

void _PG_init(void);

// This function will be called when a session starts as we are configuring session_preload_libraries param
void _PG_init(void) 
{
    // initializing all transform params with default values
    DefineCustomBoolVariable("dbms_metadata.sqlterminator", 
                            "If true, Append a SQL terminator",
                            NULL,
                            &sqlterminator, 
                            false, 
                            PGC_USERSET,
                            0, 
                            NULL, 
                            NULL, 
                            NULL);

    DefineCustomBoolVariable("dbms_metadata.constraints", 
                            "If true, include all non-referential table constraints",
                            NULL,
                            &constraints, 
                            true, 
                            PGC_USERSET,
                            0, 
                            NULL, 
                            NULL, 
                            NULL);
                            
    DefineCustomBoolVariable("dbms_metadata.ref_constraints", 
                            "If true, include all referential constraints",
                            NULL,
                            &ref_constraints, 
                            true, 
                            PGC_USERSET,
                            0, 
                            NULL, 
                            NULL, 
                            NULL);
}
