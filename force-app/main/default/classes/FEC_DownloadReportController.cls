public without sharing class FEC_DownloadReportController {

    @AuraEnabled(cacheable=true)
    public static List<ReportWrapper> getDownloadReports() {

        try {

            List<ReportWrapper> result =
                new List<ReportWrapper>();

            List<Download_Report__c> reports =
                [
                    SELECT Id,
                           Name,
                           FEC_Report_Unique_Name__c,
                           FEC_Link__c,
                           CreatedDate
                    FROM Download_Report__c
                    ORDER BY CreatedDate DESC
                ];

            for (Download_Report__c r : reports) {

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
    public static String downloadReport(
        Id downloadReportId
    ) {

        try {

            if (downloadReportId == null) {

                throw new AuraHandledException(
                    String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Report Id'})
                );
            }

            Download_Report__c report =
                [
                    SELECT Id,
                           Name,
                           FEC_Link__c
                    FROM Download_Report__c
                    WHERE Id = :downloadReportId
                    LIMIT 1
                ];

            if (String.isBlank(report.FEC_Link__c)) {

                throw new AuraHandledException(
                     String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Download link found'})
                );
            }

            return report.FEC_Link__c;

        } catch (AuraHandledException ae) {

            throw ae;

        } catch (Exception ex) {

            throw new AuraHandledException(
                ex.getMessage()
            );
        }
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