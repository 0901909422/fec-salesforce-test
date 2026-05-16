Schema.DescribeSObjectResult d = FEC_Customer_History__c.getSObjectType().getDescribe();
for (Schema.SObjectField f : d.fields.getMap().values()) {
    String n = f.getDescribe().getName();
    if (n.containsIgnoreCase('Email') || n.containsIgnoreCase('Interaction')) {
        System.debug(n + ' | ' + f.getDescribe().getLabel());
    }
}
