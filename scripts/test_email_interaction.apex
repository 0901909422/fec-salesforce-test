// Giả lập Genesys gọi createEmailInteraction - luồng dichvukhachhang@fecredit.com.vn
FEC_CreateInteractionGenesys.EmailGenesysRequest req = new FEC_CreateInteractionGenesys.EmailGenesysRequest();
req.fromEmail            = 'minhtung2108@gmail.com';       // email KH gửi đến
req.sendTo               = 'dichvukhachhang@fecredit.com.vn'; // mailbox FEC nhận
req.genesysInteractionID = 'GNS-' + String.valueOf(DateTime.now().getTime()).right(10);
req.phoneNum             = '0358193245';
req.nationalID           = '';
req.contractNum          = '';
req.cardAccountNum       = '';
req.agentID              = ''; // để trống nếu chưa có agentID thật
req.subject              = 'Yêu cầu hỗ trợ từ khách hàng - Test ' + DateTime.now().format('dd/MM/yyyy HH:mm');

FEC_CreateInteractionGenesys.InteractionResult result = FEC_CreateInteractionGenesys.createEmailInteraction(req);

System.debug('=== KẾT QUẢ ===');
System.debug('isSuccess: ' + result.isSuccess);
System.debug('message: ' + result.message);
System.debug('recordId: ' + result.recordId);
if (result.response != null) {
    System.debug('response.genesysInteractionID: ' + result.response.genesysInteractionID);
    System.debug('response.type: ' + result.response.type);
    System.debug('response.phoneNumber: ' + result.response.phoneNumber);
}
