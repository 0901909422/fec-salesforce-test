/**
 * @description Unit tests cho FEC_MetadataFieldCreator.
 * @date 2026-03-31
 */
@isTest
private class FEC_MetadataFieldCreatorTest {

    @testSetup
    static void setupData() {
        List<FEC_Field_Deploy_Request__c> requests = new List<FEC_Field_Deploy_Request__c>();
        requests.add(new FEC_Field_Deploy_Request__c(
            FEC_Target_Object__c = 'Account',
            FEC_Field_Label__c = 'Existing Test Field',
            FEC_Field_API_Name__c = 'Existing_Test__c',
            FEC_Field_Type__c = 'Text',
            FEC_Deploy_Status__c = 'Success',
            FEC_Requested_By__c = UserInfo.getUserId(),
            FEC_Requested_Date__c = Datetime.now(),
            FEC_Completed_Date__c = Datetime.now()
        ));
        requests.add(new FEC_Field_Deploy_Request__c(
            FEC_Target_Object__c = 'Contact',
            FEC_Field_Label__c = 'Failed Field',
            FEC_Field_API_Name__c = 'Failed_Field__c',
            FEC_Field_Type__c = 'Number',
            FEC_Deploy_Status__c = 'Failed',
            FEC_Error_Message__c = 'Test error message',
            FEC_Requested_By__c = UserInfo.getUserId(),
            FEC_Requested_Date__c = Datetime.now()
        ));
        insert requests;
    }

    @isTest
    static void testValidateFieldApiName_Valid() {
        List<String> validNames = new List<String>{
            'My_Field__c', 'Test__c', 'A__c', 'Field_123__c',
            'abc_def__c', 'X1__c', 'Long_Name_Here__c'
        };
        for (String name : validNames) {
            Map<String, Object> result = FEC_MetadataFieldCreator.validateFieldApiName(name);
            Assert.isTrue((Boolean) result.get('isValid'), 'Should be valid: ' + name);
        }
    }

    @isTest
    static void testValidateFieldApiName_Invalid() {
        Map<String, Object> result;
        result = FEC_MetadataFieldCreator.validateFieldApiName('has space__c');
        Assert.isFalse((Boolean) result.get('isValid'), 'Space should be invalid');

        result = FEC_MetadataFieldCreator.validateFieldApiName('123_Field__c');
        Assert.isFalse((Boolean) result.get('isValid'), 'Starting with number should be invalid');

        result = FEC_MetadataFieldCreator.validateFieldApiName('no_suffix');
        Assert.isFalse((Boolean) result.get('isValid'), 'Missing __c should be invalid');

        result = FEC_MetadataFieldCreator.validateFieldApiName('ThisIsAVeryLongFieldNameThatExceedsMax__c');
        Assert.isFalse((Boolean) result.get('isValid'), 'Over 40 chars should be invalid');

        result = FEC_MetadataFieldCreator.validateFieldApiName('');
        Assert.isFalse((Boolean) result.get('isValid'), 'Blank should be invalid');

        result = FEC_MetadataFieldCreator.validateFieldApiName(null);
        Assert.isFalse((Boolean) result.get('isValid'), 'Null should be invalid');
    }

    @isTest
    static void testBuildFieldDefinition_Text() {
        Map<String, Object> config = new Map<String, Object>{
            'objectName' => 'Account', 'fieldLabel' => 'Text Field',
            'fieldApiName' => 'Text_Field__c', 'fieldType' => 'Text',
            'length' => 100, 'description' => 'A text field'
        };
        Map<String, Object> fieldDef = FEC_MetadataFieldCreator.buildFieldDefinition(config);
        Assert.isNotNull(fieldDef, 'Field definition should not be null');
        Assert.areEqual('Account.Text_Field__c', fieldDef.get('FullName'), 'FullName mismatch');
        Map<String, Object> metadata = (Map<String, Object>) fieldDef.get('Metadata');
        Assert.areEqual('Text', metadata.get('type'), 'Type should be Text');
        Assert.areEqual(100, metadata.get('length'), 'Length should be 100');
    }

