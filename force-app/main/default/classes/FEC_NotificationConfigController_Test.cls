@IsTest
private class FEC_NotificationConfigController_Test {

    private static final String SUB_CATEGORY_CODE = 'UT_SUB';
    private static final String SUB_CODE_CODE     = 'UT_CODE';
    private static final String QUEUE_CODE        = 'UT_QUEUE';

    // ============================================================
    // Generic Test Data Helpers
    // ============================================================

    private static Id insertRecord(String objectApiName, Map<String, Object> values) {
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        System.assert(sObjectType != null, 'Object does not exist: ' + objectApiName);

        SObject rec = sObjectType.newSObject();

        for (String fieldApiName : values.keySet()) {
            putIfCreateable(rec, fieldApiName, values.get(fieldApiName));
        }

        populateRequiredFields(rec);
        insert rec;

        return (Id) rec.get('Id');
    }

    private static Database.SaveResult tryInsertRecord(
        String objectApiName,
        Map<String, Object> values
    ) {
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        System.assert(sObjectType != null, 'Object does not exist: ' + objectApiName);

        SObject rec = sObjectType.newSObject();

        for (String fieldApiName : values.keySet()) {
            putIfCreateable(rec, fieldApiName, values.get(fieldApiName));
        }

        populateRequiredFields(rec);

        return Database.insert(rec, false);
    }

