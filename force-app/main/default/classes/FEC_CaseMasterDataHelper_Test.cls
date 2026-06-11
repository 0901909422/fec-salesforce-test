@IsTest
private class FEC_CaseMasterDataHelper_Test {

    private static FEC_Master_Data_Setting__c buildMasterRow(
        String type,
        String api,
        Boolean hidden,
        String editableGroup,
        Boolean reverted,
        Boolean fieldEditable
    ) {
        return new FEC_Master_Data_Setting__c(
            FEC_Type__c = type,
            FEC_Field_API_Name__c = api,
            FEC_Hidden__c = hidden,
            FEC_Editable_User_Group__c = editableGroup,
            FEC_Field_Reverted__c = reverted,
            FEC_Field_Editable__c = fieldEditable,
            FEC_Field_Label_Name__c = api,
            FEC_Field_Object_Name__c = 'Case',
            FEC_Field_Status__c = true
        );
    }

    @IsTest
    static void testDeduplicateMasterDataRowsByFieldApiName() {
        List<SObject> rows = new List<SObject>{
            buildMasterRow('Field', 'Shared_API__c', false, null, false, false),
            buildMasterRow('Assignment', 'Shared_API__c', false, null, false, false),
            buildMasterRow('LWC', 'Shared_API__c', false, null, false, false),
            buildMasterRow('Field', null, false, null, false, false)
        };

        Test.startTest();
        List<SObject> deduped = FEC_CaseMasterDataHelper.deduplicateMasterDataRowsByFieldApiName(rows);
        List<SObject> empty = FEC_CaseMasterDataHelper.deduplicateMasterDataRowsByFieldApiName(null);
        Test.stopTest();

        System.assertEquals(2, deduped.size());
        System.assertEquals('Field', deduped[0].get('FEC_Type__c'));
        System.assertEquals(null, empty);
    }

    @IsTest
    static void testFilterAssignmentRowsByCurrentUserGroup() {
        List<SObject> rows = new List<SObject>{
            buildMasterRow('Field', 'Visible_Field__c', false, null, false, false),
            buildMasterRow('Assignment', 'Hidden_For_CC__c', true, 'CC;SP', false, true),
            buildMasterRow('Assignment', 'Hidden_For_CC__c', false, 'CC', false, true),
            buildMasterRow('Assignment', 'Other_Team__c', true, 'IT', false, true)
        };

        Test.startTest();
        List<SObject> filtered = FEC_CaseMasterDataHelper.filterAssignmentRowsByCurrentUserGroup(rows, 'CC');
        Test.stopTest();

        System.assertEquals(2, filtered.size());
        System.assertEquals('Field', filtered[0].get('FEC_Type__c'));
        System.assertEquals(true, filtered[1].get('FEC_Hidden__c'));
    }

    @IsTest
    static void testFilterRevertedAssignmentRowsByStageContext() {
        List<SObject> rows = new List<SObject>{
            buildMasterRow('Field', 'Plain_Field__c', false, null, false, false),
            buildMasterRow('Assignment', 'Reverted_Field__c', false, null, true, false),
            buildMasterRow(
                'Assignment',
                FEC_CaseMasterDataHelper.API_CONFIRM_D2C_ASSESSMENT,
                false,
                null,
                true,
                false
            )
        };

        Test.startTest();
        List<SObject> notRevertCtx =
            FEC_CaseMasterDataHelper.filterRevertedAssignmentRowsByStageContext(rows, false);
        List<SObject> revertCtx =
            FEC_CaseMasterDataHelper.filterRevertedAssignmentRowsByStageContext(rows, true, 2);
        Test.stopTest();

        System.assertEquals(1, notRevertCtx.size());
        System.assertEquals(2, revertCtx.size());
        System.assertEquals('Plain_Field__c', revertCtx[0].get('FEC_Field_API_Name__c'));
        System.assertEquals('Reverted_Field__c', revertCtx[1].get('FEC_Field_API_Name__c'));
    }

