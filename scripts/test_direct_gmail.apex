// Test gửi email trực tiếp đến Gmail không qua trigger
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new String[]{ 'tungnm.mpc@gmail.com', 'tungnm37@fpt.com' });
mail.setSubject('Direct test from Apex - ' + DateTime.now().format());
mail.setHtmlBody('<p>Test email trực tiếp từ Apex anonymous</p>');
Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
System.debug('Sent direct test email to Gmail');
