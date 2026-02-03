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
               FEC_Last_Updated_By__c
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
            'Interaction Details',
        'Interaction Phone',
        u.Username.split('@')[0],
        u.UserRole != null ? u.UserRole.Name : null,
        c.Id
            );
        
        // FEC_Sensitive_Data__c sensitiveData = new FEC_Sensitive_Data__c(
        //     FEC_Section__c = 'Interaction Details',
        // Name = 'Interaction Phone',
        // FEC_User__c = u.Username.split('@')[0],
        // FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null,
        // FEC_Related_Case__c = c.Id
        //     );
        // insert sensitiveData;
        
        return c.FEC_Phone_Number__c;
    }
    
    
    @AuraEnabled
    public static String  updateInteractionPhone(Id recordId, String phone) {
        Case c = new Case(
            Id = recordId,
        FEC_Phone_Number__c = phone
            );
        update c;
        
        // return masked phone
        return maskPhone(phone);
    }
    
    
    private static String maskPhone(String phone) {
        if (String.isBlank(phone)) {
            return phone;
        }
        
        Integer len = phone.length();
        
        // Nếu quá ngắn thì không mask
        if (len <= 7) {
            return phone;
        }
        
        return phone.substring(0, 4)
            + '***'
            + phone.substring(len - 3);
    }
    
    @AuraEnabled(cacheable=true)
    public static Case getInteractionHighlightData(Id recordId) {
        List<Case> caseList = [
        SELECT FEC_Interaction_ID__c,
               FEC_Interaction_Status__c,
               FEC_Last_Updated_On__c,
               FEC_Last_Updated_By__c
               
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
        whereConditions.add('RecordType.DeveloperName = \'Interaction\'');
        whereConditions.add('Id != :recordId');
        whereConditions.add('(' + String.join(matchConditions, ' OR ') + ')');
        
        if (archiveThreshold != null) {
            whereConditions.add('FEC_Interaction_End_On__c  >= :archiveThreshold');
        }
        
        
        // SOQL cuối cùng
        String soql =
            'SELECT Id, ' +
            '       FEC_Interaction_ID__c, ' +
            '       FEC_Channel__c, ' +
            '       FEC_Created_On__c ' +
            'FROM Case ' +
            'WHERE ' + String.join(whereConditions, ' AND ') + ' ' +
            'ORDER BY FEC_Last_Updated_On__c DESC ' +
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
        whereConditions.add('RecordType.DeveloperName = \'Interaction\'');
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
            'ORDER BY FEC_Last_Updated_On__c DESC ';
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
        whereConditions.add('RecordType.DeveloperName = \'Interaction\'');
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
        whereConditions.add('RecordType.DeveloperName != \'Interaction\'');
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
            '   FEC_SubCode__r.FEC_Name_VN__c ' +
            'FROM Case ' +
            'WHERE ' + String.join(whereConditions, ' AND ') + ' ' +
            'ORDER BY FEC_Last_Updated_On__c DESC ' +
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
        whereConditions.add('RecordType.DeveloperName != \'Interaction\'');
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
            '   FEC_SubCode__r.FEC_Name_VN__c ' +
            'FROM Case ' +
            'WHERE ' + String.join(whereConditions, ' AND ') + ' ' +
            'ORDER BY FEC_Last_Updated_On__c DESC' ;
        
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
        whereConditions.add('RecordType.DeveloperName != \'Interaction\'');
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
    
    @AuraEnabled
    public static void resetViewMode(Id recordId, String viewMode) {
        if (recordId == null) return;
        
        update new Case(
            Id = recordId,
        FEC_Interaction_View_Mode__c = viewMode
            );
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
}