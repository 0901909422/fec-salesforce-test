// Tìm object chứa account/contract number
Id accContractId = 'a0IAz000001DP9hMAG';
String objType = accContractId.getSObjectType().getDescribe().getName();
System.debug('Object type: ' + objType);

// Query dynamic
String q = 'SELECT Id, Name FROM ' + objType + ' WHERE Id = :accContractId LIMIT 1';
List<SObject> recs = Database.query(q);
if (!recs.isEmpty()) {
    System.debug('Name: ' + recs[0].get('Name'));
    Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(objType).getDescribe().fields.getMap();
    for (String fn : fields.keySet()) {
        try {
            Object val = recs[0].get(fn);
            if (val != null) System.debug('  ' + fn + ' = ' + val);
        } catch(Exception e) {}
    }
}
