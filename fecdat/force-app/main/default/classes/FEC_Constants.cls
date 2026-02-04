/**
 * FEC_Constants
 * Centralized constants for FEC module.
 * - Keep user-facing messages in Custom Labels when they need translation.
 * - Keep technical configuration constants here (integers, timeouts, flags).
 * - Use @TestVisible for flags used by tests.
 */
public with sharing class FEC_Constants {
    // Messages (if you want messages centralized in code — prefer Custom Labels for translatable text)
    public static final String OPERATION_SUCCESS = System.Label.FEC_Operation_Success;
    public static final String ERROR_DELETE_RECORD_PREFIX = System.Label.FEC_Error_Delete_Record_Prefix;
    public static final String ERROR_DELETE_FIELDLIST_PREFIX = System.Label.FEC_Error_Delete_FieldList_Prefix;

    // Technical configuration
    public static final Integer QUERY_LIMIT = 500;

    // Test flags
    @TestVisible public static Boolean forceException = false;
}