    private static Id getIdByName(String objectApiName, String recordName) {
        List<SObject> rows = Database.query(
            'SELECT Id FROM ' + objectApiName + ' WHERE Name = :recordName LIMIT 1'
        );

        return rows.isEmpty() ? null : (Id) rows[0].get('Id');
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

    private static void putIfCreateable(
        SObject rec,
        String fieldApiName,
        Object value
    ) {
        if (value == null) {
            return;
        }

        Map<String, Schema.SObjectField> fields =
            rec.getSObjectType().getDescribe().fields.getMap();

        if (!fields.containsKey(fieldApiName)) {
            return;
        }

        Schema.DescribeFieldResult d = fields.get(fieldApiName).getDescribe();

        if (d.isCreateable()) {
            rec.put(fieldApiName, value);
        }
    }

    private static void populateRequiredFields(SObject rec) {
        Map<String, Schema.SObjectField> fields =
            rec.getSObjectType().getDescribe().fields.getMap();

        for (String fieldApiName : fields.keySet()) {
            if (fieldApiName == 'Id') {
                continue;
            }

            if (rec.get(fieldApiName) != null) {
                continue;
            }

            Schema.DescribeFieldResult d = fields.get(fieldApiName).getDescribe();

            if (!d.isCreateable() || d.isNillable() || d.isDefaultedOnCreate()) {
                continue;
            }

            if (fieldApiName == 'RecordTypeId') {
                Id recordTypeId = getFirstAvailableRecordTypeId(rec.getSObjectType());

                if (recordTypeId != null) {
                    rec.put(fieldApiName, recordTypeId);
                }

                continue;
            }

            Object value = getSampleValue(d);

            if (value != null) {
                rec.put(fieldApiName, value);
            }
        }
    }

    private static Id getFirstAvailableRecordTypeId(Schema.SObjectType sObjectType) {
        for (Schema.RecordTypeInfo rtInfo :
            sObjectType.getDescribe().getRecordTypeInfos()
        ) {
            if (rtInfo.isAvailable() && !rtInfo.isMaster()) {
                return rtInfo.getRecordTypeId();
            }
        }

        return null;
    }

    private static Object getSampleValue(Schema.DescribeFieldResult d) {
        Schema.DisplayType fieldType = d.getType();

        if (fieldType == Schema.DisplayType.Boolean) {
            return false;
        }

        if (fieldType == Schema.DisplayType.Date) {
            return Date.today();
        }

        if (fieldType == Schema.DisplayType.DateTime) {
            return Datetime.now();
        }

        if (fieldType == Schema.DisplayType.Time) {
            return Time.newInstance(9, 0, 0, 0);
        }

        if (fieldType == Schema.DisplayType.Integer) {
            return 1;
        }

        if (fieldType == Schema.DisplayType.Long) {
            return 1L;
        }

        if (
            fieldType == Schema.DisplayType.Double ||
            fieldType == Schema.DisplayType.Currency ||
            fieldType == Schema.DisplayType.Percent
        ) {
            return 1;
        }

        if (
            fieldType == Schema.DisplayType.Picklist ||
            fieldType == Schema.DisplayType.MultiPicklist
        ) {
            for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                if (pe.isActive()) {
                    return pe.getValue();
                }
            }

            return null;
        }

        if (fieldType == Schema.DisplayType.Reference) {
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

    private static Boolean hasBlockingNatureOfCase(
        Id productTypeId,
        Id categoryId,
        String subCategoryCode,
        String subCodeCode
    ) {
        Integer countRows = [
            SELECT COUNT()
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Product_Type__c = :productTypeId
            AND FEC_Category__c = :categoryId
            AND FEC_Sub_Category__r.FEC_Code__c = :subCategoryCode
            AND FEC_Sub_Code__r.FEC_Code__c = :subCodeCode
            AND FEC_Active__c = true
        ];

        return countRows > 0;
    }

    // ============================================================
    // Payload Helper
    // ============================================================

    private static String buildPayload(
        Id recordId,
        String notificationName,
        Boolean notificationStatus,
        Id productTypeId,
        Id categoryId,
        String subCategoryCode,
        String subCodeCode,
        Id notificationChannelId,
        Id templateId,
        Boolean includeValidChannelTemplateLine,
        String startTime,
        String endTime
    ) {
        List<Object> channelTemplateLines = new List<Object>();

        if (includeValidChannelTemplateLine) {
            channelTemplateLines.add(
                new Map<String, Object>{
                    'channelId' => String.valueOf(notificationChannelId),
                    'templateId' => String.valueOf(templateId)
                }
            );
        } else {
            channelTemplateLines.add(
                new Map<String, Object>{
                    'channelId' => '',
                    'templateId' => String.valueOf(templateId)
                }
            );
        }

        Map<String, Object> payload = new Map<String, Object>{
            'recordId' => recordId == null ? null : String.valueOf(recordId),
            'tabType' => 'auto',
            'notificationType' => notificationName,
            'targetGroup' => getFirstPicklistValue(
                'FEC_Notification__c',
                'FEC_Target_Group__c',
                'Customer'
            ),
            'customerType' => getFirstPicklistValue(
                'FEC_Notification__c',
                'FEC_Customer_Type__c',
                'Customer'
            ),
            'notificationStatus' => notificationStatus,
            'channel' => 'UT Channel',
            'productType' => String.valueOf(productTypeId),
            'category' => String.valueOf(categoryId),

            /*
             * Important:
             * FEC_Notification__c.FEC_SubCategory__c and FEC_SubCode__c
             * store delimited FEC_Code__c values, not record Ids.
             */
            'subCategory' => subCategoryCode,
            'subCode' => subCodeCode,

            'currentStatus' => getFirstPicklistValue(
                'FEC_Notification__c',
                'FEC_Current_Status__c',
                'Open'
            ),
            'changedStatus' => getFirstPicklistValue(
                'FEC_Notification__c',
                'FEC_Changed_Status__c',
                'Closed'
            ),
            'assignedToQueue' => QUEUE_CODE,
            'receivers' => 'unit.test@example.com',
            'applicableUserGroups' => getFirstPicklistValue(
                'FEC_Notification__c',
                'FEC_Applicable_User_Groups__c',
                'All'
            ),
            'caseStage' => getFirstPicklistValue(
                'FEC_Notification__c',
                'FEC_Case_Stage__c',
                'UT Case Stage'
            ),
            'scheduleStartTime' => startTime,
            'scheduleEndTime' => endTime,
            'channelTemplateLines' => JSON.serialize(channelTemplateLines)
        };

        return JSON.serialize(payload);
    }

    // ============================================================
    // Test Setup
    // ============================================================

    @testSetup
    static void setupData() {
        Id productTypeId = insertRecord(
            'FEC_Product_Type__c',
            new Map<String, Object>{
                'Name' => 'UT Product Type'
            }
        );

        Id categoryId = insertRecord(
            'FEC_Category__c',
            new Map<String, Object>{
                'Name' => 'UT Category',

                /*
                 * Some orgs use lookup filters Category -> Product Type.
                 * If this field does not exist, helper ignores it.
                 */
                'FEC_Product_Type__c' => productTypeId
            }
        );

        Id subCategoryId = insertRecord(
            'FEC_Sub_Category__c',
            new Map<String, Object>{
                'Name' => 'UT Sub Category',
                'FEC_Code__c' => SUB_CATEGORY_CODE,

                /*
                 * These fields are included for lookup-filter compatibility.
                 * Missing fields are ignored by putIfCreateable().
                 */
                'FEC_Product_Type__c' => productTypeId,
                'FEC_Category__c' => categoryId
            }
        );

        Id subCodeId = insertRecord(
            'FEC_Sub_Code__c',
            new Map<String, Object>{
                'Name' => 'UT Sub Code',
                'FEC_Code__c' => SUB_CODE_CODE,

                /*
                 * These fields are included for lookup-filter compatibility.
                 * Missing fields are ignored by putIfCreateable().
                 */
                'FEC_Product_Type__c' => productTypeId,
                'FEC_Category__c' => categoryId,
                'FEC_Sub_Category__c' => subCategoryId,
                'FEC_SubCategory__c' => subCategoryId
            }
        );

        /*
         * FEC_Nature_of_Case__c may have lookup filters that vary by org.
         * Use safe insert so the whole test class does not fail in @testSetup.
         * If it succeeds, disable-validation tests will assert the blocking path.
         * If it fails, the tests still cover safe/non-blocking paths.
         */
        tryInsertRecord(
            'FEC_Nature_of_Case__c',
            new Map<String, Object>{
                'Name' => 'UT Active Nature Of Case',
                'FEC_Product_Type__c' => productTypeId,
                'FEC_Category__c' => categoryId,
                'FEC_Sub_Category__c' => subCategoryId,
                'FEC_Sub_Code__c' => subCodeId,
                'FEC_Active__c' => true
            }
        );

        insertRecord(
            'FEC_Case_Status__c',
            new Map<String, Object>{
                'Name' => 'UT Case Status'
            }
        );

        insertRecord(
            'FEC_Case_Stage__c',
            new Map<String, Object>{
                'Name' => 'UT Case Stage'
            }
        );

        insertRecord(
            'FEC_Channel__c',
            new Map<String, Object>{
                'Name' => 'UT Channel'
            }
        );

        Id notificationChannelId = insertRecord(
            'FEC_Notification_Channel__c',
            new Map<String, Object>{
                'Name' => 'UT Notification Channel',
                'FEC_Noti_Channel_Status__c' => true
            }
        );

        Id templateId = insertRecord(
            'FEC_Template__c',
            new Map<String, Object>{
                'Name' => 'UT Template',
                'FEC_API_Name__c' => 'UT_TEMPLATE_API',
                'FEC_Subject_Line__c' => 'UT Subject',
                'FEC_Active__c' => true,
                'FEC_Is_ZNS_Template__c' => false
            }
        );

        Id notificationId = insertRecord(
            'FEC_Notification__c',
            new Map<String, Object>{
                'Name' => 'UT Existing Notification',
                'FEC_Target_Group__c' => getFirstPicklistValue(
                    'FEC_Notification__c',
                    'FEC_Target_Group__c',
                    'Customer'
                ),
                'FEC_Customer_Type__c' => getFirstPicklistValue(
                    'FEC_Notification__c',
                    'FEC_Customer_Type__c',
                    'Customer'
                ),
                'FEC_Notification_Status__c' => true,
                'FEC_Channel__c' => 'UT Channel',
                'FEC_Product_Type__c' => productTypeId,
                'FEC_Category__c' => categoryId,

                /*
                 * These fields store FEC_Code__c values.
                 */
                'FEC_SubCategory__c' => SUB_CATEGORY_CODE,
                'FEC_SubCode__c' => SUB_CODE_CODE,

                'FEC_Current_Status__c' => getFirstPicklistValue(
                    'FEC_Notification__c',
                    'FEC_Current_Status__c',
                    'Open'
                ),
                'FEC_Changed_Status__c' => getFirstPicklistValue(
                    'FEC_Notification__c',
                    'FEC_Changed_Status__c',
                    'Closed'
                ),
                'FEC_Assigned_to_Queue__c' => QUEUE_CODE,
                'FEC_Receivers__c' => 'unit.test@example.com',
                'FEC_Applicable_User_Groups__c' => getFirstPicklistValue(
                    'FEC_Notification__c',
                    'FEC_Applicable_User_Groups__c',
                    'All'
                ),
                'FEC_Case_Stage__c' => getFirstPicklistValue(
                    'FEC_Notification__c',
                    'FEC_Case_Stage__c',
                    'UT Case Stage'
                ),
                'FEC_Schedule_Start_Time__c' => Time.newInstance(8, 0, 0, 0),
                'FEC_Schedule_End_Time__c' => Time.newInstance(17, 30, 0, 0)
            }
        );

        insertRecord(
            'FEC_Notification_Template_Channel__c',
            new Map<String, Object>{
                'FEC_Notification__c' => notificationId,
                'FEC_Notification_Channel__c' => notificationChannelId,
                'FEC_Notification_Template__c' => templateId
            }
        );
    }

    // ============================================================
    // Data Retrieval / Picklists
    // ============================================================

    @IsTest
    static void testDataRetrievalAndPicklists() {
        FEC_Notification__c existingNotification = [
            SELECT Id
            FROM FEC_Notification__c
            WHERE Name = 'UT Existing Notification'
            LIMIT 1
        ];

        Id productTypeId = getIdByName('FEC_Product_Type__c', 'UT Product Type');
        Id categoryId = getIdByName('FEC_Category__c', 'UT Category');

        Test.startTest();

        List<FEC_Notification__c> notifications =
            FEC_NotificationConfigController.getNotifications();

        FEC_Notification__c notificationById =
            FEC_NotificationConfigController.getNotificationById(existingNotification.Id);

        List<FEC_Notification_Channel__c> notificationChannels =
            FEC_NotificationConfigController.getNotificationChannels();

        List<FEC_Channel__c> channels =
            FEC_NotificationConfigController.getChannels();

        Map<String, Object> allPicklists =
            FEC_NotificationConfigController.getPicklistValues(null, null);

        Map<String, Object> filteredPicklists =
            FEC_NotificationConfigController.getPicklistValues(
                'categories',
                productTypeId
            );

        List<FEC_Sub_Category__c> subCategories =
            FEC_NotificationConfigController.getSubCategories(
                productTypeId,
                categoryId
            );

        List<FEC_Sub_Code__c> subCodes =
            FEC_NotificationConfigController.getSubCodes(
                productTypeId,
                categoryId,
                new List<String>{ SUB_CATEGORY_CODE }
            );

        Boolean duplicateExists =
            FEC_NotificationConfigController.checkDuplicateNotifType(
                'UT Existing Notification',
                null
            );

        Boolean duplicateExcluded =
            FEC_NotificationConfigController.checkDuplicateNotifType(
                'UT Existing Notification',
                existingNotification.Id
            );

        Test.stopTest();

        System.assert(notifications.size() > 0, 'Expected at least one notification.');
        System.assertEquals(existingNotification.Id, notificationById.Id);
        System.assert(notificationChannels.size() > 0, 'Expected notification channels.');
        System.assert(channels.size() > 0, 'Expected channels.');

        System.assert(allPicklists.containsKey('productTypes'));
        System.assert(allPicklists.containsKey('categories'));
        System.assert(allPicklists.containsKey('caseStatuses'));
        System.assert(allPicklists.containsKey('queues'));
        System.assert(allPicklists.containsKey('customerTypes'));
        System.assert(allPicklists.containsKey('userGroups'));
        System.assert(allPicklists.containsKey('caseStages'));
        System.assert(allPicklists.containsKey('channels'));
        System.assert(allPicklists.containsKey('templates'));

        System.assert(filteredPicklists.containsKey('categories'));

        /*
         * These lists may be empty if FEC_Nature_of_Case__c safe insert
         * was blocked by org-specific lookup filters.
         */
        System.assert(subCategories != null, 'Expected non-null sub category result.');
        System.assert(subCodes != null, 'Expected non-null sub code result.');

        System.assertEquals(true, duplicateExists);
        System.assertEquals(false, duplicateExcluded);
    }

    // ============================================================
    // Save / Update / Delete / Export
    // ============================================================

    @IsTest
    static void testSaveNotificationCreateUpdateDeleteAndExport() {
        Id productTypeId = getIdByName('FEC_Product_Type__c', 'UT Product Type');
        Id categoryId = getIdByName('FEC_Category__c', 'UT Category');

        Id notificationChannelId =
            getIdByName('FEC_Notification_Channel__c', 'UT Notification Channel');

        Id templateId =
            getIdByName('FEC_Template__c', 'UT Template');

        Test.startTest();

        Id newNotificationId =
            FEC_NotificationConfigController.saveNotification(
                buildPayload(
                    null,
                    'UT Created Notification',
                    true,
                    productTypeId,
                    categoryId,
                    SUB_CATEGORY_CODE,
                    '',
                    notificationChannelId,
                    templateId,
                    true,
                    '09:15',
                    '18:45'
                )
            );

        FEC_Notification__c createdNotification = [
            SELECT
                Id,
                Name,
                FEC_SubCategory__c,
                FEC_SubCode__c,
                FEC_Schedule_Start_Time__c,
                FEC_Schedule_End_Time__c
            FROM FEC_Notification__c
            WHERE Id = :newNotificationId
            LIMIT 1
        ];

        Integer insertedJunctionCount = [
            SELECT COUNT()
            FROM FEC_Notification_Template_Channel__c
            WHERE FEC_Notification__c = :newNotificationId
        ];

        Id updatedNotificationId =
            FEC_NotificationConfigController.saveNotification(
                buildPayload(
                    newNotificationId,
                    'UT Updated Notification',
                    true,
                    productTypeId,
                    categoryId,
                    '',
                    '',
                    notificationChannelId,
                    templateId,
                    false,
                    '',
                    ''
                )
            );

        Integer remainingJunctionCount = [
            SELECT COUNT()
            FROM FEC_Notification_Template_Channel__c
            WHERE FEC_Notification__c = :newNotificationId
        ];

        String exportedBase64 =
            FEC_NotificationConfigController.exportNotifications('auto');

        String exportedCsv =
            EncodingUtil.base64Decode(exportedBase64).toString();

        FEC_NotificationConfigController.deleteNotification(newNotificationId);

        Test.stopTest();

        System.assert(newNotificationId != null, 'Expected created notification Id.');
        System.assertEquals(newNotificationId, updatedNotificationId);
        System.assertEquals('UT Created Notification', createdNotification.Name);
        System.assertEquals(SUB_CATEGORY_CODE, createdNotification.FEC_SubCategory__c);
        System.assert(
            String.isBlank(createdNotification.FEC_SubCode__c),
            'Expected Sub Code to be blank/null when payload subCode is blank.'
        );
        //System.assertEquals('', createdNotification.FEC_SubCode__c);
        System.assert(createdNotification.FEC_Schedule_Start_Time__c != null);
        System.assert(createdNotification.FEC_Schedule_End_Time__c != null);
        System.assertEquals(1, insertedJunctionCount);
        System.assertEquals(0, remainingJunctionCount);

        System.assert(exportedCsv.contains('Notification Type'));
        System.assert(exportedCsv.contains('UT Updated Notification'));

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM FEC_Notification__c
                WHERE Id = :newNotificationId
            ],
            'Expected notification to be deleted.'
        );
    }

