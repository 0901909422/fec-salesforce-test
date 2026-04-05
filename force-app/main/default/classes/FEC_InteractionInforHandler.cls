public without sharing class FEC_InteractionInforHandler {
    @AuraEnabled(cacheable=true)
    public static Case getInteraction(Id recordId) {
        List<Case> caseList = [
        SELECT FEC_Interaction_Masked_Phone__c,
               FEC_Channel__c,
               FEC_Interaction_Subchannel__c,
               FEC_Created_On__c,
               FEC_Created_by__c,
               FEC_External_Interaction_ID__c,
               FEC_Last_Updated_On__c,
               FEC_Last_Updated_By__c,
               FEC_Outcome_Code__c,
               FEC_Interaction_Remarks__c,
               FEC_Interaction_Email__c,
               FEC_Send_To__c,
               FEC_On_Hold__c,
               ParentId,
               FEC_Parent_ID__c,
               Parent.FEC_ID_Search__c,
               IsClosed,
               FEC_Interaction_Status__c,
               Origin
        FROM Case
        WHERE Id = :recordId
    ];
        
        return caseList.isEmpty() ? null : caseList[0];
    }
    
    @AuraEnabled
    public static String getInteractionPhoneReveal(Id recordId) {
        
        Case c = [
        SELECT Id, FEC_Phone_Number__c, FEC_Interaction_ID__c
        FROM Case
        WHERE Id = :recordId
        LIMIT 1
    ];
        
        User u = [
        SELECT Username, UserRole.Name
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];
        
        
        // 🔐 Audit sensitive access
        FEC_CommonUltils.logSensitiveAccess(
            FEC_ConstantCommon.SECTION_INTERACTION_DETAILS,
        FEC_ConstantCommon.SECTION_INTERACTION_PHONE,
        u.Username.split('@')[0],
        u.UserRole != null ? u.UserRole.Name : null,
        c.Id
            );
        
        return c.FEC_Phone_Number__c;
    }
    
    
    @AuraEnabled
    public static String updateInteractionPhone(Id recordId, String phone) {
        
        if (!FEC_CommonUltils.isPhone(phone)) {
            throw new AuraHandledException(System.Label.FEC_MSG_Phone_Number_Invalid);
        }
        
        update new Case(
            Id = recordId,
        FEC_Phone_Number__c = phone
            );
        
        return FEC_CommonUltils.maskPhone(phone);
    }

    @AuraEnabled(cacheable=false)
    public static void updateInteractionEmail(Id recordId, String email) {
        if (recordId == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Record_Id_Invalid);
        }
        update new Case(
            Id = recordId,
            FEC_Interaction_Email__c = String.isNotBlank(email) ? email.trim() : null
        );
    }
    
    @AuraEnabled(cacheable=false)
    public static void updateInteractionOnHold(Id recordId, Boolean onHold) {
        if (recordId == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Record_Id_Invalid);
        }
        update new Case(
            Id = recordId,
            FEC_On_Hold__c = onHold
        );
    }
    
    @AuraEnabled(cacheable=true)
    public static Id getInteractionIdFromCustomerCase(Id caseId) {
        Case c = [
        SELECT FEC_Interaction__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
        return c.FEC_Interaction__c;
    }
    
    @AuraEnabled(cacheable=true)
    public static Case getInteractionHighlightData(Id recordId) {
        List<Case> caseList = [
        SELECT FEC_Interaction_ID__c,
               FEC_Interaction_Status__c,
               FEC_Last_Updated_On__c,
               FEC_Last_Updated_By__c,
               FEC_Channel__c,
               FEC_Interaction_Subchannel__c
        FROM Case
        WHERE Id = :recordId
    ];
        
        return caseList.isEmpty() ? null : caseList[0];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Case> getRelevantInteractions(Id recordId) {
        
        // Lấy Interaction hiện tại
        Case currentInteraction = getCurrentInteraction(recordId);
        System.debug('Current Interaction: ' + currentInteraction);
        if (currentInteraction == null) {
            return new List<Case>();
        }
        
        // TÁCH BIẾN – BẮT BUỘC
        String phone = currentInteraction.FEC_Phone_Number__c;
        String email = currentInteraction.FEC_Interaction_Email__c;
        DateTime closeDt = currentInteraction.ClosedDate;
        // Nếu không có Phone & Email → không search
        if (String.isBlank(phone) && String.isBlank(email)) {
            return new List<Case>();
        }
        
        // Build điều kiện match Phone / Email
        List<String> matchConditions = new List<String>();
        
        if (String.isNotBlank(phone)) {
            matchConditions.add('FEC_Phone_Number__c = :phone');
        }
        if (String.isNotBlank(email)) {
            matchConditions.add('FEC_Interaction_Email__c = :email');
        }
        
        DateTime archiveThreshold;
        if (closeDt != null) {
            archiveThreshold = DateTime.now().addMonths(-3);
        }
        
        // =====================================================
        // 5. BUILD WHERE CONDITIONS (DYNAMIC)
        // =====================================================
        List<String> whereConditions = new List<String>();
        whereConditions.add('RecordType.DeveloperName = \'' + FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME + '\'');
        whereConditions.add('Id != :recordId');
        whereConditions.add('(' + String.join(matchConditions, ' OR ') + ')');
        
        if (archiveThreshold != null) {
            whereConditions.add('ClosedDate >= :archiveThreshold');
        }
        
        // SOQL cuối cùng
        String soql =
            'SELECT Id, ' +
            '       FEC_Interaction_ID__c,FEC_Interaction_Status__c, ' +
            '       FEC_Channel__c, ' +
            '       FEC_Created_On__c,FEC_Created_by__c ' +
            'FROM Case ' +
            'WHERE ' + String.join(whereConditions, ' AND ') + ' ' +
            'ORDER BY FEC_Created_On__c DESC '+
            'LIMIT 5';
        System.debug('SOQL: ' + soql);
        return Database.query(soql);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Case> getRelevantInteractionsViewAll(Id recordId) {
        
        // Lấy Interaction hiện tại
        Case currentInteraction = getCurrentInteraction(recordId);
        System.debug('Current Interaction: ' + currentInteraction);
        if (currentInteraction == null) {
            return new List<Case>();
        }
        
        // TÁCH BIẾN – BẮT BUỘC
        String phone = currentInteraction.FEC_Phone_Number__c;
        String email = currentInteraction.FEC_Interaction_Email__c;
        DateTime closeDt = currentInteraction.ClosedDate;
        // Nếu không có Phone & Email → không search
        if (String.isBlank(phone) && String.isBlank(email)) {
            return new List<Case>();
        }
        
        // Build điều kiện match Phone / Email
        List<String> matchConditions = new List<String>();
        
        if (String.isNotBlank(phone)) {
            matchConditions.add('FEC_Phone_Number__c = :phone');
        }
        if (String.isNotBlank(email)) {
            matchConditions.add('FEC_Interaction_Email__c = :email');
        }
        
        DateTime archiveThreshold;
        if (closeDt != null) {
            archiveThreshold = DateTime.now().addMonths(-3);
        }
        
        // =====================================================
        // 5. BUILD WHERE CONDITIONS (DYNAMIC)
        // =====================================================
        List<String> whereConditions = new List<String>();
        whereConditions.add('RecordType.DeveloperName = \'' + FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME + '\'');
        whereConditions.add('Id != :recordId');
        whereConditions.add('(' + String.join(matchConditions, ' OR ') + ')');
        
        if (archiveThreshold != null) {
            whereConditions.add('ClosedDate >= :archiveThreshold');
        }
        
        // SOQL cuối cùng
        String soql =
            'SELECT Id, ' +
            '       FEC_Interaction_ID__c,FEC_Interaction_Status__c, ' +
            '       FEC_Channel__c, ' +
            '       FEC_Created_On__c,FEC_Created_by__c ' +
            'FROM Case ' +
            'WHERE ' + String.join(whereConditions, ' AND ') + ' ' +
            'ORDER BY FEC_Created_On__c DESC ';
        System.debug('SOQL: ' + soql);
        return Database.query(soql);
    }
    
    
    @AuraEnabled(cacheable=true)
    public static Integer getRelevantInteractionsViewAllCount(Id recordId) {
        
        // Lấy Interaction hiện tại
        Case currentInteraction = getCurrentInteraction(recordId);
        if (currentInteraction == null) {
            return 0;
        }
        
        // TÁCH BIẾN – BẮT BUỘC
        String phone = currentInteraction.FEC_Phone_Number__c;
        String email = currentInteraction.FEC_Interaction_Email__c;
        DateTime closeDt = currentInteraction.ClosedDate;
        // Nếu không có Phone & Email → không search
        if (String.isBlank(phone) && String.isBlank(email)) {
            return 0;
        }
        
        // Build điều kiện match Phone / Email
        List<String> matchConditions = new List<String>();
        
        if (String.isNotBlank(phone)) {
            matchConditions.add('FEC_Phone_Number__c = :phone');
        }
        if (String.isNotBlank(email)) {
            matchConditions.add('FEC_Interaction_Email__c = :email');
        }
        
        DateTime archiveThreshold;
        if (closeDt != null) {
            archiveThreshold = DateTime.now().addMonths(-3);
        }
        
        // =====================================================
        // 5. BUILD WHERE CONDITIONS (DYNAMIC)
        // =====================================================
        List<String> whereConditions = new List<String>();
        whereConditions.add('RecordType.DeveloperName = \'' + FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME + '\'');
        whereConditions.add('Id != :recordId');
        whereConditions.add('(' + String.join(matchConditions, ' OR ') + ')');
        
        if (archiveThreshold != null) {
            whereConditions.add('ClosedDate >= :archiveThreshold');
        }
        
        
        
        // SOQL COUNT
        String soql =
            'SELECT COUNT() ' +
            'FROM Case ' +
            'WHERE ' + String.join(whereConditions, ' AND ') + ' ';
        
        System.debug('SOQL COUNT: ' + soql);
        
        return Database.countQuery(soql);
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Case> getCaseList(Id recordId) {
        try {
            List<Case> caseList = [SELECT Id,
                                       FEC_Case_ID__c,
                                       FEC_Case_Status__c,
                                       FEC_SubCategory__c,
                                       FEC_SubCategory__r.FEC_Code__c,
                                       FEC_SubCategory__r.FEC_Name_VN__c,
                                       FEC_SubCode__c,
                                       FEC_SubCode__r.FEC_Code__c,
                                       FEC_SubCode__r.FEC_Name_VN__c
                                FROM Case
                                WHERE FEC_Interaction__c = :recordId
                                ORDER BY FEC_Case_Created_On__c DESC
                                LIMIT 5];
            return caseList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Integer getCaseTotal(Id recordId) {
        try {
            Integer totalCases = [
            SELECT COUNT()
            FROM Case
            WHERE FEC_Interaction__c = :recordId
        ];
            return totalCases;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Case> getCaseListViewAll(Id recordId) {
        try {
            List<Case> caseList = [SELECT Id,
                                       FEC_Case_ID__c,
                                       FEC_Case_Status__c,
                                       FEC_SubCategory__c,
                                       FEC_SubCategory__r.FEC_Code__c,
                                       FEC_SubCategory__r.FEC_Name_VN__c,
                                       FEC_SubCode__c,
                                       FEC_SubCode__r.FEC_Code__c,
                                       FEC_SubCode__r.FEC_Name_VN__c,
                                       FEC_Account_or_Contract__r.FEC_Account_Number__c,
                                       FEC_Case_Created_By__c,
                                       FEC_Case_Created_On__c
                                FROM Case
                                WHERE FEC_Interaction__c = :recordId
                                ORDER BY FEC_Case_Created_On__c DESC
                                ];
            return caseList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Case> getRelevantCases(Id recordId) {
        
        // =====================================================
        // 1. LẤY INTERACTION HIỆN TẠI
        // =====================================================
        Case currentInteraction = getCurrentInteraction(recordId);
        if (currentInteraction == null) {
            return new List<Case>();
        }
        
        // =====================================================
        // 2. TÁCH BIẾN – RÕ NGHĨA
        // =====================================================
        String phone     = currentInteraction.FEC_Phone_Number__c;
        String email     = currentInteraction.FEC_Interaction_Email__c;
        DateTime closeDt = currentInteraction.ClosedDate;
        
        // Không có Phone & Email → không search
        if (String.isBlank(phone) && String.isBlank(email)) {
            return new List<Case>();
        }
        
        // =====================================================
        // 3. BUILD MATCH CONDITIONS (PHONE / EMAIL)
        // =====================================================
        List<String> matchConditions = new List<String>();
        
        if (String.isNotBlank(phone)) {
            matchConditions.add('FEC_Interaction__r.FEC_Phone_Number__c = :phone');
        }
        if (String.isNotBlank(email)) {
            matchConditions.add('FEC_Interaction__r.FEC_Interaction_Email__c = :email');
        }
        
        // =====================================================
        // 4. ARCHIVE THRESHOLD (CHỈ KHI INTERACTION ĐÃ CLOSED)
        // =====================================================
        DateTime archiveThreshold;
        if (closeDt != null) {
            archiveThreshold = DateTime.now().addMonths(-3);
        }
        
        // =====================================================
        // 5. BUILD WHERE CONDITIONS (DYNAMIC)
        // =====================================================
        List<String> whereConditions = new List<String>();
        whereConditions.add('RecordType.DeveloperName != \'' + FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME + '\'');
        whereConditions.add('Id != :recordId');
        whereConditions.add('(' + String.join(matchConditions, ' OR ') + ')');
        
        if (archiveThreshold != null) {
            whereConditions.add('ClosedDate >= :archiveThreshold');
        }
        
        // =====================================================
        // 6. FINAL SOQL
        // =====================================================
        String soql =
            'SELECT ' +
            '   Id, ' +
            '   FEC_Case_ID__c, ' +
            '   FEC_Case_Status__c, ' +
            '   FEC_SubCategory__c, ' +
            '   FEC_SubCategory__r.FEC_Code__c, ' +
            '   FEC_SubCategory__r.FEC_Name_VN__c, ' +
            '   FEC_SubCode__c, ' +
            '   FEC_SubCode__r.FEC_Code__c, ' +
            '   FEC_SubCode__r.FEC_Name_VN__c, FEC_Account_or_Contract__r.FEC_Account_Number__c ' +
            'FROM Case ' +
            'WHERE ' + String.join(whereConditions, ' AND ') + ' ' +
            'ORDER BY FEC_Case_Created_On__c DESC ' +
            'LIMIT 5';
        
        // =====================================================
        // 7. EXECUTE
        // =====================================================
        return Database.query(soql);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Case> getRelevantCasesViewAll(Id recordId) {
        
        // =====================================================
        // 1. LẤY INTERACTION HIỆN TẠI
        // =====================================================
        Case currentInteraction = getCurrentInteraction(recordId);
        if (currentInteraction == null) {
            return new List<Case>();
        }
        
        // =====================================================
        // 2. TÁCH BIẾN – RÕ NGHĨA
        // =====================================================
        String phone     = currentInteraction.FEC_Phone_Number__c;
        String email     = currentInteraction.FEC_Interaction_Email__c;
        DateTime closeDt = currentInteraction.ClosedDate;
        
        // Không có Phone & Email → không search
        if (String.isBlank(phone) && String.isBlank(email)) {
            return new List<Case>();
        }
        
        // =====================================================
        // 3. BUILD MATCH CONDITIONS (PHONE / EMAIL)
        // =====================================================
        List<String> matchConditions = new List<String>();
        
        if (String.isNotBlank(phone)) {
            matchConditions.add('FEC_Interaction__r.FEC_Phone_Number__c = :phone');
        }
        if (String.isNotBlank(email)) {
            matchConditions.add('FEC_Interaction__r.FEC_Interaction_Email__c = :email');
        }
        
        // =====================================================
        // 4. ARCHIVE THRESHOLD (CHỈ KHI INTERACTION ĐÃ CLOSED)
        // =====================================================
        DateTime archiveThreshold;
        if (closeDt != null) {
            archiveThreshold = DateTime.now().addMonths(-3);
        }
        
        // =====================================================
        // 5. BUILD WHERE CONDITIONS (DYNAMIC)
        // =====================================================
        List<String> whereConditions = new List<String>();
        whereConditions.add('RecordType.DeveloperName != \'' + FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME + '\'');
        whereConditions.add('Id != :recordId');
        whereConditions.add('(' + String.join(matchConditions, ' OR ') + ')');
        
        if (archiveThreshold != null) {
            whereConditions.add('ClosedDate >= :archiveThreshold');
        }
        
        // =====================================================
        // 6. FINAL SOQL
        // =====================================================
        String soql =
            'SELECT ' +
            '   Id, ' +
            '   FEC_Case_ID__c, ' +
            '   FEC_Case_Status__c, ' +
            '   FEC_SubCategory__c, ' +
            '   FEC_SubCategory__r.FEC_Code__c, ' +
            '   FEC_SubCategory__r.FEC_Name_VN__c, ' +
            '   FEC_SubCode__c, ' +
            '   FEC_SubCode__r.FEC_Code__c, FEC_Account_or_Contract__r.FEC_Account_Number__c,' +
            '   FEC_SubCode__r.FEC_Name_VN__c , FEC_Case_Created_On__c,FEC_Case_Created_By__c ' +
            'FROM Case ' +
            'WHERE ' + String.join(whereConditions, ' AND ') + ' ' +
            'ORDER BY FEC_Case_Created_On__c DESC' ;
        
        // =====================================================
        // 7. EXECUTE
        // =====================================================
        return Database.query(soql);
    }
    
    
    @AuraEnabled(cacheable=true)
    public static Integer getRelevantCasesViewAllCount(Id recordId) {
        
        // =====================================================
        // 1. LẤY INTERACTION HIỆN TẠI
        // =====================================================
        Case currentInteraction = getCurrentInteraction(recordId);
        if (currentInteraction == null) {
            return 0;
        }
        
        // =====================================================
        // 2. TÁCH BIẾN – RÕ NGHĨA
        // =====================================================
        String phone     = currentInteraction.FEC_Phone_Number__c;
        String email     = currentInteraction.FEC_Interaction_Email__c;
        DateTime closeDt = currentInteraction.ClosedDate;
        
        // Không có Phone & Email → không search
        if (String.isBlank(phone) && String.isBlank(email)) {
            return 0;
        }
        
        // =====================================================
        // 3. BUILD MATCH CONDITIONS (PHONE / EMAIL)
        // =====================================================
        List<String> matchConditions = new List<String>();
        
        if (String.isNotBlank(phone)) {
            matchConditions.add('FEC_Interaction__r.FEC_Phone_Number__c = :phone');
        }
        if (String.isNotBlank(email)) {
            matchConditions.add('FEC_Interaction__r.FEC_Interaction_Email__c = :email');
        }
        
        // =====================================================
        // 4. ARCHIVE THRESHOLD (CHỈ KHI INTERACTION ĐÃ CLOSED)
        // =====================================================
        DateTime archiveThreshold;
        if (closeDt != null) {
            archiveThreshold = DateTime.now().addMonths(-3);
        }
        
        // =====================================================
        // 5. BUILD WHERE CONDITIONS (DYNAMIC)
        // =====================================================
        List<String> whereConditions = new List<String>();
        whereConditions.add('RecordType.DeveloperName != \'' + FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME + '\'');
        whereConditions.add('Id != :recordId');
        whereConditions.add('(' + String.join(matchConditions, ' OR ') + ')');
        
        if (archiveThreshold != null) {
            whereConditions.add('ClosedDate >= :archiveThreshold');
        }
        
        // =====================================================
        // 6. FINAL SOQL
        // =====================================================
        String soql =
            'SELECT COUNT()' +
            'FROM Case ' +
            'WHERE ' + String.join(whereConditions, ' AND ') ;
        
        // =====================================================
        // 7. EXECUTE
        // =====================================================
        return Database.countQuery(soql);
    }
    
    
    @AuraEnabled(cacheable=true)
    public static Case getCurrentInteraction(Id recordId) {
        return [
        SELECT FEC_Phone_Number__c,
               FEC_Interaction_Email__c,
               FEC_On_Hold__c,
               IsClosed,  FEC_Channel__c,
               ClosedDate
        FROM Case
        WHERE Id = :recordId
        LIMIT 1
    ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_Sensitive_Data__c> getSensitiveData(Id recordId) {
        try {
            List<FEC_Sensitive_Data__c> sensitiveDataList = [
                SELECT FEC_Case_ID__c, 
                       FEC_Section__c, 
                       Name, 
                       FEC_User__c, 
                       FEC_User_Role__c, 
                       CreatedDate 
                FROM FEC_Sensitive_Data__c
                WHERE FEC_Related_Case__c = :recordId
                ORDER BY CreatedDate DESC
                LIMIT 5
               
            ];
            return sensitiveDataList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_Sensitive_Data__c> getSensitiveDataViewAll(Id recordId, Integer pageSize, Integer pageNumber) {
        try {
            
            if (pageSize == null || pageSize <= 0) pageSize = 10;
            if (pageNumber == null || pageNumber < 1) pageNumber = 1;
            
            Integer offsetSize = (pageNumber - 1) * pageSize;
            
            List<FEC_Sensitive_Data__c> sensitiveDataList = [
                SELECT ID, FEC_Case_ID__c, 
                       FEC_Section__c, 
                       Name, 
                       FEC_User__c, 
                       FEC_User_Role__c, 
                       CreatedDate 
                FROM FEC_Sensitive_Data__c
                WHERE FEC_Related_Case__c = :recordId
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetSize
               
            ];
            return sensitiveDataList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Integer countSensitiveData(Id recordId) {
        return [
        SELECT COUNT()
        FROM FEC_Sensitive_Data__c
        WHERE FEC_Related_Case__c = :recordId
    ];
    }
    
    @AuraEnabled
    public static String resetViewMode(Id recordId, String viewMode) {
        if (recordId == null) return null;

        List<Case> caselst = [
            SELECT
                Id,
                RecordType.DeveloperName,
                FEC_First_Access__c,
                FEC_Interaction_View_Mode__c,
                FEC_Get_Next_Work__c,
                FEC_Is_Created_From_Search__c
            FROM Case
            WHERE Id = :recordId
        ];

        if (caselst.isEmpty())
            return null;

        Case c = caselst.get(0);
        if (c.FEC_Get_Next_Work__c == true) {
            viewMode = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
        } else if (c.FEC_First_Access__c == true) {
            viewMode = c.FEC_Interaction_View_Mode__c;
        }
        
        update new Case(
            Id = recordId,
            FEC_Interaction_View_Mode__c = viewMode,
            FEC_First_Access__c = false,
            FEC_Get_Next_Work__c = false
            //FEC_Is_Created_From_Search__c = false
        );
        return viewMode;
    }
    
    @AuraEnabled
    public static String getRecordTypeName(Id recordId) {
        if (recordId == null) return '';
        List<Case> caseList = [
            SELECT Id, RecordType.DeveloperName  FROM Case WHERE Id = :recordId
         ] ;
        
        string recordTypeName = caseList.isEmpty() ? null : caseList[0].RecordType.DeveloperName;
        return recordTypeName;
    }

    @AuraEnabled
    public static String getParentCaseNumber(Id caseId) {
        List<Case> caseList = [SELECT ParentId FROM Case WHERE Id = :caseId LIMIT 1];
        if (caseList.isEmpty() || caseList[0].ParentId == null) return null;
        List<Case> parentList = [SELECT FEC_ID_Search__c FROM Case WHERE Id = :caseList[0].ParentId LIMIT 1];
        if (parentList.isEmpty()) return null;
        return String.isNotBlank(parentList[0].FEC_ID_Search__c) ? parentList[0].FEC_ID_Search__c : null;
    }
}