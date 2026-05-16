Schema.DescribeFieldResult u = FEC_Relevant_Ticket__c.FEC_User_Relevant__c.getDescribe();
Schema.DescribeFieldResult ur = FEC_Relevant_Ticket__c.FEC_User_Role_Relevant__c.getDescribe();
System.debug('User: type=' + u.getType() + ' calculated=' + u.isCalculated() + ' formula=' + u.getCalculatedFormula());
System.debug('UserRole: type=' + ur.getType() + ' calculated=' + ur.isCalculated() + ' formula=' + ur.getCalculatedFormula());