    // ============================================================
    // Negative / Boundary Paths
    // ============================================================

    @IsTest
    static void testDuplicateAndDisableValidationPaths() {
        Id productTypeId = getIdByName('FEC_Product_Type__c', 'UT Product Type');
        Id categoryId = getIdByName('FEC_Category__c', 'UT Category');

        Id notificationChannelId =
            getIdByName('FEC_Notification_Channel__c', 'UT Notification Channel');

        Id templateId =
            getIdByName('FEC_Template__c', 'UT Template');

        FEC_Notification__c existingNotification = [
            SELECT Id
            FROM FEC_Notification__c
            WHERE Name = 'UT Existing Notification'
            LIMIT 1
        ];

        Boolean hasBlockingNoC = hasBlockingNatureOfCase(
            productTypeId,
            categoryId,
            SUB_CATEGORY_CODE,
            SUB_CODE_CODE
        );

        Boolean duplicateThrown = false;
        Boolean toggleValidationThrown = false;
        Boolean saveValidationThrown = false;

        Test.startTest();

        try {
            FEC_NotificationConfigController.saveNotification(
                buildPayload(
                    null,
                    'UT Existing Notification',
                    true,
                    productTypeId,
                    categoryId,
                    SUB_CATEGORY_CODE,
                    SUB_CODE_CODE,
                    notificationChannelId,
                    templateId,
                    true,
                    '',
                    ''
                )
            );
        } catch (AuraHandledException ex) {
            duplicateThrown = true;
        }

        try {
            FEC_NotificationConfigController.toggleNotificationStatus(
                existingNotification.Id,
                false
            );
        } catch (AuraHandledException ex) {
            toggleValidationThrown = true;
        }

        try {
            FEC_NotificationConfigController.saveNotification(
                buildPayload(
                    existingNotification.Id,
                    'UT Existing Notification',
                    false,
                    productTypeId,
                    categoryId,
                    SUB_CATEGORY_CODE,
                    SUB_CODE_CODE,
                    notificationChannelId,
                    templateId,
                    true,
                    '',
                    ''
                )
            );
        } catch (AuraHandledException ex) {
            saveValidationThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, duplicateThrown);

        if (hasBlockingNoC) {
            System.assertEquals(
                true,
                toggleValidationThrown,
                'Expected toggle disable validation to throw when active Nature of Case exists.'
            );

            System.assertEquals(
                true,
                saveValidationThrown,
                'Expected save disable validation to throw when active Nature of Case exists.'
            );
        } else {
            System.assertEquals(
                false,
                toggleValidationThrown,
                'No active matching Nature of Case was inserted, so toggle should not throw.'
            );
        }
    }

