// tungnm37: check Sub-Code options cho bộ NOC đang test
// Thay các ID bằng giá trị thực từ case đang test
String caseId = 'YOUR_CASE_ID'; // TODO: thay

Case c = [SELECT Id, FEC_Customer_Type__c FROM Case WHERE Id = :caseId LIMIT 1];
User u = [SELECT Id, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

System.debug('Case CustomerType: ' + c.FEC_Customer_Type__c);
System.debug('User Group: ' + u.FEC_User_Group__c);

// Lấy tất cả Sub-Category CC05 (Thông tin tín dụng)
List<FEC_Sub_Category__c> subCats = [
    SELECT Id, Name FROM FEC_Sub_Category__c WHERE Name LIKE '%CC05%' OR Name LIKE '%Thông tin tín dụng%' LIMIT 5
];
System.debug('SubCategories: ' + subCats);

if (!subCats.isEmpty()) {
    Id subCatId = subCats[0].Id;
    
    // Lấy tất cả NOC có Sub-Code với Sub-Category này
    List<FEC_Nature_of_Case__c> nocs = [
        SELECT Id, FEC_Sub_Code__c, FEC_Sub_Code__r.Name, FEC_Customer_Type__c, FEC_User_Group__c
        FROM FEC_Nature_of_Case__c
        WHERE FEC_Sub_Category__c = :subCatId
          AND FEC_Sub_Code__c != null
        LIMIT 20
    ];
    System.debug('NOCs with SubCode for CC05: ' + nocs.size());
    for (FEC_Nature_of_Case__c n : nocs) {
        System.debug('  SubCode Id: ' + n.FEC_Sub_Code__c + ' | Name: ' + n.FEC_Sub_Code__r?.Name + 
            ' | CustomerType: ' + n.FEC_Customer_Type__c + ' | UserGroup: ' + n.FEC_User_Group__c);
    }
    
    // Check filter theo CustomerType và UserGroup
    List<String> customerTypelst = new List<String>{'All', c.FEC_Customer_Type__c};
    List<FEC_Nature_of_Case__c> filtered = [
        SELECT FEC_Sub_Code__c, FEC_Sub_Code__r.Name
        FROM FEC_Nature_of_Case__c
        WHERE FEC_User_Group__c INCLUDES (:u.FEC_User_Group__c)
          AND FEC_Customer_Type__c != NULL
          AND FEC_Customer_Type__c IN :customerTypelst
          AND FEC_Sub_Category__c = :subCatId
          AND FEC_Sub_Code__c != NULL
        LIMIT 20
    ];
    System.debug('Filtered NOCs (after UserGroup+CustomerType): ' + filtered.size());
    for (FEC_Nature_of_Case__c n : filtered) {
        System.debug('  SubCode: ' + n.FEC_Sub_Code__r?.Name + ' | Id: ' + n.FEC_Sub_Code__c);
    }
}
