// Test tạo Email Interaction với subject rõ ràng
FEC_CreateInteractionGenesys.EmailGenesysRequest req = new FEC_CreateInteractionGenesys.EmailGenesysRequest();
req.fromEmail            = 'minhtung2108@gmail.com';
req.sendTo               = 'dichvukhachhang@fecredit.com.vn';
req.genesysInteractionID = 'GNS-TEST-' + String.valueOf(DateTime.now().getTime()).right(8);
req.phoneNum             = '0358193245';
req.nationalID           = '';
req.contractNum          = '';
req.cardAccountNum       = '';
req.agentID              = '';
req.subject              = 'Khiếu nại về lãi suất tháng 3/2026';

FEC_CreateInteractionGenesys.InteractionResult result = FEC_CreateInteractionGenesys.createEmailInteraction(req);

System.debug('isSuccess: ' + result.isSuccess);
System.debug('recordId: ' + result.recordId);
System.debug('message: ' + result.message);

// Verify subject và EmailMessage
if (result.isSuccess) {
    Case c = [SELECT Id, Subject FROM Case WHERE Id = :result.recordId];
    System.debug('Case Subject: ' + c.Subject);

    List<EmailMessage> msgs = [SELECT Subject, TextBody FROM EmailMessage WHERE ParentId = :result.recordId];
    System.debug('EmailMessage count: ' + msgs.size());
    if (!msgs.isEmpty()) {
        System.debug('EmailMessage Subject: ' + msgs[0].Subject);
        System.debug('EmailMessage TextBody: ' + msgs[0].TextBody);
    }
}
