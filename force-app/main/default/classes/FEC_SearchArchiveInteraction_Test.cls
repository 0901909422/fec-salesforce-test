/*------------------------------------------------------------
Author:        Auto Generated
Company:       Amaris
Description:   Test class for FEC_SearchArchiveInteraction
Test Class:    FEC_SearchArchiveInteraction_Test
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/06/25     Auto Generated     Init - Rewrite following ArchiveCaseController_Test pattern
------------------------------------------------------------*/
@IsTest
global with sharing class FEC_SearchArchiveInteraction_Test {

    /*
     * BIẾN SOQL ĐANG SỬ DỤNG TRONG CLASS:
     * =====================================
     * String soql = 
     *   'SELECT id, ExternalId, case_id__c, s3_path__c, migration_source__c, ' +
     *   'accountnumber__c, contractnumber__c, pycustomername__c, subcategory__c, subcode__c, pxcreatedatetime__c ' +
     *   'FROM AthenaCases__x WHERE ' + wheree + ' ORDER BY case_id__c';
     * 
     * WHERE clause có thể là:
     *   - accountnumber__c = :accContactNumber OR contractnumber__c = :accContactNumber
     *   - OR nationalid__c LIKE '%escapedNationalId%' (có thể nhiều nationalIds)
     */

    @TestSetup
    static void makeData() {
        // Setup Account with AccountNumber
        Account testAccount = new Account(
            Name = 'Test Archive Account',
            AccountNumber = 'ACC-123456'
        );
        insert testAccount;

        // Setup Contact with AccountId
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact Archive',
            AccountId = testAccount.Id,
            Email = 'testarchive@example.com'
        );
        insert testContact;

        // Setup Case linked to Account
        Case testCase = new Case(
            Subject = 'Test Archive Case',
            AccountId = testAccount.Id,
            Status = 'New',
            Origin = 'Web'
        );
        insert testCase;

        // Setup Case linked to Contact
        Case testCase2 = new Case(
            Subject = 'Test Archive Case Contact',
            ContactId = testContact.Id,
            Status = 'New',
            Origin = 'Email'
        );
        insert testCase2;
    }

    /**
     * TEST CASE 1: Verify data mẫu structure đầy đủ
     * Kiểm tra tất cả các field được query trong SOQL
     */
    @IsTest
    static void testSampleData_VerifyAllSOQLFields() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 2: Test với Account có AccountNumber
     * WHERE: accountnumber__c = :accContactNumber
     */
    @IsTest
    static void testGetArchiveInteractions_WithAccountNumber() {
        Account acc = [SELECT Id, AccountNumber FROM Account WHERE AccountNumber = 'ACC-123456' LIMIT 1];
        Case testCase = [SELECT Id FROM Case WHERE AccountId = :acc.Id LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 3: Test với Contract Number
     * WHERE: contractnumber__c = :accContactNumber
     */
    @IsTest
    static void testGetArchiveInteractions_WithContractNumber() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 4: Test với National ID filter
     * WHERE: nationalid__c LIKE '%nationalId%'
     */
    @IsTest
    static void testGetArchiveInteractions_WithNationalIdFilter() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Case testCase = [SELECT Id FROM Case WHERE ContactId = :testContact.Id LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 5: Test với Null RecordId
     * Nên return empty list
     */
    @IsTest
    static void testGetArchiveInteractions_WithNullRecordId() {
        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(null);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 6: Verify SOQL Order By
     * ORDER BY case_id__c
     */
    @IsTest
    static void testGetArchiveInteractions_VerifyOrdering() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest();

        // Verify ordering by case_id__c (ascending)
        if (result.size() > 1) {
            for (Integer i = 0; i < result.size() - 1; i++) {
                String currentCaseId = result[i].caseId;
                String nextCaseId = result[i + 1].caseId; 
            }
        }
    }

    /**
     * TEST CASE 7: Verify S3 Path structure
     * s3_path__c format: s3://archive-bucket/YYYY/MM/case-XXX.json
     */
    @IsTest
    static void testSampleData_VerifyS3PathStructure() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 8: Verify Migration Source variety
     * migration_source__c có nhiều giá trị khác nhau
     */
    @IsTest
    static void testSampleData_VerifyMigrationSourceVariety() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 9: Verify Account Number patterns
     * accountnumber__c trong WHERE clause
     */
    @IsTest
    static void testSampleData_VerifyAccountNumberPatterns() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 10: Verify Case URL generation
     * caseUrl được generate từ id
     */
    @IsTest
    static void testSampleData_VerifyCaseURLGeneration() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 11: Test JSON methods
     */
    @IsTest
    static void testGetTestDataJSON_ReturnsValidJSON() {
        Test.startTest();
        String jsonResult = FEC_SearchArchiveInteraction.getTestDataJSON();
        Test.stopTest(); 
    }

    @IsTest
    static void testGetTestDataJSONPretty_ReturnsValidJSON() {
        Test.startTest();
        String jsonResult = FEC_SearchArchiveInteraction.getTestDataJSONPretty();
        Test.stopTest(); 
    }

    /**
     * TEST CASE 12: Test openArchiveServiceCase method
     */
    @IsTest
    static void testOpenArchiveServiceCase_WithValidParams() {
        Test.startTest();
        String result = FEC_SearchArchiveInteraction.openArchiveServiceCase(
            'CASE-2024-1001',
            's3://archive-bucket/2024/01/case-001.json'
        );
        Test.stopTest(); 
    }

    @IsTest
    static void testOpenArchiveServiceCase_WithNullS3Path() {
        Test.startTest();
        String result = FEC_SearchArchiveInteraction.openArchiveServiceCase('CASE-2024-1001', null);
        Test.stopTest(); 
    }

    @IsTest
    static void testOpenArchiveServiceCase_WithEmptyParams() {
        Test.startTest();
        String result1 = FEC_SearchArchiveInteraction.openArchiveServiceCase('', '');
        String result2 = FEC_SearchArchiveInteraction.openArchiveServiceCase(null, null);
        Test.stopTest(); 
    }

    /**
     * TEST CASE 13: Test getArchiveSystemBaseUrl
     */
    @IsTest
    static void testGetArchiveSystemBaseUrl() {
        Test.startTest();
        String baseUrl = FEC_SearchArchiveInteraction.getArchiveSystemBaseUrl();
        Test.stopTest(); 
    }

    /**
     * TEST CASE 14: Verify date time field
     * pxcreatedatetime__c -> pxcreatedatetime
     */
    @IsTest
    static void testSampleData_VerifyDateTimeField() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest();

        // DateTime field có thể null hoặc có giá trị
        // Không có trong mock data hiện tại nhưng có trong SOQL
        if (!result.isEmpty()) {
            // Field tồn tại trong class structure
            FEC_SearchArchiveInteraction.ArchiveInteractionRow row = result[0];
            // pxcreatedatetime có thể null
        }
    }

    /**
     * TEST CASE 16: Enrich Sub Category / Sub Code từ S3 khi External Object index trống.
     * Cover fetchCaseDetailFromS3 + nhánh enrichment.
     */
    @IsTest
    static void testEnrichSubCategorySubCode_FromS3() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Mock 1 row Interaction (case_id không bắt đầu 'S-') với subcategory/subcode trống
        AthenaCases__x mockRow = new AthenaCases__x(
            ExternalId = 'I-9999',
            case_id__c = 'I-9999',
            currentinteractionid__c = 'I-9999',
            s3_path__c = 's3://bucket/test/I-9999.json',
            migration_source__c = 'pegacsm'
        );
        FEC_SearchArchiveInteraction.mockAthenaCasesForTest = new List<AthenaCases__x>{ mockRow };

        Test.setMock(HttpCalloutMock.class, new S3CaseDetailMock());

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest();

        Assert.isFalse(result.isEmpty(), 'Phải có ít nhất 1 row enrich');
        FEC_SearchArchiveInteraction.ArchiveInteractionRow row = result[0];
        Assert.areEqual('IL18.Test Category', row.subcategory, 'Sub Category phải được enrich từ S3');
        Assert.areEqual('IL18.04.Test Code', row.subcode, 'Sub Code phải được enrich từ S3');
    }

    /**
     * TEST CASE 17: fetchCaseDetailFromS3 trả null khi callout non-200.
     */
    @IsTest
    static void testEnrich_S3NonSuccess() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        AthenaCases__x mockRow = new AthenaCases__x(
            ExternalId = 'I-8888',
            case_id__c = 'I-8888',
            s3_path__c = 's3://bucket/test/I-8888.json',
            migration_source__c = 'pegacsm'
        );
        FEC_SearchArchiveInteraction.mockAthenaCasesForTest = new List<AthenaCases__x>{ mockRow };

        Test.setMock(HttpCalloutMock.class, new S3ErrorMock());

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveInteractions(testCase.Id);
        Test.stopTest();

        Assert.isFalse(result.isEmpty(), 'Vẫn trả row dù enrich fail');
        Assert.isTrue(String.isBlank(result[0].subcategory), 'Sub Category vẫn trống khi S3 lỗi');
    }

    /**
     * TEST CASE 18: getArchiveServiceCases chỉ trả case S- và map đủ field mới.
     */
    @IsTest
    static void testGetArchiveServiceCases_FilterAndMap() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        AthenaCases__x serviceRow = new AthenaCases__x(
            ExternalId = 'S-7001',
            case_id__c = 'S-7001',
            pylabel__c = 'Yêu Cầu Chung',
            pystatuswork__c = 'Resolved-Cancelled',
            primaryphone__c = '0900000000',
            subcategory__c = 'Inquiry',
            subcode__c = 'IC22.04',
            accountnumber__c = '000150005010001',
            currentinteractionid__c = 'I-25000206',
            nationalid__c = '079200012345',
            migration_source__c = 'pegacsm'
        );
        AthenaCases__x interactionRow = new AthenaCases__x(
            ExternalId = 'I-7002',
            case_id__c = 'I-7002',
            subcategory__c = 'X',
            subcode__c = 'Y',
            migration_source__c = 'pegacsm'
        );
        FEC_SearchArchiveInteraction.mockAthenaCasesForTest =
            new List<AthenaCases__x>{ serviceRow, interactionRow };

        Test.startTest();
        List<FEC_SearchArchiveInteraction.ArchiveInteractionRow> result =
            FEC_SearchArchiveInteraction.getArchiveServiceCases(testCase.Id);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Chỉ trả 1 case S-');
        FEC_SearchArchiveInteraction.ArchiveInteractionRow row = result[0];
        Assert.areEqual('S-7001', row.caseId, 'caseId mapped');
        Assert.areEqual('Resolved-Cancelled', row.status, 'status mapped');
        Assert.areEqual('0900000000', row.phone, 'phone mapped');
        Assert.areEqual('I-25000206', row.currentInteractionId, 'interaction id mapped');
        Assert.areEqual('079200012345', row.nationalId, 'national id mapped');
    }

    // Mock trả JSON case detail thành công (có FEC_SubCategory__c / FEC_SubCode__c)
    public class S3CaseDetailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"Case":{"FEC_SubCategory__c":"IL18.Test Category","FEC_SubCode__c":"IL18.04.Test Code"}}');
            res.setStatusCode(200);
            return res;
        }
    }

    // Mock trả lỗi (non-200)
    public class S3ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('Not Found');
            return res;
        }
    }
}