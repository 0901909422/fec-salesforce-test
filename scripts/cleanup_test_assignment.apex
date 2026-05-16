// tungnm37: Xóa Assignment test vừa tạo trên case 00001272
List<FEC_Assignment__c> toDelete = [
    SELECT Id FROM FEC_Assignment__c
    WHERE FEC_Case__c = '500Az00000MI8iQIAT'
      AND FEC_Assignment_Remark__c = 'Test Loan remark'
      AND CreatedDate = TODAY
];
System.debug('Deleting ' + toDelete.size() + ' test assignments');
if (!toDelete.isEmpty()) delete toDelete;
