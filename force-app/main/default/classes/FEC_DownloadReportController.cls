/****************************************************************************************
* File Name    : FEC_DownloadReportController
* Author       : Quangdv7
* Date         : 2026-05-20
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-05-20    Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_DownloadReportController {

    @AuraEnabled(cacheable=true)
    public static List<ReportWrapper> getDownloadReports() {

        try {

            List<ReportWrapper> result =
                new List<ReportWrapper>();

            List<FEC_Download_Report__c> reports =
                [
                    SELECT Id,
                           Name,
                           FEC_Report_Unique_Name__c,
                           FEC_Link__c,
                           CreatedDate
                    FROM FEC_Download_Report__c
                    ORDER BY CreatedDate DESC
                ];

            for (FEC_Download_Report__c r : reports) {

                ReportWrapper w =
                    new ReportWrapper();

                w.id = r.Id;
                w.name = r.Name;
                w.uniqueName = r.FEC_Report_Unique_Name__c;
                w.link = r.FEC_Link__c;
                result.add(w);
            }

            return result;

        } catch (Exception ex) {

            throw new AuraHandledException(
                ex.getMessage()
            );
        }
    }

    // =========================================================================
    // DOWNLOAD REPORT FILE
    // =========================================================================
    @AuraEnabled
    public static List<String> downloadReport(List<Id> downloadReportIds) {
        List<String> links = new List<String>();
        
        List<FEC_Download_Report__c> reports = [
            SELECT Id, Name, FEC_Link__c
            FROM FEC_Download_Report__c
            WHERE Id IN :downloadReportIds
        ];

        for (FEC_Download_Report__c r : reports) {
            if (String.isNotBlank(r.FEC_Link__c)) {
                links.add(r.FEC_Link__c);
            }
        }

        if (links.isEmpty()) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Download link found'}));
        }

        return links;
    }

    // =========================================================================
    // WRAPPER
    // =========================================================================
    public class ReportWrapper {

        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String uniqueName;
        @AuraEnabled
        public String link;
    }
}