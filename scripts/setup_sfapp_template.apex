// Tạo template cho SF App notification
FEC_Template__c tmpl = new FEC_Template__c();
tmpl.Name = 'Test SF App Template';
tmpl.FEC_Template_Name__c = 'Test SF App Template';
tmpl.FEC_Subject_Line__c = 'Case {{CaseNumber}} được chuyển đến queue';
tmpl.FEC_Body__c = 'Case {{CaseNumber}} đã được route đến queue của bạn. Vui lòng xử lý.';
tmpl.FEC_Active__c = true;
insert tmpl;

FEC_Notification__c n = [SELECT Id FROM FEC_Notification__c WHERE Name = 'TEST_SFAPP_NOTIF' LIMIT 1];
n.FEC_Notification_Template__c = tmpl.Id;
update n;
System.debug('Done: ' + n.Id);
