/**
 * NotificationConfigController
 * ──────────────────────────────────────────────────────────────────────────
 * Apex controller for the Notification Configuration Tool LWC.
 * Provides data retrieval, CRUD operations, validation, audit logging,
 * and Excel export for FEC_Notification__c and related objects.
 *
 * @author  FEC Dev
 * @version 1.0
 */
public with sharing class FEC_NotificationConfigController {


    // ─── Data Retrieval ────────────────────────────────────────────────────

    /**
     * Returns all FEC_Notification__c records along with child
     * FEC_Notification_Template_Channel__c junction records and related
     * lookups needed by the data table.
     */
    @AuraEnabled(cacheable=false)
    public static List<FEC_Notification__c> getNotifications() {
        return [
            SELECT Id,
                   Name,
                   FEC_Target_Group__c,
                   FEC_Customer_Type__c,
                   FEC_Notification_Status__c,
                   FEC_Channel__c,
                   FEC_Product_Type__c,
                   FEC_Product_Type__r.Name,
                   FEC_Category__c,
                   FEC_Category__r.Name,
                   FEC_SubCategory__c,
                   FEC_SubCode__c,
                   FEC_Current_Status__c,
                   FEC_Changed_Status__c,
                   FEC_Assigned_to_Queue__c,
                   FEC_Receivers__c,
                   FEC_Schedule_Start_Time__c,
                   FEC_Schedule_End_Time__c,
                   FEC_Applicable_User_Groups__c,
                   FEC_Case_Stage__c,
                   RecordType.Id,
                   RecordType.Name,
                   (
                       SELECT Id,
                              FEC_Notification_Channel__c,
                              FEC_Notification_Channel__r.Name,
                              FEC_Notification_Channel__r.FEC_Noti_Channel_Status__c,
                              FEC_Notification_Template__c,
                              FEC_Notification_Template__r.Name,
                              FEC_Notification_Template__r.FEC_API_Name__c,
                              FEC_Notification_Template__r.FEC_Subject_Line__c,
                              FEC_Notification_Template__r.FEC_Active__c,
                              FEC_Notification_Template__r.FEC_Is_ZNS_Template__c,
                              FEC_Notification_Template__r.FEC_Preview_ZNS_Url__c
                       FROM Notification_Template_Channel__r
                   )
            FROM FEC_Notification__c
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Returns a single FEC_Notification__c record with all fields for the
     * edit modal pre-population.
     */
    @AuraEnabled(cacheable=false)
    public static FEC_Notification__c getNotificationById(Id recordId) {
        return [
            SELECT Id, Name, RecordType.Name, RecordTypeId, RecordType.DeveloperName, 
                   FEC_Target_Group__c,
                   FEC_Customer_Type__c,
                   FEC_Notification_Status__c,
                   FEC_Channel__c,
                   FEC_Product_Type__c, FEC_Product_Type__r.Name,
                   FEC_Category__c, FEC_Category__r.Name,
                   FEC_SubCategory__c,
                   FEC_SubCode__c,
                   FEC_Current_Status__c,
                   FEC_Changed_Status__c,
                   FEC_Assigned_to_Queue__c,
                   FEC_Receivers__c,
                   FEC_Schedule_Start_Time__c,
                   FEC_Schedule_End_Time__c,
                   FEC_Applicable_User_Groups__c,
                   FEC_Case_Stage__c,
                   (
                       SELECT Id,
                              FEC_Notification_Channel__c,
                              FEC_Notification_Channel__r.FEC_Noti_Channel_Status__c,
                              FEC_Notification_Template__c
                       FROM Notification_Template_Channel__r
                   )
            FROM FEC_Notification__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }

    /**
     * Returns all active FEC_Notification_Channel__c records for the
     * Channel Settings tab and for the notification modal channel picklist.
     */
    @AuraEnabled(cacheable=false)
    public static List<FEC_Notification_Channel__c> getNotificationChannels() {
        return [
            SELECT Id, Name, FEC_Noti_Channel_Status__c
            FROM FEC_Notification_Channel__c
            ORDER BY Name ASC
        ];
    }

    /**
     * Returns all active FEC_Channel__c records for the
     * Channel Settings tab and for the notification modal channel picklist.
     */
    @AuraEnabled(cacheable=false)
    public static List<FEC_Channel__c> getChannels() {
        return [
            SELECT Id, Name FROM FEC_Channel__c
            ORDER BY Name ASC
        ];
    }

    /**
     * Returns all picklist option data needed by the creation modal,
     * including product types, categories, case statuses, queues, templates, etc.
     * Pass filterType = 'categories' and productTypeId to get filtered categories.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPicklistValues(
            String filterType,
            Id productTypeId) {
        Map<String, Object> result = new Map<String, Object>();

        // Product Types
        List<Map<String,String>> ptList = new List<Map<String,String>>();
        for (FEC_Product_Type__c pt : [
            SELECT Id, Name FROM FEC_Product_Type__c 
            WHERE Id IN (SELECT FEC_Product_Type__c FROM FEC_Nature_of_Case__c WHERE FEC_Product_Type__c != NULL)
            ORDER BY Name]) {
                ptList.add(new Map<String,String>{ 'Id' => pt.Id, 'Name' => pt.Name });
        }
        result.put('productTypes', ptList);

        // Categories (optionally filtered by product type)
        List<Map<String,String>> catList = new List<Map<String,String>>();
        String catQuery = 'SELECT Id, Name FROM FEC_Category__c WHERE Id IN (SELECT FEC_Category__c FROM FEC_Nature_of_Case__c WHERE FEC_Category__c != NULL';
        if (filterType == 'categories' && productTypeId != null) {
            catQuery += ' AND FEC_Product_Type__c = :productTypeId';
            //catQuery += ' WHERE FEC_Product_Type__c = :productTypeId';
        }
        catQuery += ') ORDER BY Name';
        for (FEC_Category__c cat : Database.query(catQuery)) {
            catList.add(new Map<String,String>{ 'Id' => cat.Id, 'Name' => cat.Name });
        }
        result.put('categories', catList);

        // Case Statuses
        List<Map<String,String>> statusList = new List<Map<String,String>>();
        for (FEC_Case_Status__c row : [SELECT Id, Name FROM FEC_Case_Status__c ORDER BY Name]) {
            statusList.add(new Map<String,String>{
                    'Id' => row.Id, 'Name' => row.Name });
        }
        // Schema.DescribeFieldResult statusField =
        //     FEC_Case_Status__c.Name.getDescribe();
        // for (Schema.PicklistEntry pe : statusField.getPicklistValues()) {
        //     if (pe.isActive()) {
        //         statusList.add(new Map<String,String>{
        //             'label' => pe.getLabel(), 'value' => pe.getValue() });
        //     }
        // }
        result.put('caseStatuses', statusList);

        // Queues
        List<Map<String,String>> queueList = new List<Map<String,String>>();
        for (Group q : [SELECT Id, Name, DeveloperName FROM Group WHERE Type = 'Queue' ORDER BY Name]) {
            //queueList.add(new Map<String,String>{ 'Id' => q.Id, 'Name' => q.Name });
            queueList.add(new Map<String,String>{ 'Id' => q.DeveloperName, 'Name' => q.Name });
        }
        result.put('queues', queueList);

        // Customer Types — from FEC_Customer_Type__c picklist
        Schema.DescribeFieldResult custField =
            FEC_Notification__c.FEC_Customer_Type__c.getDescribe();
        List<Map<String,String>> custList = new List<Map<String,String>>();
        for (Schema.PicklistEntry pe : custField.getPicklistValues()) {
            if (pe.isActive()) {
                custList.add(new Map<String,String>{
                    'label' => pe.getLabel(), 'value' => pe.getValue() });
            }
        }
        result.put('customerTypes', custList);

        // Applicable User Groups
        Schema.DescribeFieldResult ugField =
            FEC_Notification__c.FEC_Applicable_User_Groups__c.getDescribe();
        List<Map<String,String>> ugList = new List<Map<String,String>>();
        for (Schema.PicklistEntry pe : ugField.getPicklistValues()) {
            if (pe.isActive()) {
                ugList.add(new Map<String,String>{
                    'label' => pe.getLabel(), 'value' => pe.getValue() });
            }
        }
        result.put('userGroups', ugList);

        // Case Stages — from FEC_Case_Stage__c or picklist on notification
        Schema.DescribeFieldResult stageField =
            FEC_Notification__c.FEC_Case_Stage__c.getDescribe();
        // FEC_Case_Stage__c is a Long Text Area; source from a custom metadata or picklist object
        // Adjust query below to match your actual Case Stage object/picklist
        List<Map<String,String>> stageList = new List<Map<String,String>>();
        for (FEC_Case_Stage__c cs : [SELECT Id, Name FROM FEC_Case_Stage__c ORDER BY Name]) {
            stageList.add(new Map<String,String>{ 'Id' => cs.Id, 'Name' => cs.Name });
        }
        result.put('caseStages', stageList);

        // Channels (FEC_Channel__c picklist on FEC_Notification__c)
        Schema.DescribeFieldResult chanField =
            FEC_Notification__c.FEC_Channel__c.getDescribe();
        List<Map<String,String>> chanList = new List<Map<String,String>>();
        // FEC_Channel__c is Text(255); populate from a related Channel object
        // or from a custom metadata — adjust as required
        for (FEC_Channel__c nc : [SELECT Id, Name FROM FEC_Channel__c ORDER BY Name]) {
            chanList.add(new Map<String,String>{ 'Id' => nc.Id, 'Name' => nc.Name });
        }
        result.put('channels', chanList);

        // Templates (with their channel mapping for client-side filtering)
        List<Map<String,String>> tplList = new List<Map<String,String>>();
        for (FEC_Template__c t : [
            SELECT Id, Name, FEC_API_Name__c, FEC_Active__c,
                   FEC_Is_ZNS_Template__c
            FROM FEC_Template__c
            WHERE FEC_Active__c = true
            ORDER BY Name
        ]) {
            // FEC_Applicable_for_Mailbox__c encodes which channel(s) a template belongs to
            tplList.add(new Map<String,String>{
                'Id'        => t.Id,
                'Name'      => t.Name,
                'isZNS'     => String.valueOf(t.FEC_Is_ZNS_Template__c).toLowerCase()
            });
        }
        result.put('templates', tplList);

        return result;
    }

    /**
     * Returns sub-categories that belong to the given productType Id and parent category.
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_Sub_Category__c> getSubCategories(Id productTypeId, Id categoryId) {
        return [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Sub_Category__c
            //WHERE Id IN :categoryId
            WHERE Id IN (SELECT FEC_Sub_Category__c FROM FEC_Nature_of_Case__c WHERE FEC_Sub_Category__c != NULL AND FEC_Product_Type__c = :productTypeId AND FEC_Category__c = :categoryId)
            ORDER BY Name
        ];
    }

    /**
     * Returns sub-codes that belong to any of the given productType Id, category Id and sub-category Ids.
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_Sub_Code__c> getSubCodes(Id productTypeId, Id categoryId, List<String> subCategoryIds) {
        return [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Sub_Code__c
            //WHERE FEC_SubCategory__c IN :subCategoryIds
            WHERE Id IN (
                SELECT FEC_Sub_Code__c FROM FEC_Nature_of_Case__c 
                WHERE FEC_Sub_Code__c != NULL 
                    AND FEC_Product_Type__c = :productTypeId 
                    AND FEC_Category__c = :categoryId 
                    AND (FEC_Sub_Category__c IN :subCategoryIds
                        OR FEC_Sub_Category__r.Name IN :subCategoryIds
                        OR FEC_Sub_Category__r.FEC_Code__c IN :subCategoryIds
                        )
                    )
            ORDER BY Name
        ];
    }

    // ─── Validation ────────────────────────────────────────────────────────

    /**
     * Returns true if a duplicate Name exists (excluding the
     * current record when editing).
     */
    @AuraEnabled(cacheable=false)
    public static Boolean checkDuplicateNotifType(String notifType, Id excludeId) {
        String queryStr =
            'SELECT COUNT() FROM FEC_Notification__c ' +
            'WHERE Name = :notifType';
        if (excludeId != null) {
            queryStr += ' AND Id != :excludeId';
        }
        return Database.countQuery(queryStr) > 0;
    }

    // ─── Save (Create / Update) ────────────────────────────────────────────

    /**
     * Saves (upserts) a FEC_Notification__c record and its
     * FEC_Notification_Template_Channel__c junction children.
     * All parameters are passed as a JSON string payload.
     */
    @AuraEnabled
    public static Id saveNotification(String payload) {
        Map<String, Object> data =
            (Map<String, Object>) JSON.deserializeUntyped(payload);

        // ── Build FEC_Notification__c ──
        /*FEC_Notification__c notif = new FEC_Notification__c();

        String recId = (String) data.get('recordId');
        if (String.isNotBlank(recId)) { notif.Id = recId; }*/

        // ── Existing record (for update) ──
        FEC_Notification__c notif;

        String recId = (String) data.get('recordId');
        if (String.isNotBlank(recId)) {
            notif = [
                SELECT Id, Name, RecordTypeId, FEC_Notification_Status__c,
                FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
                FROM FEC_Notification__c
                WHERE Id = :recId
                LIMIT 1
            ];
            // =========================
            // Status validation
            // true -> false
            // =========================
            Boolean oldStatus = notif.FEC_Notification_Status__c;
            Boolean newStatus = (Boolean) data.get('notificationStatus');
            if (oldStatus == true && newStatus == false) {
                validateCanDisableNotification(notif);
            }
        } else {
            notif = new FEC_Notification__c();
        }

        

        // ── RECORD TYPE ──
        if (notif.RecordTypeId == null) {

            String tabType = (String) data.get('tabType');

            String rtDeveloperName =
                (tabType == 'auto')
                    ? 'Auto_Notification'
                    : 'Manual_Notification';

            Schema.RecordTypeInfo rtInfo =
                Schema.SObjectType.FEC_Notification__c
                    .getRecordTypeInfosByDeveloperName()
                    .get(rtDeveloperName);

            if (rtInfo != null) {
                notif.RecordTypeId = rtInfo.getRecordTypeId();
            }
        }

        notif.Name          = (String) data.get('notificationType');
        notif.FEC_Target_Group__c           = (String) data.get('targetGroup');
        notif.FEC_Customer_Type__c          = (String) data.get('customerType');
        notif.FEC_Notification_Status__c    = (Boolean) data.get('notificationStatus');
        notif.FEC_Channel__c                = (String) data.get('channel');
        notif.FEC_Product_Type__c           = (Id)     data.get('productType');
        notif.FEC_Category__c               = (Id)     data.get('category');
        notif.FEC_SubCategory__c            = (String) data.get('subCategory');
        notif.FEC_SubCode__c                = (String) data.get('subCode');
        notif.FEC_Current_Status__c         = (String) data.get('currentStatus');
        notif.FEC_Changed_Status__c         = (String) data.get('changedStatus');
        notif.FEC_Assigned_to_Queue__c      = (String) data.get('assignedToQueue');
        notif.FEC_Receivers__c              = (String) data.get('receivers');
        notif.FEC_Applicable_User_Groups__c = (String) data.get('applicableUserGroups');
        notif.FEC_Case_Stage__c             = (String) data.get('caseStage');

        String startTime = (String) data.get('scheduleStartTime');
        String endTime   = (String) data.get('scheduleEndTime');
        if (String.isNotBlank(startTime)) {
            notif.FEC_Schedule_Start_Time__c = parseTime(startTime);
        }
        if (String.isNotBlank(endTime)) {
            notif.FEC_Schedule_End_Time__c   = parseTime(endTime);
        }

        // ── Duplicate check (belt-and-suspenders; Trigger also validates) ──
        /*Integer dupCount = [
            SELECT COUNT() FROM FEC_Notification__c
            WHERE Name = :notif.Name
            AND Id != :notif.Id
        ];
        if (dupCount > 0) {
            throw new AuraHandledException(
                'A Notification with Type "' + notif.Name + '" already exists.');
        }*/

        upsert notif;

        // ── Junction records: delete existing, re-insert ──
        if (String.isNotBlank(recId)) {
            delete [
                SELECT Id FROM FEC_Notification_Template_Channel__c
                WHERE FEC_Notification__c = :notif.Id
            ];
        }

        List<Object> lines =
            (List<Object>) JSON.deserializeUntyped((String) data.get('channelTemplateLines'));
        List<FEC_Notification_Template_Channel__c> junctions =
            new List<FEC_Notification_Template_Channel__c>();

        for (Object lineObj : lines) {
            Map<String, Object> line = (Map<String, Object>) lineObj;
            String channelId  = (String) line.get('channelId');
            String templateId = (String) line.get('templateId');
            if (String.isNotBlank(channelId) && String.isNotBlank(templateId)) {
                junctions.add(new FEC_Notification_Template_Channel__c(
                    FEC_Notification__c          = notif.Id,
                    FEC_Notification_Channel__c  = channelId,
                    FEC_Notification_Template__c = templateId
                ));
            }
        }
        if (!junctions.isEmpty()) { insert junctions; }

        return notif.Id;
    }

    // ─── Delete ────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void deleteNotification(Id notificationId) {
        FEC_Notification__c rec = [
            SELECT Id, Name FROM FEC_Notification__c
            WHERE Id = :notificationId LIMIT 1
        ];
        // Log deletion before record is removed
        //NotificationHistoryLogger.logDeletion(rec);
        delete rec;
    }

    // ─── Status Toggle ─────────────────────────────────────────────────────

    /**
     * Enables or disables a notification. Throws an error if the notification
     * is being disabled while mapped to an active Nature of Case.
     */
    @AuraEnabled
    public static void toggleNotificationStatus(Id notificationId, Boolean newStatus) {
        FEC_Notification__c rec = [
            SELECT Id, FEC_Notification_Status__c, Name,
                   FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
            FROM FEC_Notification__c
            WHERE Id = :notificationId LIMIT 1
        ];

        if (!newStatus) {
            validateCanDisableNotification(rec);
        }

        rec.FEC_Notification_Status__c = newStatus;
        update rec;
    }

    private static void validateCanDisableNotification(FEC_Notification__c rec) {
        Set<String> subCategories = String.isBlank(rec.FEC_SubCategory__c)
            ? new Set<String>()
            : new Set<String>(rec.FEC_SubCategory__c.split(','));

        Set<String> subCodes = String.isBlank(rec.FEC_SubCode__c)
            ? new Set<String>()
            : new Set<String>(rec.FEC_SubCode__c.split(','));

        // Local variables required — dynamic SOQL bind expressions
        // cannot reference record fields directly (e.g. :rec.FEC_Product_Type__c)
        String productType = rec.FEC_Product_Type__c;
        String category    = rec.FEC_Category__c;

        String query =
            'SELECT COUNT() FROM FEC_Nature_of_Case__c'
            + ' WHERE FEC_Product_Type__c = :productType'
            + '   AND FEC_Category__c = :category'
            + '   AND (FEC_Sub_Category__r.FEC_Code__c IN :subCategories'
            + '     OR FEC_Sub_Category__r.Id IN :subCategories)'
            + '   AND FEC_Active__c = true';

        if (!subCodes.isEmpty()) {
            query +=
                ' AND (FEC_Sub_Code__r.FEC_Code__c IN :subCodes'
                + '  OR FEC_Sub_Code__r.Id IN :subCodes)';
        }

        Integer activeCount = Database.countQuery(query);

        if (activeCount > 0) {
            throw new AuraHandledException(
                 String.format(
                    System.Label.FEC_Notification_Config_Disable_Warning,
                    new List<String>{ String.valueOf(activeCount) }
                )
            );
        }
    }

    // ─── Channel Status Update ─────────────────────────────────────────────

    @AuraEnabled
    public static void updateChannelStatus(Id channelId, Boolean newStatus) {
        FEC_Notification_Channel__c ch = [
            SELECT Id, FEC_Noti_Channel_Status__c
            FROM FEC_Notification_Channel__c
            WHERE Id = :channelId LIMIT 1
        ];
        ch.FEC_Noti_Channel_Status__c = newStatus;
        update ch;
    }

    // ─── History Logs ──────────────────────────────────────────────────────

    public class AuditFieldChangeDTO {

        @AuraEnabled
        public String fieldLabel;

        @AuraEnabled
        public String oldValue;

        @AuraEnabled
        public String newValue;
    }

    public class AuditTransactionDTO {

        @AuraEnabled
        public String id;

        @AuraEnabled
        public String action;

        @AuraEnabled
        public Datetime changedDate;

        @AuraEnabled
        public String changedBy;

        @AuraEnabled
        public Integer changeCount;

        @AuraEnabled
        public List<AuditFieldChangeDTO> changes =
            new List<AuditFieldChangeDTO>();
    }

    @AuraEnabled(cacheable=false)
    public static List<AuditTransactionDTO> getHistoryLogs(
        Id notificationId
    ) {

        List<FEC_Notification__History> histories = [
            SELECT
                CreatedDate,
                CreatedById,
                CreatedBy.Email,
                Field,
                DataType,
                OldValue,
                NewValue
            FROM FEC_Notification__History
            WHERE ParentId = :notificationId AND DataType != 'EntityId'
            ORDER BY CreatedDate DESC
        ];

        Map<String,String> fieldLabels =
            getFieldLabels();

        /*
         * Collect lookup ids
         */
        Set<Id> lookupIds = new Set<Id>();

        for(FEC_Notification__History h : histories){

            if(h.DataType == 'EntityId'){

                try{
                    if(h.OldValue != null){
                        lookupIds.add(
                            (Id)String.valueOf(h.OldValue)
                        );
                    }
                }catch(Exception ex){}

                try{
                    if(h.NewValue != null){
                        lookupIds.add(
                            (Id)String.valueOf(h.NewValue)
                        );
                    }
                }catch(Exception ex){}
            }
        }

        /*
         * Resolve lookup names
         */
        Map<Id,String> namesById =
            resolveNames(lookupIds);

        /*
         * Build transactions
         */
        Map<String,AuditTransactionDTO> grouped =
            new Map<String,AuditTransactionDTO>();

        for(FEC_Notification__History h : histories){

            String transactionKey =
                h.CreatedById +
                '_' +
                h.CreatedDate.formatGMT(
                    'yyyyMMddHHmmss'
                );

            if(!grouped.containsKey(transactionKey)){

                AuditTransactionDTO dto =
                    new AuditTransactionDTO();

                dto.id = transactionKey;
                dto.action = 'Updated';
                dto.changedDate = h.CreatedDate;
                dto.changedBy = h.CreatedBy.Email;
                dto.changeCount = 0;

                grouped.put(
                    transactionKey,
                    dto
                );
            }

            AuditTransactionDTO dto =
                grouped.get(transactionKey);

            if(
                h.Field != null &&
                h.Field.equalsIgnoreCase('created')
            ){
                dto.action = 'Created';
                continue;
            }

            AuditFieldChangeDTO change =
                new AuditFieldChangeDTO();

            String fieldApiName =
                h.Field == null
                ? ''
                : h.Field.toLowerCase();

            change.fieldLabel =
                fieldLabels.containsKey(fieldApiName)
                ? fieldLabels.get(fieldApiName)
                : h.Field;

            change.oldValue =
                formatHistoryValue(
                    h.Field,
                    h.DataType,
                    h.OldValue,
                    namesById
                );

            change.newValue =
                formatHistoryValue(
                    h.Field,
                    h.DataType,
                    h.NewValue,
                    namesById
                );

            dto.changes.add(change);
            dto.changeCount++;
        }

        List<AuditTransactionDTO> result =
            new List<AuditTransactionDTO>();

        result.addAll(grouped.values());

        result.sort(
            new AuditTransactionComparator()
        );

        return result;
    }

    /*
     * Resolve lookup names
     */
    private static Map<Id,String> resolveNames(
        Set<Id> ids
    ){

        Map<Id,String> result =
            new Map<Id,String>();

        for(Id recordId : ids){

            try{

                String objectName =
                    recordId.getSObjectType()
                        .getDescribe()
                        .getName();

                SObject record =
                    Database.query(
                        'SELECT Name FROM ' +
                        objectName +
                        ' WHERE Id = :recordId'
                    );

                result.put(
                    recordId,
                    (String)record.get('Name')
                );

            }catch(Exception ex){
                System.debug(ex.getMessage());
            }
        }

        return result;
    }

    /*
     * Convert history value
     */
    private static String formatHistoryValue(
        String fieldApiName,
        String dataType,
        Object value,
        Map<Id,String> namesById
    ){

        if(value == null){
            return '';
        }

        /*
         * Lookup fields
         */
        if(dataType == 'EntityId'){

            try{

                Id recordId =
                    (Id)String.valueOf(value);

                if(
                    namesById.containsKey(recordId)
                ){
                    return namesById.get(recordId);
                }

            }catch(Exception ex){}
        }

        String strValue =
            String.valueOf(value);

        /*
         * TimeOnly
         */
        if(dataType == 'TimeOnly'){
            return formatTime(strValue);
        }

        return strValue;
    }

    /*
     * 03:45:00.000Z
     * ->
     * 3:45 AM
     */
    private static String formatTime(String value){

        if(String.isBlank(value)){
            return '';
        }

        try{

            Integer hour =
                Integer.valueOf(
                    value.substring(0,2)
                );

            String minute =
                value.substring(3,5);

            String ampm =
                hour >= 12
                ? 'PM'
                : 'AM';

            Integer displayHour =
                Math.mod(hour,12);

            if(displayHour == 0){
                displayHour = 12;
            }

            return
                String.valueOf(displayHour)
                + ':'
                + minute
                + ' '
                + ampm;

        }catch(Exception ex){

            return value;
        }
    }

    /*
     * Field label map
     */
    private static Map<String,String> getFieldLabels(){

        Map<String,String> labels =
            new Map<String,String>();

        Map<String,Schema.SObjectField> fields = FEC_Notification__c.SObjectType.getDescribe().fields.getMap();

        for(String apiName : fields.keySet()){

            labels.put(
                apiName.toLowerCase(),
                fields.get(apiName)
                    .getDescribe()
                    .getLabel()
            );
        }

        return labels;
    }

    public class AuditTransactionComparator implements Comparator<AuditTransactionDTO>{

        public Integer compare(AuditTransactionDTO a, AuditTransactionDTO b){

            if(a.changedDate > b.changedDate){
                return -1;
            }

            if(a.changedDate < b.changedDate){
                return 1;
            }

            return 0;
        }
    }

    // ─── Excel Export ──────────────────────────────────────────────────────

    /**
     * Generates a base64-encoded Excel (.xlsx) file containing all notification
     * records for the given tab type ('auto' or 'manual').
     *
     * Uses a CSV-compatible approach since Apex cannot natively create .xlsx.
     * The file is base64-encoded and returned to the LWC for download.
     * For true xlsx output, use a Connected App / Heroku microservice with
     * Apache POI, or the ExcelJS npm library via Salesforce Functions.
     */
    @AuraEnabled(cacheable=false)
    public static String exportNotifications(String tabType) {
        List<FEC_Notification__c> recs = [
            SELECT Name,
                   FEC_Target_Group__c,
                   FEC_Channel__c,
                   FEC_Product_Type__r.Name,
                   FEC_Category__r.Name,
                   FEC_SubCategory__c,
                   FEC_SubCode__c,
                   FEC_Notification_Status__c,
                   FEC_Customer_Type__c,
                   FEC_Current_Status__c,
                   FEC_Changed_Status__c,
                   FEC_Assigned_to_Queue__c,
                   FEC_Applicable_User_Groups__c,
                   FEC_Case_Stage__c
            FROM FEC_Notification__c
            ORDER BY CreatedDate DESC
        ];

        // Build CSV content
        List<String> rows = new List<String>();

        // Header row
        rows.add(
            '"Notification Type","Target Group","Channel","Product Type",' +
            '"Category","Sub Category","Sub Code","Notification Status",' +
            '"Customer Type","Current Status","Changed Status",' +
            '"Assigned to Queue","Applicable User Groups","Case Stage"'
        );

        for (FEC_Notification__c r : recs) {
            rows.add(String.join(new List<String>{
                csvSafe(r.Name),
                csvSafe(r.FEC_Target_Group__c),
                csvSafe(r.FEC_Channel__c),
                csvSafe(r.FEC_Product_Type__r != null ? r.FEC_Product_Type__r.Name : ''),
                csvSafe(r.FEC_Category__r != null ? r.FEC_Category__r.Name : ''),
                csvSafe(r.FEC_SubCategory__c),
                csvSafe(r.FEC_SubCode__c),
                csvSafe(r.FEC_Notification_Status__c ? 'Active' : 'Inactive'),
                csvSafe(r.FEC_Customer_Type__c),
                csvSafe(r.FEC_Current_Status__c),
                csvSafe(r.FEC_Changed_Status__c),
                csvSafe(r.FEC_Assigned_to_Queue__c),
                csvSafe(r.FEC_Applicable_User_Groups__c),
                csvSafe(r.FEC_Case_Stage__c)
            }, ','));
        }

        String csvContent = String.join(rows, '\n');
        return EncodingUtil.base64Encode(Blob.valueOf(csvContent));
    }

    // ─── Helpers ───────────────────────────────────────────────────────────

    private static String csvSafe(String val) {
        if (val == null) return '""';
        return '"' + val.replaceAll('"', '""') + '"';
    }

    private static Time parseTime(String timeStr) {
        // Expects 'HH:mm' format from lightning-input[type=time]
        if (String.isBlank(timeStr)) return null;
        List<String> parts = timeStr.split(':');
        if (parts.size() < 2) return null;
        return Time.newInstance(
            Integer.valueOf(parts[0]),
            Integer.valueOf(parts[1]),
            0, 0
        );
    }
}