// Debug: kiểm tra resolveToNatureOfCaseId logic
// Chạy script này để xác nhận FEC_Actual_Nature_of_Case__c → FEC_Nature_of_Case__c mapping

// Lấy case đang test
String caseId = '500Az00000OLe6HIAT'; // thay bằng case ID thực tế

Case c = [SELECT Id, FEC_Actual_Nature_of_Case__c, FEC_Business_Process__c FROM Case WHERE Id = :caseId LIMIT 1];
System.debug('Case FEC_Actual_Nature_of_Case__c = ' + c.FEC_Actual_Nature_of_Case__c);

if (c.FEC_Actual_Nature_of_Case__c != null) {
    Id actualNocId = c.FEC_Actual_Nature_of_Case__c;
    String objName = actualNocId.getSObjectType().getDescribe().getName();
    System.debug('Object type of FEC_Actual_Nature_of_Case__c ID = ' + objName);
    
    // Nếu là FEC_Actual_Nature_of_Case__c, tìm FEC_Nature_of_Case__c tương ứng
    if (objName == 'FEC_Actual_Nature_of_Case__c') {
        FEC_Actual_Nature_of_Case__c an = [
            SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
            FROM FEC_Actual_Nature_of_Case__c WHERE Id = :actualNocId LIMIT 1
        ];
        System.debug('Actual NOC: BP=' + an.FEC_Business_Process__c + ' Cat=' + an.FEC_Category__c + ' SubCat=' + an.FEC_Sub_Category__c + ' SubCode=' + an.FEC_Sub_Code__c);
        
        List<FEC_Nature_of_Case__c> matchNocs = [
            SELECT Id, FEC_Active__c FROM FEC_Nature_of_Case__c
            WHERE FEC_Business_Process__c = :an.FEC_Business_Process__c
              AND FEC_Category__c = :an.FEC_Category__c
              AND FEC_Sub_Category__c = :an.FEC_Sub_Category__c
              AND FEC_Sub_Code__c = :an.FEC_Sub_Code__c
        ];
        System.debug('Matching FEC_Nature_of_Case__c count = ' + matchNocs.size());
        for (FEC_Nature_of_Case__c n : matchNocs) {
            System.debug('  NOC Id=' + n.Id + ' Active=' + n.FEC_Active__c);
            
            // Check FEC_Routing_Assignment__c
            List<FEC_Routing_Assignment__c> ras = [
                SELECT FEC_Team__c, FEC_Queue__c FROM FEC_Routing_Assignment__c
                WHERE FEC_Nature_of_Cases__c = :n.Id
            ];
            System.debug('  Routing Assignments for this NOC: ' + ras.size());
            for (FEC_Routing_Assignment__c ra : ras) {
                System.debug('    Team=' + ra.FEC_Team__c + ' Queue=' + ra.FEC_Queue__c);
            }
        }
    }
}
