/**
 * @description Service class để deploy custom field lên FEC_Additional_Info__c qua Metadata API.
 * Sử dụng Metadata.Operations.enqueueDeployment() — native Apex, không cần HTTP callout.
 * @date 2026-04-21
 */
public with sharing class FEC_MetadataFieldCreator {

    private static final String TARGET_OBJECT = 'FEC_Additional_Info__c';
    private static final String FIELD_PREFIX = 'FEC_';
    private static final String FIELD_SUFFIX = '__c';

    /**
     * @description Deploy custom field lên FEC_Additional_Info__c từ Property data.
     * @param uniqueId FEC_Unique_ID__c của Property
     * @param fieldLabel Label hiển thị
     * @param propertyType FEC_Type__c của Property (List, String, Number, etc.)
     * @param picklistValues List<String> picklist values (chỉ dùng khi type = List)
     * @return String field API name sẽ được deploy
     */
    @AuraEnabled
    public static String deployFieldFromProperty(
        String uniqueId,
        String fieldLabel,
        String propertyType,
        List<String> picklistValues
    ) {
        String fieldApiName = buildFieldApiName(uniqueId);

        // Check if field already exists
        if (checkFieldExists(TARGET_OBJECT, fieldApiName)) {
            return fieldApiName;
        }

        // Build CustomMetadata for deployment
        Metadata.CustomMetadataValue[] values = new Metadata.CustomMetadataValue[]{};

        // Use Metadata.CustomField via DeployContainer
        Metadata.DeployContainer container = new Metadata.DeployContainer();

        // Build the custom field metadata
        Map<String, Object> fieldDef = new Map<String, Object>();
        fieldDef.put('fullName', TARGET_OBJECT + '.' + fieldApiName);
        fieldDef.put('label', fieldLabel);
        fieldDef.put('trackHistory', false);
        fieldDef.put('trackTrending', false);

        switch on propertyType {
            when 'List' {
                fieldDef.put('type', 'Picklist');
                // Build picklist values XML-style for metadata deploy
            }
            when 'String' {
                fieldDef.put('type', 'Text');
                fieldDef.put('length', 255);
            }
            when 'Number' {
                fieldDef.put('type', 'Number');
                fieldDef.put('precision', 18);
                fieldDef.put('scale', 2);
            }
            when 'Boolean' {
                fieldDef.put('type', 'Checkbox');
                fieldDef.put('defaultValue', 'false');
            }
            when 'Date' {
                fieldDef.put('type', 'Date');
            }
            when 'DateTime' {
                fieldDef.put('type', 'DateTime');
            }
            when 'Phone number' {
                fieldDef.put('type', 'Phone');
            }
            when else {
                fieldDef.put('type', 'Text');
                fieldDef.put('length', 255);
            }
        }

        // Store deploy request info for tracking
        System.debug('FEC_DEBUG MetadataFieldCreator: Queuing deploy for ' + fieldApiName + ' type=' + propertyType);
        System.debug('FEC_DEBUG MetadataFieldCreator: Field definition: ' + JSON.serialize(fieldDef));

        // Note: Metadata.Operations.enqueueDeployment requires Metadata.CustomField type
        // which is only available in orgs with Metadata API enabled.
        // For sandbox/scratch orgs, we use a Queueable with Tooling API callout instead.
        System.enqueueJob(new FEC_FieldDeployQueueable(
            fieldApiName, fieldLabel, propertyType,
            picklistValues != null ? picklistValues : new List<String>()
        ));

        return fieldApiName;
    }

    /**
     * @description Build field API name from Unique ID.
     * Format: FEC_ + uniqueId + __c
     */
    @TestVisible
    private static String buildFieldApiName(String uniqueId) {
        if (String.isBlank(uniqueId)) {
            throw new AuraHandledException('Unique ID is required');
        }
        String sanitized = uniqueId.replaceAll('[^a-zA-Z0-9_]', '_');
        String apiName = FIELD_PREFIX + sanitized + FIELD_SUFFIX;
        if (apiName.length() > 40) {
            apiName = apiName.substring(0, 37) + FIELD_SUFFIX;
        }
        return apiName;
    }

    /**
     * @description Check if field already exists on target object.
     */
    @AuraEnabled
    public static Boolean checkFieldExists(String objectName, String fieldApiName) {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) return false;
        return objType.getDescribe().fields.getMap().containsKey(fieldApiName.toLowerCase());
    }

    /**
     * @description Validate field API name format.
     * Must: start with letter, contain only alphanumeric/underscore, end with __c, max 40 chars.
     */
    @AuraEnabled
    public static Map<String, Object> validateFieldApiName(String apiName) {
        Map<String, Object> result = new Map<String, Object>{ 'isValid' => false, 'errorMessage' => '' };
        if (String.isBlank(apiName)) {
            result.put('errorMessage', 'Field API Name is required');
            return result;
        }
        if (apiName.length() > 40) {
            result.put('errorMessage', 'Field API Name must be 40 characters or less');
            return result;
        }
        if (!Pattern.matches('^[a-zA-Z][a-zA-Z0-9_]*__c$', apiName)) {
            result.put('errorMessage', System.Label.FEC_Error_Invalid_Api_Name);
            return result;
        }
        result.put('isValid', true);
        return result;
    }

    /**
     * @description Build field definition map from config for Metadata API deploy.
     */
    @AuraEnabled
    public static Map<String, Object> buildFieldDefinition(Map<String, Object> config) {
        String objectName = (String) config.get('objectName');
        String fieldApiName = (String) config.get('fieldApiName');
        String fieldLabel = (String) config.get('fieldLabel');
        String fieldType = (String) config.get('fieldType');
        String description = (String) config.get('description');

        Map<String, Object> metadata = new Map<String, Object>();
        metadata.put('label', fieldLabel);
        metadata.put('type', fieldType);
        metadata.put('description', description);

        if (fieldType == 'Text') {
            metadata.put('length', config.get('length') != null ? config.get('length') : 255);
        } else if (fieldType == 'Number') {
            metadata.put('precision', 18);
            metadata.put('scale', config.get('length') != null ? config.get('length') : 2);
        } else if (fieldType == 'Checkbox') {
            metadata.put('defaultValue', 'false');
        } else if (fieldType == 'Picklist') {
            metadata.put('picklistValues', config.get('picklistValues'));
        } else if (fieldType == 'Lookup') {
            metadata.put('referenceTo', config.get('relatedObject'));
        }

        return new Map<String, Object>{
            'FullName' => objectName + '.' + fieldApiName,
            'Metadata' => metadata
        };
    }

    /**
     * @description Auto-generate API name from label.
     */
    @AuraEnabled
    public static String generateApiName(String label) {
        if (String.isBlank(label)) return '';
        String sanitized = label.replaceAll('[^a-zA-Z0-9]', '_').replaceAll('_+', '_');
        if (sanitized.startsWith('_')) sanitized = sanitized.substring(1);
        if (String.isBlank(sanitized)) return '';
        // Ensure starts with letter
        if (sanitized.substring(0, 1).isNumeric()) {
            sanitized = 'F_' + sanitized;
        }
        String apiName = sanitized + FIELD_SUFFIX;
        if (apiName.length() > 40) {
            apiName = apiName.substring(0, 37) + FIELD_SUFFIX;
        }
        return apiName;
    }

    /**
     * @description Get deploy request status by ID.
     */
    @AuraEnabled
    public static Map<String, Object> getDeployRequestStatus(Id requestId) {
        List<FEC_Field_Deploy_Request__c> requests = [
            SELECT FEC_Deploy_Status__c, FEC_Error_Message__c, FEC_Field_API_Name__c,
                   FEC_Completed_Date__c
            FROM FEC_Field_Deploy_Request__c
            WHERE Id = :requestId LIMIT 1
        ];
        if (requests.isEmpty()) {
            return new Map<String, Object>{ 'status' => 'Not Found' };
        }
        FEC_Field_Deploy_Request__c req = requests[0];
        return new Map<String, Object>{
            'status' => req.FEC_Deploy_Status__c,
            'errorMessage' => req.FEC_Error_Message__c,
            'fieldApiName' => req.FEC_Field_API_Name__c,
            'completedDate' => req.FEC_Completed_Date__c
        };
    }

    /**
     * @description Check if current user has deploy permission.
     */
    @AuraEnabled
    public static void checkDeployPermission() {
        if (!FeatureManagement.checkPermission('FEC_MDM_Field_Creator')) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Deploy_Permission);
        }
    }

    /**
     * @description Deploy a custom field using Tooling API via Queueable.
     * Called from LWC fecAutoFieldCreator.
     */
    @AuraEnabled
    public static Map<String, Object> deployCustomField(Map<String, Object> config) {
        String objectName = (String) config.get('objectName');
        String fieldApiName = (String) config.get('fieldApiName');
        String fieldLabel = (String) config.get('fieldLabel');
        String fieldType = (String) config.get('fieldType');
        String description = (String) config.get('description');
        Integer fieldLength = config.get('length') != null ? Integer.valueOf(String.valueOf(config.get('length'))) : 255;
        String picklistValues = (String) config.get('picklistValues');
        String relatedObject = (String) config.get('relatedObject');

        // Validate
        Map<String, Object> validation = validateFieldApiName(fieldApiName);
        if (!(Boolean) validation.get('isValid')) {
            throw new AuraHandledException((String) validation.get('errorMessage'));
        }
        if (checkFieldExists(objectName, fieldApiName)) {
            throw new AuraHandledException(String.format(System.Label.FEC_Error_Field_Already_Exists, new List<String>{ fieldApiName, objectName }));
        }

        // Create deploy request record
        FEC_Field_Deploy_Request__c request = new FEC_Field_Deploy_Request__c(
            FEC_Target_Object__c = objectName,
            FEC_Field_Label__c = fieldLabel,
            FEC_Field_API_Name__c = fieldApiName,
            FEC_Field_Type__c = fieldType,
            FEC_Field_Description__c = description,
            FEC_Field_Length__c = fieldLength,
            FEC_Picklist_Values__c = picklistValues,
            FEC_Related_Object__c = relatedObject,
            FEC_Deploy_Status__c = 'Pending',
            FEC_Requested_By__c = UserInfo.getUserId(),
            FEC_Requested_Date__c = Datetime.now()
        );
        insert request;

        // Enqueue deploy job
        List<String> picklistList = String.isNotBlank(picklistValues) ? picklistValues.split('\n') : new List<String>();
        System.enqueueJob(new FEC_FieldDeployQueueable(fieldApiName, fieldLabel, fieldType, picklistList));

        return new Map<String, Object>{
            'requestId' => request.Id,
            'fieldApiName' => fieldApiName,
            'status' => 'Pending'
        };
    }
}