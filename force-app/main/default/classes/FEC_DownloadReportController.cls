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

    private static final String CONTENT_DOWNLOAD_PATH = '/sfc/servlet.shepherd/document/download/';

    // =========================================================================
    // DOWNLOAD REPORT FILE
    // =========================================================================
    @AuraEnabled
    public static List<String> downloadReport(List<Id> downloadReportIds) {
        try {
            List<String> links = new List<String>();

            List<FEC_Download_Report__c> reports = [
                SELECT Id, FEC_Link__c
                FROM FEC_Download_Report__c
                WHERE Id IN :downloadReportIds
            ];

            for (FEC_Download_Report__c r : reports) {
                if (String.isBlank(r.FEC_Link__c)) {
                    continue;
                }

                Id contentDocumentId = extractContentDocumentId(r.FEC_Link__c);
                if (contentDocumentId == null) {
                    continue;
                }

                ensureReportFileLinked(r.Id, contentDocumentId);
                links.add(buildDownloadUrl(contentDocumentId));
            }

            if (links.isEmpty()) {
                throw new AuraHandledException('Download link not found');
            }

            return links;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static Id extractContentDocumentId(String link) {
        if (String.isBlank(link)) {
            return null;
        }

        Integer lastSlash = link.lastIndexOf('/');
        if (lastSlash < 0 || lastSlash >= link.length() - 1) {
            return null;
        }

        try {
            return (Id) link.substring(lastSlash + 1);
        } catch (Exception ex) {
            return null;
        }
    }

    private static void ensureReportFileLinked(Id reportId, Id contentDocumentId) {
        List<ContentDocumentLink> existing = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId
            AND LinkedEntityId = :reportId
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return;
        }

        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = reportId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    private static String buildDownloadUrl(Id contentDocumentId) {
        return CONTENT_DOWNLOAD_PATH + contentDocumentId;
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
