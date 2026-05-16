Schema.DescribeFieldResult f = Schema.SObjectType.FEC_Nature_of_Case__c.fields.getMap().get('FEC_Channel__c').getDescribe();
System.debug('Type: ' + f.getType());
System.debug('Label: ' + f.getLabel());
List<Schema.sObjectType> refs = f.getReferenceTo();
for (Schema.sObjectType r : refs) System.debug('ReferenceTo: ' + r.getDescribe().getName());
