/**
 * Unit tests for FEC_BatchCaseCreationService.processImportRows (row validate + Case insert).
 */
@IsTest
private class FEC_BatchCaseCreationService_Test {

    private static final String VALID_CONTRACT = '0001500010000000261';
    /** Welcome import: contract must contain '-' and match API digit groups (8-6-3). */
    private static final String VALID_CONTRACT_WC = '00015000-100000-2621';
    private static final String VALID_CONTRACT_WC_DATA = '00015000-100000-2631';

    private class BatchCaseCustomerListMock implements HttpCalloutMock {
        private final String accountOrContract;

        BatchCaseCustomerListMock(String accountOrContract) {
            this.accountOrContract = accountOrContract;
        }

        public HttpResponse respond(HttpRequest req) {
            String body =
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<Count>1</Count><Customers><Customer>' +
                '<Applications><Application>' +
                '<AccountNumber>' + accountOrContract + '</AccountNumber>' +
                '<ContractNumber>' + accountOrContract + '</ContractNumber>' +
                '</Application></Applications>' +
                '</Customer></Customers>' +
                '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(body);
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Inquiry',
            FEC_Code__c = 'INQ',
            FEC_Active__c = true
        );
        FEC_Category__c catWelcomeRow = new FEC_Category__c(
            Name = 'welcome_call_category',
            FEC_Code__c = 'WCCAT',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Card Issue',
            FEC_Code__c = 'CI',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'Lost Card',
            FEC_Code__c = 'LC',
            FEC_Active__c = true
        );
        insert new List<SObject>{ prod, cat, catWelcomeRow, subCat, subCode };

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true
        );
        insert noc;

        insert new FEC_Case_Stage__c(
            Name = 'Batch Import Stage 1',
            FEC_Code__c = 'STG' + suffix,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = true,
            FEC_Active__c = true
        );
    }

    private static List<FEC_BatchCaseCreationController.CaseRowResult> processImportRows(
        List<Object> inputRows,
        String templateName
    ) {
        return FEC_BatchCaseCreationService.processImportRows(inputRows, templateName);
    }

    @IsTest
    static void testProcessImportRows_StandardSuccess() {
        List<Object> inputRows = new List<Object>();
        Map<String, Object> validRow = new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Standard flow batch creation test'
        };
        inputRows.add(validRow);

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock(VALID_CONTRACT));
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Succeeded', results[0].status);
        System.assertNotEquals('', results[0].recordId);

        List<Case> checkCases = [SELECT Id FROM Case WHERE FEC_Account_Number__c = :VALID_CONTRACT];
        System.assert(checkCases.size() > 0, 'Standard import should persist account number on Case.');
    }

    @IsTest
    static void testProcessImportRows_WelcomeCallSuccess() {
        List<Object> inputRows = new List<Object>();
        Map<String, Object> wcRow = new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '0988888888',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Welcome call batch test',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME,
            'interactionEmail' => 'welcome.test@fecredit.com.vn'
        };
        inputRows.add(wcRow);

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock(VALID_CONTRACT_WC));
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Succeeded', results[0].status);
        System.assertNotEquals('', results[0].recordId);
    }

    @IsTest
    static void testProcessImportRows_WelcomeCallByRowData() {
        List<Object> inputRows = new List<Object>();
        Map<String, Object> wcRow = new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT_WC_DATA,
            'interactionPhone' => '0977777777',
            'productType' => 'Credit Card',
            'category' => 'welcome_call_category',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Welcome by row fileType',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
        };
        inputRows.add(wcRow);

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock(VALID_CONTRACT_WC_DATA));
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Generic Custom Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Succeeded', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_ValidationFailures() {
        List<Object> inputRows = new List<Object>();
        Map<String, Object> brokenRow = new Map<String, Object>{
            'layout' => 'invalid_layout_name',
            'contractNumber' => '',
            'interactionPhone' => '09123',
            'productType' => 'Non-Existing Product',
            'category' => 'Non-Existing Category',
            'subCategory' => 'Non-Existing SubCategory',
            'subCode' => 'Non-Existing SubCode',
            'caseStatus' => 'InvalidStatusValue',
            'interactionEmail' => 'wrong_email_format'
        };
        inputRows.add(brokenRow);

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);

        List<Case> checkCases = [
            SELECT Id
            FROM Case
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
        ];
        System.assertEquals(0, checkCases.size());
    }

    @IsTest
    static void testProcessImportRows_EmptyInput() {
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            FEC_BatchCaseCreationService.processImportRows(new List<Object>(), 'Standard Case Template');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input returns no row results.');
    }
}
