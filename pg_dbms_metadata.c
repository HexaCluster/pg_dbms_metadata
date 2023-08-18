#include "postgres.h"
#include "utils/guc.h"

PG_MODULE_MAGIC;

bool sqlterminator = false;

void _PG_init(void);

void _PG_init(void) {
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
}
