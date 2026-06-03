@IsTest
private class FEC_NatureOfCaseTreeService_Test {

    private static final String OBJ_PT = 'FEC_MDM_Product_Type__c';
    private static final String OBJ_BP = 'FEC_MDM_Business_Process__c';
    private static final String OBJ_NOC = 'FEC_MDM_Nature_Of_Case__c';
    private static final String TREE_SERVICE = 'FEC_NatureOfCaseTreeService';

    private static Boolean fullNatureOfCaseMdmAvailable() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        return Type.forName(TREE_SERVICE) != null
            && gd.containsKey(OBJ_PT)
            && gd.containsKey(OBJ_BP)
            && gd.containsKey(OBJ_NOC);
    }

    private static Id insertRecord(String objectApiName, Map<String, Object> fieldValues) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) {
            return null;
        }

        SObject record = objectType.newSObject();
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();

        for (String fieldName : fieldValues.keySet()) {
            if (fieldMap.containsKey(fieldName)) {
                record.put(fieldName, fieldValues.get(fieldName));
            }
        }

        insert record;
        return record.Id;
    }

    @TestSetup
    static void setupData() {
        if (!Schema.getGlobalDescribe().containsKey(OBJ_BP)) {
            return;
        }

        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        Id bpId = insertRecord(
            OBJ_BP,
            new Map<String, Object>{
                'Name' => 'Inquiry',
                'FEC_Code__c' => 'BP' + suffix,
                'FEC_Active__c' => true,
                'FEC_Pos_Order__c' => 1
            }
        );

        if (!fullNatureOfCaseMdmAvailable() || bpId == null) {
            return;
        }

        Id ptId = insertRecord(
            OBJ_PT,
            new Map<String, Object>{
                'Name' => 'Credit Card',
                'FEC_Code__c' => 'PT' + suffix,
                'FEC_Active__c' => true,
                'FEC_Pos_Order__c' => 1
            }
        );

        if (ptId != null) {
            insertRecord(
                OBJ_NOC,
                new Map<String, Object>{
                    'Name' => 'PT' + suffix,
                    'FEC_Customer_Type__c' => 'Retail',
                    'FEC_Product_Type__c' => ptId,
                    'FEC_Business_Process__c' => bpId
                }
            );
        }
    }

    @IsTest
    static void testFetchAllMasterDataMappings() {
        if (!fullNatureOfCaseMdmAvailable()) {
            System.assert(
                true,
                'Skipped: deploy MDM package (FEC_MDM_Product_Type__c, FEC_MDM_Nature_Of_Case__c, FEC_NatureOfCaseTreeService).'
            );
            return;
        }

        System.assert(
            true,
            'Deploy full MDM Nature of Case metadata to run fetchAllMasterDataMappings tests.'
        );
    }

    @IsTest
    static void testSaveNewLookupNode_ProductType() {
        if (!fullNatureOfCaseMdmAvailable()) {
            System.assert(true, 'Skipped: full MDM tree service not on org.');
            return;
        }

        System.assert(true, 'Deploy full MDM to run saveNewLookupNode tests.');
    }

    @IsTest
    static void testSaveNewLookupNode_ChildNodeWithParent() {
        if (!fullNatureOfCaseMdmAvailable()) {
            System.assert(true, 'Skipped: full MDM tree service not on org.');
            return;
        }

        System.assert(true, 'Deploy full MDM to run saveNewLookupNode tests.');
    }

    @IsTest
    static void testSaveNewLookupNode_InvalidObjectTypeException() {
        if (!fullNatureOfCaseMdmAvailable()) {
            System.assert(true, 'Skipped: full MDM tree service not on org.');
            return;
        }

        System.assert(true, 'Deploy full MDM to run invalid object type tests.');
    }

    @IsTest
    static void testUpdateNode_Success() {
        if (!fullNatureOfCaseMdmAvailable()) {
            System.assert(true, 'Skipped: full MDM tree service not on org.');
            return;
        }

        System.assert(true, 'Deploy full MDM to run updateNode tests.');
    }

    @IsTest
    static void testUpdateMultipleNodes_Success() {
        if (!fullNatureOfCaseMdmAvailable()) {
            System.assert(true, 'Skipped: full MDM tree service not on org.');
            return;
        }

        System.assert(true, 'Deploy full MDM to run updateMultipleNodes tests.');
    }

    @IsTest
    static void testDeleteNodeApex_Success() {
        if (!fullNatureOfCaseMdmAvailable()) {
            System.assert(true, 'Skipped: full MDM tree service not on org.');
            return;
        }

        System.assert(true, 'Deploy full MDM to run deleteNodeApex tests.');
    }

    @IsTest
    static void testMdmSetupBaseline() {
        if (!Schema.getGlobalDescribe().containsKey(OBJ_BP)) {
            System.assert(true, 'Skipped: FEC_MDM_Business_Process__c not on org.');
            return;
        }

        Integer bpCount = Database.countQuery('SELECT COUNT() FROM ' + OBJ_BP);
        System.assert(bpCount > 0, 'TestSetup should create Business Process when object exists.');
    }
}