    @IsTest
    static void testRemoveMasterDataRowsByHiddenAssignmentFieldApis() {
        List<SObject> rows = new List<SObject>{
            buildMasterRow('Assignment', 'Secret_API__c', true, 'CC', false, true),
            buildMasterRow('Field', 'Secret_API__c', false, null, false, false),
            buildMasterRow('LWC', 'Visible_API__c', false, null, false, false)
        };

        Test.startTest();
        List<SObject> removed = FEC_CaseMasterDataHelper.removeMasterDataRowsByHiddenAssignmentFieldApis(
            rows,
            true,
            'CC'
        );
        List<SObject> unchanged = FEC_CaseMasterDataHelper.removeMasterDataRowsByHiddenAssignmentFieldApis(
            rows,
            false,
            'CC'
        );
        Test.stopTest();

        System.assertEquals(1, removed.size());
        System.assertEquals('Visible_API__c', removed[0].get('FEC_Field_API_Name__c'));
        System.assertEquals(3, unchanged.size());
    }

    @IsTest
    static void testEditableGroupAndRecallHelpers() {
        List<SObject> rows = new List<SObject>{
            buildMasterRow('Assignment', 'Editable_API__c', false, 'CC;SP', false, true)
        };

        Test.startTest();
        Map<String, String> groups = FEC_CaseMasterDataHelper.collectAssignmentFieldEditableGroups(rows);
        Boolean editable = FEC_CaseMasterDataHelper.isAssignmentFieldEditable(true, 'CC;SP', 'CC');
        Boolean inGroup = FEC_CaseMasterDataHelper.isUserInEditableGroup('CC;SP', 'CC');
        Boolean recall = FEC_CaseMasterDataHelper.isLatestRoutingActionRecall(null);
        Boolean skipCsSp = FEC_CaseMasterDataHelper.shouldSkipRevertConfirmAssessmentField(
            3,
            FEC_CaseMasterDataHelper.API_CONFIRM_CS_SP_ASSESSMENT
        );
        Boolean hideSub = FEC_CaseMasterDataHelper.shouldHideRevertConfirmSubSection(
            3,
            'Confirm CS SP Assessment'
        );
        Test.stopTest();

        System.assertEquals('CC;SP', groups.get('Editable_API__c'));
        System.assertEquals(true, editable);
        System.assertEquals(true, inGroup);
        System.assertEquals(false, recall);
        System.assertEquals(true, skipCsSp);
        System.assertEquals(true, hideSub);
    }

    @IsTest
    static void testPruneRevertConfirmAssessmentSubSections() {
        FEC_CaseBusinessService.Section parent = new FEC_CaseBusinessService.Section();
        FEC_CaseBusinessService.Section d2c = new FEC_CaseBusinessService.Section();
        d2c.name = 'Confirm to D2C Assessment';
        FEC_CaseBusinessService.Section other = new FEC_CaseBusinessService.Section();
        other.name = 'Other Section';
        parent.subSectionlst = new List<FEC_CaseBusinessService.Section>{ d2c, other };

        Test.startTest();
        FEC_CaseMasterDataHelper.pruneRevertConfirmAssessmentSubSections(
            new List<FEC_CaseBusinessService.Section>{ parent },
            2
        );
        FEC_CaseMasterDataHelper.pruneRevertConfirmAssessmentSubSections(null, 2);
        Test.stopTest();

        System.assertEquals(1, parent.subSectionlst.size());
        System.assertEquals('Other Section', parent.subSectionlst[0].name);
    }

