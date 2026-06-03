@IsTest
private class FEC_BCH_IPExportHelper_Test {

    @IsTest
    static void testApplyCaseSelectFields_addsRequiredFieldsAndHandlesNull() {
        FEC_BCH_IncorrectPaymentExportHelper.applyCaseSelectFields(null);

        List<String> selectFields = new List<String>{ 'Id', 'FEC_Bill_Date__c' };
        FEC_BCH_IncorrectPaymentExportHelper.applyCaseSelectFields(selectFields);

        System.assert(selectFields.contains('FEC_Incorrect_Contract_Number__c'));
        System.assert(selectFields.contains('FEC_Payment_Method__c'));
        System.assert(selectFields.contains('FEC_Bill_Date__c'));
        System.assert(selectFields.contains('FEC_Bill_Amount__c'));
        System.assert(selectFields.contains('FEC_Correct_Contract_Number__c'));
        System.assert(selectFields.contains('FEC_Input_Correct_Contract_Number__c'));
        System.assert(selectFields.contains('FEC_Adjusted_Amount__c'));
        System.assert(selectFields.contains('FEC_Selected_Contract_Number__c'));
        System.assert(selectFields.contains('FEC_Incorrect_Payment_Adj_Rows__c'));
    }

    @IsTest
    static void testApplyCaseFields_mapsAndFormatsValues() {
        FEC_BatchCaseHandlingExportRow row = new FEC_BatchCaseHandlingExportRow();
        Case c = new Case(
            Subject = 'Incorrect Payment',
            Status = 'New',
            FEC_Incorrect_Contract_Number__c = 'ICN-001',
            FEC_Payment_Method__c = 'Bank',
            FEC_Bill_Date__c = Date.newInstance(2026, 6, 1),
            FEC_Bill_Amount__c = 100000.75,
            FEC_Correct_Contract_Number__c = 'CCN-ROOT',
            FEC_Input_Correct_Contract_Number__c = 'CCN-INPUT',
            FEC_Selected_Contract_Number__c = 'SCN-001',
            FEC_Adjusted_Amount__c = 50000.25
        );

        FEC_BCH_IncorrectPaymentExportHelper.applyCaseFields(row, c);

        System.assertEquals('ICN-001', row.incorrectContractNumber);
        System.assertEquals('Bank', row.paymentMethod);
        System.assertEquals('01/06/2026', row.billDate);
        System.assertEquals('100001', row.billAmount);
        System.assertEquals('01/06/2026', row.paymentDate);
        System.assertEquals('100001', row.excessAmount);
        System.assertEquals('SCN-001', row.selectedContractNumber);
        System.assertEquals('CCN-INPUT', row.correctContractNumber);
        System.assertEquals('50000', row.adjustedAmount);
    }

    @IsTest
    static void testEnrichRows_fillsMissingFieldsFromIncorrectPaymentInfo() {
        Case c = new Case(Subject = 'Case for enrich', Status = 'New');
        insert c;

        Schema.SObjectType infoType = Schema.getGlobalDescribe().get('FEC_Incorrect_Payment_Info__c');
        Map<String, Schema.SObjectField> fieldMap = infoType.getDescribe().fields.getMap();
        String correctFieldApi = fieldMap.containsKey('FEC_Correct_Contract_Number__c')
            ? 'FEC_Correct_Contract_Number__c'
            : 'FEC_Correct_Account_Contract__c';

        SObject info = infoType.newSObject();
        info.put('FEC_Case__c', c.Id);
        info.put(correctFieldApi, 'CORRECT-123');
        info.put('FEC_Adjusted_Amount__c', 777.88);
        insert info;

        FEC_BatchCaseHandlingExportRow row = new FEC_BatchCaseHandlingExportRow();
        row.caseId = c.Id;
        row.correctAccountContract = '';
        row.adjustedAmount = '';

        FEC_BCH_IncorrectPaymentExportHelper.enrichRows(
            new List<FEC_BatchCaseHandlingExportRow>{ row, null }
        );

        System.assertEquals('CORRECT-123', row.correctAccountContract);
        System.assertEquals('778', row.adjustedAmount);
    }

    @IsTest
    static void testEnrichRows_guardClauses() {
        FEC_BCH_IncorrectPaymentExportHelper.enrichRows(null);
        FEC_BCH_IncorrectPaymentExportHelper.enrichRows(new List<FEC_BatchCaseHandlingExportRow>());

        FEC_BatchCaseHandlingExportRow noCase = new FEC_BatchCaseHandlingExportRow();
        noCase.correctAccountContract = 'keep';
        noCase.adjustedAmount = '100';
        FEC_BCH_IncorrectPaymentExportHelper.enrichRows(
            new List<FEC_BatchCaseHandlingExportRow>{ noCase }
        );

        System.assertEquals('keep', noCase.correctAccountContract);
        System.assertEquals('100', noCase.adjustedAmount);
    }
}