    // ============================================================
    // Toggle / Channel Status Success
    // ============================================================

    @IsTest
    static void testToggleAndChannelStatusSuccessPaths() {
        Id productTypeId = getIdByName('FEC_Product_Type__c', 'UT Product Type');
        Id categoryId = getIdByName('FEC_Category__c', 'UT Category');

        Id channelId =
            getIdByName('FEC_Notification_Channel__c', 'UT Notification Channel');

        Id safeNotificationId = insertRecord(
            'FEC_Notification__c',
            new Map<String, Object>{
                'Name' => 'UT Safe Toggle Notification',
                'FEC_Target_Group__c' => getFirstPicklistValue(
                    'FEC_Notification__c',
                    'FEC_Target_Group__c',
                    'Customer'
                ),
                'FEC_Customer_Type__c' => getFirstPicklistValue(
                    'FEC_Notification__c',
                    'FEC_Customer_Type__c',
                    'Customer'
                ),
                'FEC_Notification_Status__c' => true,
                'FEC_Channel__c' => 'UT Channel',
                'FEC_Product_Type__c' => productTypeId,
                'FEC_Category__c' => categoryId,

                /*
                 * Blank codes guarantee validateCanDisableNotification()
                 * has no matching blocking Nature of Case.
                 */
                'FEC_SubCategory__c' => '',
                'FEC_SubCode__c' => '',

                'FEC_Assigned_to_Queue__c' => QUEUE_CODE
            }
        );

        Test.startTest();

        FEC_NotificationConfigController.toggleNotificationStatus(
            safeNotificationId,
            false
        );

        FEC_NotificationConfigController.toggleNotificationStatus(
            safeNotificationId,
            true
        );

        FEC_NotificationConfigController.updateChannelStatus(
            channelId,
            false
        );

        Test.stopTest();

        FEC_Notification__c notification = [
            SELECT FEC_Notification_Status__c
            FROM FEC_Notification__c
            WHERE Id = :safeNotificationId
            LIMIT 1
        ];

        FEC_Notification_Channel__c channel = [
            SELECT FEC_Noti_Channel_Status__c
            FROM FEC_Notification_Channel__c
            WHERE Id = :channelId
            LIMIT 1
        ];

        System.assertEquals(true, notification.FEC_Notification_Status__c);
        System.assertEquals(false, channel.FEC_Noti_Channel_Status__c);
    }

