// Check xem đã có remote site cho sandbox file domain chưa
List<SetupEntityAccess> existing = [SELECT Id FROM SetupEntityAccess LIMIT 1];
System.debug('Note: Cannot create RemoteSiteSetting via Apex - must be done via UI or Metadata');

// Check org domain để biết URL cần add
Organization org = [SELECT Id, InstanceName, IsSandbox FROM Organization LIMIT 1];
System.debug('Org instance: ' + org.InstanceName + ' | IsSandbox: ' + org.IsSandbox);

// URL cần add vào Remote Site Settings
System.debug('Add this URL to Remote Site Settings:');
System.debug('https://fecredit123--fptsb03.sandbox.file.force.com');
