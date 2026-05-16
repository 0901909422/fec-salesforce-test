// Fix: Cập nhật FEC_Assigned_to_Queue__c từ Queue Id cũ sang DeveloperName
// để match đúng với Queue trong org hiện tại

// Lấy tất cả Queue hiện tại trong org
Map<String, String> idToDevName = new Map<String, String>();
Map<String, String> idShortToDevName = new Map<String, String>();
for (Group g : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue']) {
    idToDevName.put(String.valueOf(g.Id), g.DeveloperName);
    idShortToDevName.put(String.valueOf(g.Id).substring(0, 15), g.DeveloperName);
}

System.debug('Queues in org: ' + idToDevName);

// Lấy tất cả Notification records có FEC_Assigned_to_Queue__c là Queue Id (bắt đầu bằng 00G)
List<FEC_Notification__c> notifsToFix = [
    SELECT Id, Name, FEC_Assigned_to_Queue__c
    FROM FEC_Notification__c
    WHERE FEC_Assigned_to_Queue__c != null
];

List<FEC_Notification__c> toUpdate = new List<FEC_Notification__c>();

for (FEC_Notification__c n : notifsToFix) {
    String val = n.FEC_Assigned_to_Queue__c.trim();
    
    // Nếu đang lưu dạng Queue Id (18 char)
    if (idToDevName.containsKey(val)) {
        System.debug('Fix [' + n.Name + ']: ' + val + ' → ' + idToDevName.get(val));
        n.FEC_Assigned_to_Queue__c = idToDevName.get(val);
        toUpdate.add(n);
    }
    // Nếu đang lưu dạng Queue Id (15 char)
    else if (idShortToDevName.containsKey(val)) {
        System.debug('Fix [' + n.Name + ']: ' + val + ' → ' + idShortToDevName.get(val));
        n.FEC_Assigned_to_Queue__c = idShortToDevName.get(val);
        toUpdate.add(n);
    }
    // Nếu là Queue Id nhưng không tìm thấy trong org hiện tại (Id của org khác)
    else if (val.startsWith('00G') && val.length() >= 15) {
        System.debug('WARNING [' + n.Name + ']: Queue Id [' + val + '] không tồn tại trong org này!');
        System.debug('  → Cần update thủ công FEC_Assigned_to_Queue__c sang DeveloperName đúng');
    }
    else {
        System.debug('OK [' + n.Name + ']: đang dùng DeveloperName [' + val + ']');
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' notification records.');
} else {
    System.debug('Không có record nào cần fix tự động.');
    System.debug('Nếu vẫn không match, kiểm tra DeveloperName trong FEC_Assigned_to_Queue__c có đúng không.');
}
