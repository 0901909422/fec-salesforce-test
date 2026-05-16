Case c = [
    SELECT Id, CaseNumber, Subject, Status,
           FEC_Product_Type__r.Name,
           FEC_Category__r.Name, FEC_SubCategory__r.Name,
           FEC_Business_Process__r.FEC_Code__c,
           Owner.Name, CreatedDate
    FROM Case WHERE Id = '500Az00000MI8iQIAT' LIMIT 1
];
System.debug('CaseNumber: ' + c.CaseNumber);
System.debug('Subject: ' + c.Subject);
System.debug('Status: ' + c.Status);
System.debug('ProductType: ' + c.FEC_Product_Type__r?.Name);
System.debug('Category: ' + c.FEC_Category__r?.Name);
System.debug('BP: ' + c.FEC_Business_Process__r?.FEC_Code__c);
System.debug('Owner: ' + c.Owner?.Name);
