// Tạo FEC_Template__c test
FEC_Template__c tmpl = new FEC_Template__c();
tmpl.Name = 'Test Notification Template';
tmpl.FEC_Template_Name__c = 'Test Notification Template';
tmpl.FEC_Subject_Line__c = 'Case {{CaseNumber}} đã được chuyển đến queue của bạn';
tmpl.FEC_Body__c = '<p>Xin chào,</p><p>Case <b>{{CaseNumber}}</b> đã được route đến queue của bạn.</p><p>Vui lòng xử lý sớm.</p>';
tmpl.FEC_Active__c = true;
insert tmpl;
System.debug('Template created: ' + tmpl.Id);

// Gán template vào notification record TEST_EMAIL_NOTIF
FEC_Notification__c n = [SELECT Id FROM FEC_Notification__c WHERE Name = 'TEST_EMAIL_NOTIF' LIMIT 1];
n.FEC_Notification_Template__c = tmpl.Id;
update n;
System.debug('Notification updated with template: ' + n.Id);
