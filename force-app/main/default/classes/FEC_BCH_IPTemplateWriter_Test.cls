@IsTest
private class FEC_BCH_IPTemplateWriter_Test {

    private static ContentVersion createTemplateVersion(String pathOnClient) {
        ContentVersion cv = new ContentVersion(
            Title = pathOnClient,
            PathOnClient = pathOnClient,
            VersionData = Blob.valueOf('dummy')
        );
        insert cv;
        return [SELECT Id, PathOnClient, Title, FileExtension FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
    }

    @IsTest
    static void testShouldHandle_nullAndUnknownId() {
        System.assertEquals(false, FEC_BCH_IncorrectPaymentTemplateWriter.shouldHandle(null));
        System.assertEquals(
            false,
            FEC_BCH_IncorrectPaymentTemplateWriter.shouldHandle((Id) '068000000000001AAA')
        );
    }

    @IsTest
    static void testShouldHandle_byTemplateFileName() {
        ContentVersion target = createTemplateVersion('incorrectpaymenttemp1_pm.xlsx');
        ContentVersion nonTarget = createTemplateVersion('other_template.xlsx');

        System.assertEquals(
            true,
            FEC_BCH_IncorrectPaymentTemplateWriter.shouldHandle(target.Id),
            'Target template file name should be handled.'
        );
        System.assertEquals(
            false,
            FEC_BCH_IncorrectPaymentTemplateWriter.shouldHandle(nonTarget.Id),
            'Non-target template should not be handled.'
        );
    }

    @IsTest
    static void testExportWorkbook_guardClauses() {
        FEC_BCH_TemplateExportService.ExportWorkbookResponse blankResp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook(null);
        System.assertEquals(false, blankResp.success);
        System.assertEquals('EMPTY_REQUEST', blankResp.errorCode);

        FEC_BCH_TemplateExportService.ExportWorkbookResponse invalidResp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook('{}');
        System.assertEquals(false, invalidResp.success);
        System.assertEquals('INVALID_REQUEST', invalidResp.errorCode);
    }

    @IsTest
    static void testExportWorkbook_unsupportedTemplate() {
        ContentVersion nonTarget = createTemplateVersion('not_incorrect_payment.xlsx');

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = nonTarget.Id;
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0 };
        req.dataRows = new List<List<String>>{
            new List<String>{ 'CASE-001' }
        };

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('UNSUPPORTED_TEMPLATE', resp.errorCode);
        System.assertNotEquals(null, resp.errorMessage);
    }

}
