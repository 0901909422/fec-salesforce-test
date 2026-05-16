// tungnm37: test gọi API MarkNFU trực tiếp để xem raw response
// Thay caseId bằng case đang test (S-2612)
String caseId = 'YOUR_CASE_ID'; // TODO: thay bằng Id của S-2612

Case c = [
    SELECT Id, FEC_Account_Contract_Number_Text__c, FEC_SubCode__c,
           FEC_NFU_Status__c, FEC_NFU_Code__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
System.debug('Case ContractNumber: ' + c.FEC_Account_Contract_Number_Text__c);
System.debug('Case NFU Status: ' + c.FEC_NFU_Status__c);
System.debug('Case NFU Code: ' + c.FEC_NFU_Code__c);

String userEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Email;
System.debug('User Email: ' + userEmail);

FEC_MarkNFU.MarkNFURequest req = new FEC_MarkNFU.MarkNFURequest();
req.ContractNumber = c.FEC_Account_Contract_Number_Text__c;
req.NFUReasonCode  = 'CS_NFU_COMPLAINT30'; // NFU code từ UI
req.NFUUpdatedBy   = userEmail;

System.debug('Request: ' + JSON.serialize(req));

FEC_MarkNFU.MarkNFUResult result = FEC_MarkNFU.markNFU(req);
System.debug('Result code: ' + result.code);
System.debug('Result description: ' + result.description);
System.debug('Result success: ' + result.success);
System.debug('Result errorMessage: ' + result.errorMessage);
System.debug('Result httpStatus: ' + result.httpStatus);
System.debug('Result rawResponse: ' + result.rawResponse);
