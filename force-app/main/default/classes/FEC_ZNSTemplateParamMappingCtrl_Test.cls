@IsTest
private class FEC_ZNSTemplateParamMappingCtrl_Test  {

    private static final String TEMPLATE_ID = 'TPL_PARAM_001';

    private static Id insertRecord(String objectApiName, Map<String, Object> values) {
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        System.assertNotEquals(null, sObjectType, 'Object does not exist: ' + objectApiName);

        SObject rec = sObjectType.newSObject();

        for (String fieldApiName : values.keySet()) {
            putIfCreateable(rec, fieldApiName, values.get(fieldApiName));
        }

        populateRequiredFields(rec);
        insert rec;

        return (Id) rec.get('Id');
    }

    private static void putIfCreateable(SObject rec, String fieldApiName, Object value) {
        if (value == null) {
            return;
        }

        Map<String, Schema.SObjectField> fields =
            rec.getSObjectType().getDescribe().fields.getMap();

        if (!fields.containsKey(fieldApiName)) {
            return;
        }

        if (fields.get(fieldApiName).getDescribe().isCreateable()) {
            rec.put(fieldApiName, value);
        }
    }

    private static void populateRequiredFields(SObject rec) {
        Map<String, Schema.SObjectField> fields =
            rec.getSObjectType().getDescribe().fields.getMap();

        for (String fieldApiName : fields.keySet()) {
            if (fieldApiName == 'Id' || rec.get(fieldApiName) != null) {
                continue;
            }

            Schema.DescribeFieldResult d = fields.get(fieldApiName).getDescribe();

            if (!d.isCreateable() || d.isNillable() || d.isDefaultedOnCreate()) {
                continue;
            }

            Object value = getSampleValue(d);

            if (value != null) {
                rec.put(fieldApiName, value);
            }
        }
    }

    private static Object getSampleValue(Schema.DescribeFieldResult d) {
        Schema.DisplayType t = d.getType();

        if (t == Schema.DisplayType.Boolean) {
            return false;
        }

        if (t == Schema.DisplayType.Date) {
            return Date.today();
        }

        if (t == Schema.DisplayType.DateTime) {
            return Datetime.now();
        }

        if (t == Schema.DisplayType.Time) {
            return Time.newInstance(9, 0, 0, 0);
        }

        if (t == Schema.DisplayType.Integer) {
            return 1;
        }

        if (t == Schema.DisplayType.Long) {
            return 1L;
        }

        if (
            t == Schema.DisplayType.Double ||
            t == Schema.DisplayType.Currency ||
            t == Schema.DisplayType.Percent
        ) {
            return 1;
        }

        if (
            t == Schema.DisplayType.Picklist ||
            t == Schema.DisplayType.MultiPicklist
        ) {
            for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                if (pe.isActive()) {
                    return pe.getValue();
                }
            }

            return null;
        }

        if (t == Schema.DisplayType.Reference) {
            for (Schema.SObjectType refType : d.getReferenceTo()) {
                if (refType.getDescribe().getName() == 'User') {
                    return UserInfo.getUserId();
                }
            }

            return null;
        }

        Integer maxLength = d.getLength() > 0
            ? Math.min(d.getLength(), 40)
            : 40;

        String value = 'Unit Test Value';