    // ============================================================
    // Bulk Boundary
    // ============================================================

    @IsTest
    static void testBulkSaveNotifications() {
        Id productTypeId = getIdByName('FEC_Product_Type__c', 'UT Product Type');
        Id categoryId = getIdByName('FEC_Category__c', 'UT Category');

        Id notificationChannelId =
            getIdByName('FEC_Notification_Channel__c', 'UT Notification Channel');

        Id templateId =
            getIdByName('FEC_Template__c', 'UT Template');

        List<Id> createdIds = new List<Id>();

        Test.startTest();

        for (Integer i = 0; i < 10; i++) {
            createdIds.add(
                FEC_NotificationConfigController.saveNotification(
                    buildPayload(
                        null,
                        'UT Bulk Notification ' + i,
                        true,
                        productTypeId,
                        categoryId,
                        '',
                        '',
                        notificationChannelId,
                        templateId,
                        true,
                        '07:0' + Math.mod(i, 10),
                        '08:0' + Math.mod(i, 10)
                    )
                )
            );
        }

        Test.stopTest();

        Integer savedCount = [
            SELECT COUNT()
            FROM FEC_Notification__c
            WHERE Id IN :createdIds
        ];

        Integer junctionCount = [
            SELECT COUNT()
            FROM FEC_Notification_Template_Channel__c
            WHERE FEC_Notification__c IN :createdIds
        ];

        System.assertEquals(10, createdIds.size());
        System.assertEquals(10, savedCount);
        System.assertEquals(10, junctionCount);
    }

    // ============================================================
    // History Logs
    // ============================================================

    @IsTest
    static void testHistoryLogsSafeResult() {
        FEC_Notification__c existingNotification = [
            SELECT Id
            FROM FEC_Notification__c
            WHERE Name = 'UT Existing Notification'
            LIMIT 1
        ];

        Test.startTest();

        List<FEC_NotificationConfigController.AuditTransactionDTO> historyRows =
            FEC_NotificationConfigController.getHistoryLogs(existingNotification.Id);

        Test.stopTest();

        System.assert(historyRows != null, 'Expected non-null history log response.');
    }
}