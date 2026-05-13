public with sharing class FEC_IntegrationMasterDataController {
    public static final Boolean DEBUG_LOG = true;
    public static final String MSG_XML_SYNC_SUCCESS =  System.Label.LBL_Master_XML_Sync_Success;


    /**
     * Synchronizes Fraud Master Data from the integration source.
     *
     * This method triggers the integration process that fetches fraud master data
     * (e.g., from XML or an external system), then inserts or updates records in Salesforce.
     * It returns a human-readable summary message indicating how many records
     * were created or updated during the synchronization.
     *
     * @return A status message describing the synchronization result.
     */
    @AuraEnabled
    public static String syncFraudMasterData() {
        Integer created = FEC_IntegrationFraudService.syncMasterDataIntegration();
        String msg = String.format(MSG_XML_SYNC_SUCCESS,
            new List<String>{ String.valueOf(created) }
        );

        return msg;
    }

    /**
     * Writes a log message to the debug log if debugging is enabled.
     *
     * This method centralizes logging behavior and ensures that debug
     * messages are only printed when the DEBUG_LOG flag is set to true.
     * It helps control log noise and improves performance in production
     * environments by avoiding unnecessary debug statements.
     *
     * @param msg The message to be written to the debug log.
     */
    private static void log(String msg) {
        if (DEBUG_LOG) {
            System.debug(LoggingLevel.INFO, msg);
        }
    }

    

}