        return value.length() > maxLength
            ? value.substring(0, maxLength)
            : value;
    }

    private static String getFirstPicklistValue(
        String objectApiName,
        String fieldApiName,
        String fallbackValue
    ) {
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);

        if (sObjectType == null) {
            return fallbackValue;
        }

        Map<String, Schema.SObjectField> fields =
            sObjectType.getDescribe().fields.getMap();

        if (!fields.containsKey(fieldApiName)) {
            return fallbackValue;
        }

        Schema.DescribeFieldResult d = fields.get(fieldApiName).getDescribe();

        if (
            d.getType() == Schema.DisplayType.Picklist ||
            d.getType() == Schema.DisplayType.MultiPicklist
        ) {
            for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                if (pe.isActive()) {
                    return pe.getValue();
                }
            }
        }

        return fallbackValue;
    }

    @testSetup
    static void setupData() {
        insertRecord(
            'FEC_Template__c',
            new Map<String, Object>{
                'Name' => 'UT ZNS Template',
                'FEC_Subject_Line__c' => TEMPLATE_ID,
                'FEC_Preview_ZNS_Url__c' => 'https://preview.example/param',
                'FEC_Is_ZNS_Template__c' => true,
                'FEC_Active__c' => true
            }
        );

        insertRecord(
            'FEC_Notification_ZNS_Param_Mapping__c',
            new Map<String, Object>{
                'Name' => 'amount',
                'Template_ID__c' => TEMPLATE_ID,
                'Param_Type__c' => 'NUMBER',
                'Page_Context__c' => 'Case',
                'Field_Name__c' => 'CaseNumber',
                'Format_Function__c' => '',
                'Require__c' => true,
                'Accept_Null__c' => false,
                'Max_Length__c' => 20,
                'Min_Length__c' => 1
            }
        );

        insertRecord(
            'FEC_Notification_ZNS_Param_Mapping__c',
            new Map<String, Object>{
                'Name' => 'customer_name',
                'Template_ID__c' => TEMPLATE_ID,
                'Param_Type__c' => 'STRING',
                'Page_Context__c' => 'Case',
                'Field_Name__c' => 'Subject',
                'Format_Function__c' => '',
                'Require__c' => false,
                'Accept_Null__c' => true,
                'Max_Length__c' => 100,
                'Min_Length__c' => 0
            }
        );
    }

    @IsTest
    static void testSaveParamMappingsSuccessAndSkipBlankRecordId() {
        FEC_Notification_ZNS_Param_Mapping__c mapping = [
            SELECT Id
            FROM FEC_Notification_ZNS_Param_Mapping__c
            WHERE Name = 'amount'
            LIMIT 1
        ];

        String validPageContext = getFirstPicklistValue(
            'FEC_Notification_ZNS_Param_Mapping__c',
            'Page_Context__c',
            'Case'
        );

        String validFieldName = getFirstPicklistValue(
            'FEC_Notification_ZNS_Param_Mapping__c',
            'Field_Name__c',
            'ClosedDate'
        );

        String validFunction = getFirstPicklistValue(
            'FEC_Notification_ZNS_Param_Mapping__c',
            'Format_Function__c',
            'GET_DAY_OF_DATE'
        );

        List<FEC_ZNSTemplateParamMappingController.ParamMappingInput> inputs =
            new List<FEC_ZNSTemplateParamMappingController.ParamMappingInput>();

        FEC_ZNSTemplateParamMappingController.ParamMappingInput validInput =
            new FEC_ZNSTemplateParamMappingController.ParamMappingInput();

        validInput.recordId = String.valueOf(mapping.Id);
        validInput.pageContext = validPageContext;
        validInput.fieldName = validFieldName;
        validInput.functionValue = validFunction;
        inputs.add(validInput);

        FEC_ZNSTemplateParamMappingController.ParamMappingInput skippedInput =
            new FEC_ZNSTemplateParamMappingController.ParamMappingInput();

        skippedInput.recordId = '';
        skippedInput.pageContext = 'Case';
        skippedInput.fieldName = 'Subject';
        skippedInput.functionValue = '';
        inputs.add(skippedInput);

        Test.startTest();

        FEC_ZNSTemplateParamMappingController.saveParamMappings(
            JSON.serialize(inputs),
            TEMPLATE_ID
        );

        FEC_ZNSTemplateParamMappingController.saveParamMappings(
            JSON.serialize(new List<FEC_ZNSTemplateParamMappingController.ParamMappingInput>()),
            TEMPLATE_ID
        );

        Test.stopTest();

        FEC_Notification_ZNS_Param_Mapping__c updated = [
            SELECT Page_Context__c, Field_Name__c, Format_Function__c
            FROM FEC_Notification_ZNS_Param_Mapping__c
            WHERE Id = :mapping.Id
            LIMIT 1
        ];

        System.assertEquals(validPageContext, updated.Page_Context__c);
        System.assertEquals(validFieldName, updated.Field_Name__c);
        System.assertEquals(validFunction, updated.Format_Function__c);
    }

    @IsTest
    static void testSaveParamMappingsInvalidJsonNegativePath() {
        Boolean thrown = false;

        Test.startTest();

        try {
            FEC_ZNSTemplateParamMappingController.saveParamMappings(
                'not-valid-json',
                TEMPLATE_ID
            );
        } catch (Exception ex) {
            thrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, thrown, 'Expected invalid JSON to throw exception.');
    }

    @IsTest
    static void testSaveParamMappingsDmlExceptionPath() {
        Id mappingId = insertRecord(
            'FEC_Notification_ZNS_Param_Mapping__c',
            new Map<String, Object>{
                'Name' => 'deleted_param',
                'Template_ID__c' => TEMPLATE_ID,
                'Param_Type__c' => 'STRING',
                'Page_Context__c' => 'Case',
                'Field_Name__c' => 'Subject',
                'Format_Function__c' => '',
                'Require__c' => true,
                'Accept_Null__c' => false,
                'Max_Length__c' => 50,
                'Min_Length__c' => 1
            }
        );

        delete [
            SELECT Id
            FROM FEC_Notification_ZNS_Param_Mapping__c
            WHERE Id = :mappingId
            LIMIT 1
        ];

        FEC_ZNSTemplateParamMappingController.ParamMappingInput input =
            new FEC_ZNSTemplateParamMappingController.ParamMappingInput();

        input.recordId = String.valueOf(mappingId);
        input.pageContext = 'Case';
        input.fieldName = 'Subject';
        input.functionValue = '';

        Boolean thrown = false;

        Test.startTest();

        try {
            FEC_ZNSTemplateParamMappingController.saveParamMappings(
                JSON.serialize(
                    new List<FEC_ZNSTemplateParamMappingController.ParamMappingInput>{
                        input
                    }
                ),
                TEMPLATE_ID
            );
        } catch (AuraHandledException ex) {
            thrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, thrown, 'Expected DML error to be wrapped as AuraHandledException.');
    }

    @IsTest
    static void testGetHistoryNoParentRows() {
        Test.startTest();

        List<FEC_ZNSTemplateParamMappingController.HistoryRow> historyRows =
            FEC_ZNSTemplateParamMappingController.getHistory('NO_SUCH_TEMPLATE');

        Test.stopTest();

        System.assertEquals(0, historyRows.size(), 'Expected no history rows for unknown template.');
    }

    @IsTest
    static void testGetHistoryExistingParentRowsSafeResult() {
        Test.startTest();

        List<FEC_ZNSTemplateParamMappingController.HistoryRow> historyRows =
            FEC_ZNSTemplateParamMappingController.getHistory(TEMPLATE_ID);

        Test.stopTest();

        System.assert(historyRows != null, 'Expected non-null history result.');
    }
}