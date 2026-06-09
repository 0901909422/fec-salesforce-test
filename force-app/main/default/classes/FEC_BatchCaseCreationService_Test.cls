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

        List<FEC_Routing_Action_History__c> histories = [
            SELECT Id
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :results[0].recordId
        ];
        System.assertEquals(0, histories.size(), 'Open status import không tạo Routing Action History.');
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

        List<FEC_Routing_Action_History__c> histories = [
            SELECT FEC_Routing_Action__c, FEC_Routing_Action_Type__c, FEC_Current_Status__c,
                FEC_Changed_Status__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :results[0].recordId
        ];
        System.assertEquals(1, histories.size(), 'Resolved Welcome Call import phải tạo Routing Action History.');
        System.assertEquals(FEC_CaseBusinessService.RESOLVE, histories[0].FEC_Routing_Action__c);
        System.assertEquals('Case', histories[0].FEC_Routing_Action_Type__c);
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_OPEN, histories[0].FEC_Current_Status__c);
        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            histories[0].FEC_Changed_Status__c
        );
    }

    @IsTest
    static void testProcessImportRows_StandardResolvedCreatesHistory() {
        List<Object> inputRows = new List<Object>();
        Map<String, Object> resolvedRow = new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Standard resolved batch creation test'
        };
        inputRows.add(resolvedRow);

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock(VALID_CONTRACT));
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Succeeded', results[0].status);
        System.assertNotEquals('', results[0].recordId);

        List<FEC_Routing_Action_History__c> histories = [
            SELECT FEC_Routing_Action__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :results[0].recordId
        ];
        System.assertEquals(1, histories.size(), 'Resolved standard import phải tạo Routing Action History.');
        System.assertEquals(FEC_CaseBusinessService.RESOLVE, histories[0].FEC_Routing_Action__c);
    }

    @IsTest
    static void testProcessImportRows_WelcomeCallSimpleLayout() {
        List<Object> inputRows = new List<Object>();
        Map<String, Object> wcRow = new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '0966666666',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Welcome simple layout test'
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
    static void testProcessImportRows_StandardExtendedResolved() {
        List<Object> inputRows = new List<Object>();
        Map<String, Object> resolvedRow = new Map<String, Object>{
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Extended resolved import',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME,
            'interactionEmail' => 'extended.test@fecredit.com.vn'
        };
        inputRows.add(resolvedRow);

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock(VALID_CONTRACT_WC));
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
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
    static void testProcessImportRows_MixedSuccessAndFailedRows() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Valid mixed row'
        });
        inputRows.add(new Map<String, Object>{
            'layout' => 'invalid_layout_name',
            'contractNumber' => VALID_CONTRACT,
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Invalid mixed row'
        });

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock(VALID_CONTRACT));
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals('Succeeded', results[0].status);
        System.assertEquals('Failed', results[1].status);
        System.assertNotEquals('', results[0].recordId);
        System.assertEquals('', results[1].recordId);
    }

    @IsTest
    static void testProcessImportRows_StandardInvalidCaseStatus() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => 'Pending',
            'caseRemarks' => 'Invalid status for standard import'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);
    }

    @IsTest
    static void testProcessImportRows_StandardInvalidInteractionEmail() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT,
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Invalid email row',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME,
            'interactionEmail' => 'not-an-email'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);
    }

    @IsTest
    static void testProcessImportRows_WelcomeMissingRemarks() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '0987654321',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);
    }

    @IsTest
    static void testProcessImportRows_StandardExtendedMissingChannel() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT,
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Missing channel'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);
    }

    @IsTest
    static void testProcessImportRows_WelcomeExtendedMissingChannel() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '0987654321',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Missing welcome channel'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);
    }

    @IsTest
    static void testProcessImportRows_WelcomeMissingPhone() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT_WC,
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Missing phone'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);
    }

    @IsTest
    static void testProcessImportRows_EmptyInput() {
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            FEC_BatchCaseCreationService.processImportRows(new List<Object>(), 'Standard Case Template');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input returns no row results.');
    }

    @IsTest
    static void testProcessImportRows_WelcomeCallInvalidStatus() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '0987654321',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Invalid welcome status',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            FEC_BatchCaseCreationService.processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);
    }

    @IsTest
    static void testNatureOfCaseLookupRegistration() {
        FEC_Nature_of_Case__c noc = [
            SELECT Id, FEC_Product_Type__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c,
                FEC_Category__r.Name, FEC_Category__r.FEC_Code__c,
                FEC_Sub_Category__r.Name, FEC_Sub_Category__r.FEC_Code__c,
                FEC_Sub_Code__r.Name, FEC_Sub_Code__r.FEC_Code__c
            FROM FEC_Nature_of_Case__c
            LIMIT 1
        ];
        FEC_BatchCaseCreationService.NatureOfCaseResolveMaps maps =
            new FEC_BatchCaseCreationService.NatureOfCaseResolveMaps();
        FEC_BatchCaseCreationService.registerNatureOfCaseLookupKeys(maps, noc);
        Set<String> aliases = FEC_BatchCaseCreationService.natureTextAliases('Inquiry', 'INQ');
        System.assert(aliases.contains('inquiry'));
        System.assert(aliases.contains('inq'));
    }

    @IsTest
    static void testPrivateHelperCoverage() {
        Schema.DescribeFieldResult statusDfr = Case.Status.getDescribe();
        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();

        System.assertEquals(null, FEC_BatchCaseCreationService.matchPicklist(null, 'Open'));
        System.assertNotEquals(
            null,
            FEC_BatchCaseCreationService.matchPicklist(statusDfr, FEC_ConstantCommon.CASE_STATUS_OPEN)
        );
        System.assertEquals(
            null,
            FEC_BatchCaseCreationService.matchPicklist(statusDfr, 'TotallyInvalidStatusXYZ')
        );
        System.assertNotEquals(
            null,
            FEC_BatchCaseCreationService.matchCaseStatus(
                statusDfr,
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
            )
        );
        System.assertNotEquals(
            null,
            FEC_BatchCaseCreationService.matchBatchImportCaseStatus(
                statusDfr,
                FEC_ConstantCommon.CASE_STATUS_OPEN
            )
        );
        System.assertEquals(
            null,
            FEC_BatchCaseCreationService.matchBatchImportCaseStatus(statusDfr, 'Pending')
        );

        Map<String, Set<String>> subChannelsByChannel =
            FEC_BatchCaseCreationService.buildSubChannelsByChannelMap(channelDfr, subChannelDfr);
        System.assertNotEquals(null, subChannelsByChannel);
        System.assertEquals(
            true,
            FEC_BatchCaseCreationService.isSubChannelValidForChannel(
                FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
                FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME,
                subChannelsByChannel
            )
        );
        System.assertEquals(255, FEC_BatchCaseCreationService.hexStringToInt('FF'));
        List<String> natureCandidates =
            FEC_BatchCaseCreationService.importNatureTextCandidates('INQ-Inquiry');
        System.assert(natureCandidates.size() >= 2, 'Nature alias list should include name and code.');

        List<Schema.PicklistEntry> channelEntries = channelDfr.getPicklistValues();
        List<Schema.PicklistEntry> subChannelEntries = subChannelDfr.getPicklistValues();
        if (!channelEntries.isEmpty() && !subChannelEntries.isEmpty()) {
            for (Integer channelIndex = 0; channelIndex < channelEntries.size(); channelIndex++) {
                for (Schema.PicklistEntry subEntry : subChannelEntries) {
                    FEC_BatchCaseCreationService.isPicklistEntryValidForControllerIndex(
                        subEntry,
                        channelIndex
                    );
                }
            }
            Schema.PicklistEntry subEntry = subChannelEntries[0];
            FEC_BatchCaseCreationService.readPicklistEntryValidFor(subEntry);
        }
        System.assertEquals(0, FEC_BatchCaseCreationService.hexStringToInt('GG'));
        System.assertEquals(
            true,
            FEC_BatchCaseCreationService.isSubChannelValidForChannel(null, null, null)
        );
        System.assertNotEquals(
            null,
            FEC_BatchCaseCreationService.resolveOtherInteractionStatusApi(
                statusDfr,
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
            )
        );
        System.assertEquals('INQ', FEC_BatchCaseCreationService.extractCodeKey('INQ-Inquiry'));
        FEC_Product_Type__c prod = [
            SELECT Id
            FROM FEC_Product_Type__c
            WHERE FEC_Code__c = 'CC'
            LIMIT 1
        ];
        Map<String, String> lookupMap = new Map<String, String>{
            'cc' => String.valueOf(prod.Id)
        };
        System.assertEquals(prod.Id, FEC_BatchCaseCreationService.lookupFromMap('CC', lookupMap));
        Map<String, Set<String>> fakeSubChannelMap = new Map<String, Set<String>>();
        fakeSubChannelMap.put('outbound', new Set<String>{ 'outbound call' });
        System.assertEquals(
            false,
            FEC_BatchCaseCreationService.isSubChannelValidForChannel(
                FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
                FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME,
                fakeSubChannelMap
            )
        );
        Case channelCase = new Case();
        FEC_BatchCaseCreationService.applyWelcomeChannelDefaults(
            channelCase,
            channelDfr,
            subChannelDfr
        );
        System.assertNotEquals(null, channelCase.FEC_Channel__c);
        System.assertEquals(false, FEC_BatchCaseCreationService.contractNumberContainsLetter(null));
        System.assertEquals(false, FEC_BatchCaseCreationService.isOtherCasesContractNumber(''));
        FEC_BatchCaseCreationService.applyOtherAccountOrContractNumber(null, VALID_CONTRACT);
        FEC_BatchCaseCreationService.applyOtherAccountOrContractNumber(new Case(), '');
        System.assertEquals(true, FEC_BatchCaseCreationService.contractNumberContainsLetter('ABC-123'));
        System.assertEquals(true, FEC_BatchCaseCreationService.isOtherCasesContractNumber(VALID_CONTRACT_WC));
        Case accountCase = new Case();
        FEC_BatchCaseCreationService.applyOtherAccountOrContractNumber(accountCase, VALID_CONTRACT);
        System.assertEquals(VALID_CONTRACT, accountCase.FEC_Account_Number__c);
        Case contractCase = new Case();
        FEC_BatchCaseCreationService.applyOtherAccountOrContractNumber(contractCase, VALID_CONTRACT_WC);
        System.assertEquals(VALID_CONTRACT_WC, contractCase.FEC_Contract_Number__c);
        FEC_Category__c cat = [
            SELECT Id
            FROM FEC_Category__c
            WHERE FEC_Code__c = 'INQ'
            LIMIT 1
        ];
        FEC_Sub_Category__c subCat = [
            SELECT Id
            FROM FEC_Sub_Category__c
            WHERE FEC_Code__c = 'CI'
            LIMIT 1
        ];
        System.assertNotEquals(
            '',
            FEC_BatchCaseCreationService.buildNatureOfCaseCompositeKey(
                prod.Id,
                cat.Id,
                subCat.Id,
                null
            )
        );

        FEC_BatchCaseCreationService.ParsedCaseRow parsedRow =
            new FEC_BatchCaseCreationService.ParsedCaseRow();
        parsedRow.productType = 'CC';
        parsedRow.category = 'INQ';
        parsedRow.subCategory = 'CI';
        parsedRow.subCode = 'LC';
        parsedRow.layout = 'extended';
        parsedRow.contractNumber = VALID_CONTRACT;
        parsedRow.caseRemarks = 'Helper coverage remarks';
        parsedRow.interactionChannel = FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME;
        parsedRow.interactionSubChannel = FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME;
        parsedRow.interactionEmail = 'helper@test.com';
        FEC_BatchCaseCreationService.LookupMaps lookupMaps =
            new FEC_BatchCaseCreationService.LookupMaps();
        lookupMaps.productMap = new Map<String, String>{ 'cc' => String.valueOf(prod.Id) };
        lookupMaps.categoryMap = new Map<String, String>{ 'inq' => String.valueOf(cat.Id) };
        lookupMaps.subCategoryMap = new Map<String, String>{ 'ci' => String.valueOf(subCat.Id) };
        lookupMaps.subCodeMap = new Map<String, String>();
        Case natureCase = new Case();
        FEC_BatchCaseCreationService.applyNatureFields(
            natureCase,
            parsedRow,
            lookupMaps,
            channelDfr,
            subChannelDfr
        );
        System.assertEquals('Helper coverage remarks', natureCase.FEC_Remarks__c);
        FEC_BatchCaseCreationService.NatureOfCaseResolveMaps nocMaps =
            FEC_BatchCaseCreationService.loadNatureOfCaseResolveMaps(
                new List<FEC_BatchCaseCreationService.ParsedCaseRow>{ parsedRow },
                lookupMaps
            );
        System.assertNotEquals(null, nocMaps);
        System.assertEquals(0, FEC_BatchCaseCreationService.importNatureTextCandidates('').size());
        System.assertEquals(0, FEC_BatchCaseCreationService.natureTextAliases(null, null).size());

        FEC_BatchCaseCreationService.ParsedCaseRow welcomeRow =
            new FEC_BatchCaseCreationService.ParsedCaseRow();
        welcomeRow.fileType = 'welcome';
        FEC_BatchCaseCreationService.ParsedCaseRow otherRow =
            new FEC_BatchCaseCreationService.ParsedCaseRow();
        otherRow.fileType = 'standard';
        System.assertEquals(
            null,
            FEC_BatchCaseCreationService.resolveConsistentImportFileType(
                new List<FEC_BatchCaseCreationService.ParsedCaseRow>{ welcomeRow, otherRow }
            )
        );

        List<String> channelValidationErrors = new List<String>();
        FEC_BatchCaseCreationService.ParsedCaseRow extendedRow =
            new FEC_BatchCaseCreationService.ParsedCaseRow();
        extendedRow.layout = 'extended';
        extendedRow.interactionChannel = FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME;
        extendedRow.interactionSubChannel = FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME;
        String outboundApi = FEC_BatchCaseCreationService.matchPicklist(
            channelDfr,
            FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME
        );
        String inboundSubApi = FEC_BatchCaseCreationService.matchPicklist(
            subChannelDfr,
            FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME
        );
        Map<String, Set<String>> restrictedSubChannels = new Map<String, Set<String>>();
        if (String.isNotBlank(outboundApi) && String.isNotBlank(inboundSubApi)) {
            restrictedSubChannels.put(
                outboundApi.trim().toLowerCase(),
                new Set<String>{
                    FEC_BatchCaseCreationService.matchPicklist(
                        subChannelDfr,
                        FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
                    ).trim().toLowerCase()
                }
            );
            FEC_BatchCaseCreationService.appendOtherInteractionChannelValidation(
                extendedRow,
                true,
                channelDfr,
                subChannelDfr,
                restrictedSubChannels,
                channelValidationErrors
            );
            System.assert(!channelValidationErrors.isEmpty(), 'Mismatched sub channel should fail validation.');
        }

        List<String> welcomeStatusErrors = new List<String>();
        FEC_BatchCaseCreationService.ParsedCaseRow openWelcomeRow =
            new FEC_BatchCaseCreationService.ParsedCaseRow();
        openWelcomeRow.caseStatus = FEC_ConstantCommon.CASE_STATUS_OPEN;
        FEC_BatchCaseCreationService.appendWelcomeCaseStatusRules(
            openWelcomeRow,
            statusDfr,
            welcomeStatusErrors
        );
        System.assert(!welcomeStatusErrors.isEmpty(), 'Welcome flow only allows Resolved-Completed status.');
        FEC_BatchCaseCreationService.appendWelcomeCaseStatusRules(null, statusDfr, welcomeStatusErrors);

        System.assertEquals(false, FEC_BatchCaseCreationService.hasAnySucceededRowResult(null));
        FEC_BatchCaseCreationController.CaseRowResult failedResult =
            new FEC_BatchCaseCreationController.CaseRowResult();
        failedResult.status = 'Failed';
        System.assertEquals(
            false,
            FEC_BatchCaseCreationService.hasAnySucceededRowResult(
                new List<FEC_BatchCaseCreationController.CaseRowResult>{ failedResult }
            )
        );
        String longContract = 'X'.repeat(300);
        System.assertEquals(
            255,
            FEC_BatchCaseCreationService.truncateWelcomeSubject('Welcome Call Case - ', longContract).length()
        );
        System.assert(
            FEC_BatchCaseCreationService.truncateWelcomeSubject('Prefix - ', null).contains('Unknown')
        );
        System.assertEquals(
            'Short - ABC',
            FEC_BatchCaseCreationService.truncateWelcomeSubject('Short - ', 'ABC')
        );
        FEC_BatchCaseCreationService.applyOtherInteractionFields(
            null,
            parsedRow,
            lookupMaps,
            channelDfr,
            subChannelDfr
        );
        FEC_BatchCaseCreationService.applyOtherInteractionFields(
            new Case(),
            null,
            lookupMaps,
            channelDfr,
            subChannelDfr
        );
        Database.SaveResult failedInsert = Database.insert(
            new Case(RecordTypeId = (Id) '012000000000000AAA'),
            false
        );
        if (!failedInsert.isSuccess()) {
            System.assertNotEquals(
                '',
                FEC_BatchCaseCreationService.formatSaveResultErrors(failedInsert)
            );
        }

        List<String> missingChannelErrors = new List<String>();
        FEC_BatchCaseCreationService.ParsedCaseRow missingChannelRow =
            new FEC_BatchCaseCreationService.ParsedCaseRow();
        missingChannelRow.layout = 'extended';
        missingChannelRow.interactionChannel = '';
        missingChannelRow.interactionSubChannel = FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME;
        FEC_BatchCaseCreationService.appendOtherInteractionChannelValidation(
            missingChannelRow,
            true,
            channelDfr,
            subChannelDfr,
            new Map<String, Set<String>>(),
            missingChannelErrors
        );
        System.assert(!missingChannelErrors.isEmpty());

        List<String> missingSubChannelErrors = new List<String>();
        FEC_BatchCaseCreationService.ParsedCaseRow missingSubChannelRow =
            new FEC_BatchCaseCreationService.ParsedCaseRow();
        missingSubChannelRow.layout = 'extended';
        missingSubChannelRow.interactionChannel = FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME;
        missingSubChannelRow.interactionSubChannel = '';
        FEC_BatchCaseCreationService.appendOtherInteractionChannelValidation(
            missingSubChannelRow,
            true,
            channelDfr,
            subChannelDfr,
            new Map<String, Set<String>>(),
            missingSubChannelErrors
        );
        System.assert(!missingSubChannelErrors.isEmpty());

        List<String> simpleLayoutChannelErrors = new List<String>();
        FEC_BatchCaseCreationService.appendOtherInteractionChannelValidation(
            missingSubChannelRow,
            false,
            channelDfr,
            subChannelDfr,
            new Map<String, Set<String>>(),
            simpleLayoutChannelErrors
        );
        System.assertEquals(0, simpleLayoutChannelErrors.size());

        List<String> welcomeChannelErrors = new List<String>();
        FEC_BatchCaseCreationService.ParsedCaseRow welcomeExtendedRow =
            new FEC_BatchCaseCreationService.ParsedCaseRow();
        welcomeExtendedRow.interactionChannel = FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME;
        welcomeExtendedRow.interactionSubChannel = FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME;
        if (String.isNotBlank(outboundApi) && String.isNotBlank(inboundSubApi)) {
            FEC_BatchCaseCreationService.appendWelcomeExtendedChannelValidation(
                welcomeExtendedRow,
                channelDfr,
                subChannelDfr,
                restrictedSubChannels,
                welcomeChannelErrors
            );
            System.assert(!welcomeChannelErrors.isEmpty(), 'Welcome extended mismatched sub channel should fail.');
        }
    }

    @IsTest
    static void testProcessImportRows_StandardSuccessSetsDefaultCaseStage() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Verify default case stage'
        });

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock(VALID_CONTRACT));
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals('Succeeded', results[0].status);
        Case importedCase = [
            SELECT FEC_Current_Case_Stage__c
            FROM Case
            WHERE Id = :results[0].recordId
        ];
        System.assertNotEquals(null, importedCase.FEC_Current_Case_Stage__c);
    }

    @IsTest
    static void testNatureOfCaseResolveWithoutSubCodeRegistration() {
        FEC_Product_Type__c prod = [
            SELECT Id
            FROM FEC_Product_Type__c
            WHERE FEC_Code__c = 'CC'
            LIMIT 1
        ];
        FEC_Category__c cat = [
            SELECT Id
            FROM FEC_Category__c
            WHERE FEC_Code__c = 'INQ'
            LIMIT 1
        ];
        FEC_Sub_Category__c subCat = [
            SELECT Id
            FROM FEC_Sub_Category__c
            WHERE FEC_Code__c = 'CI'
            LIMIT 1
        ];
        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Active__c = true
        );

        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'interactionPhone' => '0912345678',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Nature resolve without sub code'
        });

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock(VALID_CONTRACT));
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals('Succeeded', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_StandardOptionalInvalidPhone() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'interactionPhone' => '09123',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Invalid optional phone'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_StandardExtendedInvalidSubChannelValue() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT,
            'interactionPhone' => '0912345678',
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Invalid sub channel value',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => 'Invalid Sub Channel Value'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_StandardResolvedWithoutSubCode() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'interactionPhone' => '0912345678',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Resolved without sub code'
        });

        Test.setMock(HttpCalloutMock.class, new BatchCaseCustomerListMock(VALID_CONTRACT));
        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals('Succeeded', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_MissingCaseStatus() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseRemarks' => 'Missing status'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_WelcomeInvalidPhoneFormat() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '09123',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Invalid phone'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_WelcomeExtendedInvalidChannelValue() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '0987654321',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Invalid channel',
            'interactionChannel' => 'InvalidChannelValue',
            'interactionSubChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_LookupNotFoundFailures() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'productType' => 'Missing Product',
            'category' => 'Missing Category',
            'subCategory' => 'Missing SubCategory',
            'subCode' => 'Missing SubCode',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Lookup failures'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);
    }

    @IsTest
    static void testProcessImportRows_WelcomeMissingContractNumber() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'simple',
            'interactionPhone' => '0987654321',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Missing contract'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_MissingProductType() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Missing product type'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_WelcomeExtendedInvalidSubChannelValue() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'extended',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '0987654321',
            'productType' => 'CC',
            'category' => 'INQ',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Invalid welcome sub channel',
            'interactionChannel' => FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            'interactionSubChannel' => 'Invalid Sub Channel Value'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_MissingCategoryAndSubCategory() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT,
            'productType' => 'Credit Card',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_OPEN,
            'caseRemarks' => 'Missing category and sub category'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'Standard Case Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
        System.assert(results[0].errors.contains('Category') || results[0].errors.contains('Sub'), 'Expected category/subcategory validation errors.');
    }

    @IsTest
    static void testProcessImportRows_WelcomeMissingCategory() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'layout' => 'simple',
            'contractNumber' => VALID_CONTRACT_WC,
            'interactionPhone' => '0987654321',
            'productType' => 'CC',
            'subCategory' => 'CI',
            'subCode' => 'LC',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'caseRemarks' => 'Missing category'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals('Failed', results[0].status);
    }

    @IsTest
    static void testProcessImportRows_WelcomeCallMissingDashInContract() {
        List<Object> inputRows = new List<Object>();
        inputRows.add(new Map<String, Object>{
            'fileType' => 'welcome',
            'contractNumber' => '0001500010000000261',
            'caseStatus' => FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'productType' => 'Credit Card',
            'category' => 'Inquiry',
            'subCategory' => 'Card Issue',
            'subCode' => 'Lost Card'
        });

        Test.startTest();
        List<FEC_BatchCaseCreationController.CaseRowResult> results =
            FEC_BatchCaseCreationService.processImportRows(inputRows, 'FEC Welcome Call Template');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Failed', results[0].status);
        System.assertNotEquals('', results[0].errors);
    }
}
