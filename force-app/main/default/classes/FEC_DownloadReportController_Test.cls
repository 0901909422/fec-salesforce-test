@IsTest
private class FEC_DownloadReportController_Test {

    private static Id createContentDocumentId() {
        ContentVersion cv = new ContentVersion(
            Title = 'Download Report Test',
            PathOnClient = 'report-test.xls',
            VersionData = Blob.valueOf('test'),
            IsMajorVersion = true
        );
        insert cv;
        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        return cv.ContentDocumentId;
    }

    @IsTest
    static void testDownloadReport_emptyIds_throwsAuraHandledException() {
        Boolean threw = false;
        try {
            FEC_DownloadReportController.downloadReport(new List<Id>());
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assert(threw, 'Empty id list should throw AuraHandledException.');
    }

    @IsTest
    static void testDownloadReport_blankLink_throwsAuraHandledException() {
        FEC_Download_Report__c reportRec = new FEC_Download_Report__c(
            Name = 'Blank Link Report',
            FEC_Report_Unique_Name__c = 'FEC_RP_CTRL_TEST',
            FEC_Link__c = null
        );
        insert reportRec;

        Boolean threw = false;
        try {
            FEC_DownloadReportController.downloadReport(new List<Id>{ reportRec.Id });
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assert(threw, 'Blank FEC_Link__c should throw AuraHandledException.');
    }

    @IsTest
    static void testDownloadReport_validShepherdLink_returnsPath() {
        Id docId = createContentDocumentId();
        String shepherdPath =
            '/sfc/servlet.shepherd/document/download/' + docId;

        FEC_Download_Report__c reportRec = new FEC_Download_Report__c(
            Name = 'Valid Link Report',
            FEC_Report_Unique_Name__c = 'FEC_RP_CTRL_VALID',
            FEC_Link__c = shepherdPath
        );
        insert reportRec;

        Test.startTest();
        List<String> links = FEC_DownloadReportController.downloadReport(
            new List<Id>{ reportRec.Id }
        );
        Test.stopTest();

        System.assertEquals(1, links.size(), 'Should return one download path.');
        System.assertEquals(shepherdPath, links[0], 'Path should match shepherd document URL.');

        List<ContentDocumentLink> cdls = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
            AND LinkedEntityId = :reportRec.Id
        ];
        System.assertEquals(1, cdls.size(), 'Controller should link file to report record.');
    }

    @IsTest
    static void testDownloadReport_fullOrgUrlLink_returnsPath() {
        Id docId = createContentDocumentId();
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String fullLink = String.format(
            FEC_ConstantCommon.CONTENT_DOWNLOAD_ENDPOINT,
            new List<String>{ baseUrl, docId }
        );

        FEC_Download_Report__c reportRec = new FEC_Download_Report__c(
            Name = 'Full URL Link Report',
            FEC_Report_Unique_Name__c = 'FEC_RP_CTRL_FULL',
            FEC_Link__c = fullLink
        );
        insert reportRec;

        List<String> links = FEC_DownloadReportController.downloadReport(
            new List<Id>{ reportRec.Id }
        );

        System.assertEquals(1, links.size());
        System.assert(
            links[0].endsWith(String.valueOf(docId)),
            'Returned path should end with ContentDocumentId.'
        );
    }
}