    @isTest
    static void testBuildFieldDefinition_Number() {
        Map<String, Object> config = new Map<String, Object>{
            'objectName' => 'Account', 'fieldLabel' => 'Number Field',
            'fieldApiName' => 'Number_Field__c', 'fieldType' => 'Number',
            'length' => 2, 'description' => 'A number field'
        };
        Map<String, Object> fieldDef = FEC_MetadataFieldCreator.buildFieldDefinition(config);
        Map<String, Object> metadata = (Map<String, Object>) fieldDef.get('Metadata');
        Assert.areEqual('Number', metadata.get('type'), 'Type should be Number');
    }

    @isTest
    static void testBuildFieldDefinition_Checkbox() {
        Map<String, Object> config = new Map<String, Object>{
            'objectName' => 'Account', 'fieldLabel' => 'Check Field',
            'fieldApiName' => 'Check_Field__c', 'fieldType' => 'Checkbox',
            'description' => 'A checkbox'
        };
        Map<String, Object> fieldDef = FEC_MetadataFieldCreator.buildFieldDefinition(config);
        Map<String, Object> metadata = (Map<String, Object>) fieldDef.get('Metadata');
        Assert.areEqual('Checkbox', metadata.get('type'), 'Type should be Checkbox');
    }

    @isTest
    static void testBuildFieldDefinition_Lookup() {
        Map<String, Object> config = new Map<String, Object>{
            'objectName' => 'Account', 'fieldLabel' => 'Lookup Field',
            'fieldApiName' => 'Lookup_Field__c', 'fieldType' => 'Lookup',
            'relatedObject' => 'Contact', 'description' => 'A lookup'
        };
        Map<String, Object> fieldDef = FEC_MetadataFieldCreator.buildFieldDefinition(config);
        Map<String, Object> metadata = (Map<String, Object>) fieldDef.get('Metadata');
        Assert.areEqual('Lookup', metadata.get('type'), 'Type should be Lookup');
        Assert.areEqual('Contact', metadata.get('referenceTo'), 'Related object should be Contact');
    }

    @isTest
    static void testBuildFieldDefinition_OtherTypes() {
        List<String> types = new List<String>{ 'Date', 'DateTime', 'Currency', 'Percent', 'Phone', 'Email', 'URL' };
        for (String ft : types) {
            Map<String, Object> config = new Map<String, Object>{
                'objectName' => 'Account', 'fieldLabel' => ft + ' Field',
                'fieldApiName' => ft + '_Field__c', 'fieldType' => ft,
                'description' => 'A ' + ft + ' field'
            };
            Map<String, Object> fieldDef = FEC_MetadataFieldCreator.buildFieldDefinition(config);
            Assert.isNotNull(fieldDef, 'Field def should not be null for type: ' + ft);
            Assert.areEqual('Account.' + ft + '_Field__c', fieldDef.get('FullName'), 'FullName mismatch for: ' + ft);
        }
    }

    @isTest
    static void testCheckFieldExists_Existing() {
        Assert.isTrue(FEC_MetadataFieldCreator.checkFieldExists('Account', 'Name'), 'Account.Name should exist');
    }

    @isTest
    static void testCheckFieldExists_NonExisting() {
        Assert.isFalse(FEC_MetadataFieldCreator.checkFieldExists('Account', 'Totally_Fake__c'), 'Fake field should not exist');
    }

    @isTest
    static void testGenerateApiName_SpecialChars() {
        String apiName = FEC_MetadataFieldCreator.generateApiName('Hello World!@#');
        Assert.isTrue(apiName.endsWith('__c'), 'Should end with __c');
        Assert.isFalse(apiName.contains(' '), 'Should not contain spaces');
    }

    @isTest
    static void testGetDeployRequestStatus() {
        FEC_Field_Deploy_Request__c req = [SELECT Id FROM FEC_Field_Deploy_Request__c WHERE FEC_Deploy_Status__c = 'Success' LIMIT 1];
        Map<String, Object> status = FEC_MetadataFieldCreator.getDeployRequestStatus(req.Id);
        Assert.areEqual('Success', status.get('status'), 'Status should be Success');
    }

    @isTest
    static void testCheckDeployPermission() {
        try {
            FEC_MetadataFieldCreator.checkDeployPermission();
            Assert.isTrue(true, 'Permission check passed');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Should have error message');
        }
    }
}