    @IsTest
    static void testResolveCustomerHistoryForCase() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(Subject = 'Master Data Helper Case');
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'MDH-CUST',
            FEC_Case__c = c.Id,
            FEC_Email__c = 'mdh@test.example'
        );
        insert customer;
        c.FEC_Account_or_Contract__c = customer.Id;
        update c;
        c = [SELECT Id, FEC_Account_or_Contract__c, FEC_Account_or_Contract__r.FEC_Email__c FROM Case WHERE Id = :c.Id];

        Test.startTest();
        FEC_Customer_History__c fromRel = FEC_CaseMasterDataHelper.resolveCustomerHistoryForCase(c);
        c.putSObject('FEC_Account_or_Contract__r', null);
        FEC_Customer_History__c fromId = FEC_CaseMasterDataHelper.resolveCustomerHistoryForCase(c);
        FEC_Customer_History__c nullCase = FEC_CaseMasterDataHelper.resolveCustomerHistoryForCase(null);
        Test.stopTest();

        System.assertEquals('mdh@test.example', fromRel.FEC_Email__c);
        System.assertEquals(customer.Id, fromId.Id);
        System.assertEquals(null, nullCase);
    }

    @IsTest
    static void testIsGsrRevertStage2ToStage1_NoCase() {
        Test.startTest();
        Boolean result = FEC_CaseMasterDataHelper.isGsrRevertStage2ToStage1('');
        Test.stopTest();
        System.assertEquals(false, result);
    }

    @IsTest
    static void testCofGsrBusinessProcessHelpers() {
        Test.startTest();
        System.assertEquals(true, FEC_CaseMasterDataHelper.isCofOrGsrBusinessProcessCode('COF'));
        System.assertEquals(true, FEC_CaseMasterDataHelper.isCofOrGsrBusinessProcessCode('GSR'));
        System.assertEquals(false, FEC_CaseMasterDataHelper.isCofOrGsrBusinessProcessCode('OTHER'));
        System.assertEquals(false, FEC_CaseMasterDataHelper.isCofGsrRevertStage2ToStage1(''));
        System.assertEquals(
            false,
            FEC_CaseMasterDataHelper.shouldHideRevertConfirmSubSection(1, 'Confirm to D2C Assessment')
        );
        System.assertEquals(
            true,
            FEC_CaseMasterDataHelper.shouldHideRevertConfirmSubSection(
                2,
                'Confirm to D2C Assessment'
            )
        );
        System.assertEquals(
            false,
            FEC_CaseMasterDataHelper.shouldHideRevertConfirmSubSection(
                3,
                'Confirm to D2C Assessment'
            )
        );
        System.assertEquals(
            true,
            FEC_CaseMasterDataHelper.shouldSkipRevertConfirmAssessmentField(
                2,
                FEC_CaseMasterDataHelper.API_CONFIRM_D2C_ASSESSMENT
            )
        );
        Test.stopTest();
    }

    @IsTest
    static void testRoutingHistoryAndRevertHelpers() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'GSR MDH BP ' + suffix,
            FEC_Code__c = 'GSRMDH' + suffix,
            FEC_Active__c = true
        );
        insert bp;

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'MDH PT',
            FEC_Code__c = 'MDHPT' + suffix,
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'MDH Cat',
            FEC_Code__c = 'MDHCAT' + suffix,
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'MDH SubCat',
            FEC_Code__c = 'MDHSUB' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert noc;

        FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(
            Name = 'Flow - ' + FEC_ConstantCommon.STAGE_ONE + ' - Open',
            FEC_Code__c = 'MDHS1' + suffix,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        FEC_Case_Stage__c stage2 = new FEC_Case_Stage__c(
            Name = 'Flow - ' + FEC_ConstantCommon.STAGE_TWO + ' - Review',
            FEC_Code__c = 'MDHS2' + suffix,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        insert new List<FEC_Case_Stage__c>{ stage1, stage2 };

        FEC_Actual_Nature_of_Case__c actualNoc = new FEC_Actual_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id
        );
        insert actualNoc;

        Case revertCase;
        Case recallCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            revertCase = new Case(
                Subject = 'Revert MDH Case',
                FEC_Current_Case_Stage__c = stage1.Id,
                FEC_Actual_Nature_of_Case__c = actualNoc.Id
            );
            recallCase = new Case(Subject = 'Recall MDH Case');
            insert new List<Case>{ revertCase, recallCase };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = recallCase.Id,
            FEC_Routing_Action__c = 'Recall'
        );
        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = revertCase.Id,
            FEC_Previous_Stage__c = stage2.Id,
            FEC_Next_Stage__c = stage1.Id,
            FEC_IsReverted__c = true,
            FEC_Routing_Action__c = 'Revert'
        );

        List<SObject> csSpRows = new List<SObject>{
            buildMasterRow(
                'Assignment',
                FEC_CaseMasterDataHelper.API_CONFIRM_CS_SP_ASSESSMENT,
                false,
                null,
                true,
                false
            ),
            buildMasterRow('Field', 'Keep_Field__c', false, null, false, false)
        };

        Test.startTest();
        Boolean recall = FEC_CaseMasterDataHelper.isLatestRoutingActionRecall(recallCase.Id);
        String prevStage = FEC_CaseMasterDataHelper.getLatestRevertPreviousStageName(
            revertCase.Id,
            stage1.Id,
            stage1.Name
        );
        Integer sourceStage = FEC_CaseMasterDataHelper.resolveRevertConfirmAssessmentSourceStage(
            revertCase.Id,
            stage1.Id,
            stage1.Name,
            true
        );
        Boolean gsrRevert = FEC_CaseMasterDataHelper.isGsrRevertFromPreviousStageName(
            revertCase.Id,
            stage1.Id,
            FEC_ConstantCommon.STAGE_TWO,
            stage1.Name
        );
        Boolean cofGsrRevert = FEC_CaseMasterDataHelper.isCofGsrRevertStage2ToStage1(revertCase.Id);
        Boolean skipD2c = FEC_CaseMasterDataHelper.shouldSkipRevertConfirmAssessmentField(
            2,
            FEC_CaseMasterDataHelper.API_CONFIRM_D2C_ASSESSMENT
        );
        Boolean hideD2c = FEC_CaseMasterDataHelper.shouldHideRevertConfirmSubSection(
            2,
            'Confirm to D2C Assessment'
        );
        List<SObject> csSpRowsStage3 = new List<SObject>{
            buildMasterRow(
                'Assignment',
                FEC_CaseMasterDataHelper.API_CONFIRM_CS_SP_ASSESSMENT,
                false,
                null,
                true,
                false
            ),
            buildMasterRow('Field', 'Keep_Field__c', false, null, false, false)
        };
        List<SObject> revertCtx2 =
            FEC_CaseMasterDataHelper.filterRevertedAssignmentRowsByStageContext(csSpRowsStage3, true, 3);
        List<SObject> emptyFilter =
            FEC_CaseMasterDataHelper.filterAssignmentRowsByCurrentUserGroup(new List<SObject>(), 'CC');
        Test.stopTest();

        System.assertEquals(true, recall);
        System.assert(prevStage.contains(FEC_ConstantCommon.STAGE_TWO));
        System.assertEquals(2, sourceStage);
        System.assertEquals(true, gsrRevert);
        System.assertEquals(true, cofGsrRevert);
        System.assertEquals(true, skipD2c);
        System.assertEquals(true, hideD2c);
        System.assertEquals(1, revertCtx2.size());
        System.assertEquals('Keep_Field__c', revertCtx2[0].get('FEC_Field_API_Name__c'));
        System.assertEquals(0, emptyFilter.size());
    }

    @IsTest
    static void testResolveCustomerHistoryForCase_NoLookup() {
        Case bareCase = new Case(Subject = 'No History Case');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert bareCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_Customer_History__c result = FEC_CaseMasterDataHelper.resolveCustomerHistoryForCase(bareCase);
        Test.stopTest();

        System.assertEquals(null, result);
    }
}
