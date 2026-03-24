// Gọi trực tiếp getFromAddresses với case ID thực tế
String caseId = '5004z00001xxxxxxx'; // sẽ thay bằng case ID thực
// Lấy case ID gần nhất
Case c = [SELECT Id, CaseNumber FROM Case ORDER BY CreatedDate DESC LIMIT 1];
System.debug('Testing with Case: ' + c.CaseNumber + ' Id=' + c.Id);

Map<String, Object> result = FEC_CustomEmailService.getFromAddresses(c.Id);
List<Object> opts = (List<Object>) result.get('options');
String def = (String) result.get('defaultFrom');
System.debug('defaultFrom: ' + def);
System.debug('options count: ' + opts.size());
for (Object o : opts) {
    Map<String, Object> m = (Map<String, Object>) o;
    System.debug('  option: label=' + m.get('label') + ' value=' + m.get('value'));
}
