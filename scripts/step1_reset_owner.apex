// Bước 1: Đổi owner về user trước
Case c = [SELECT Id, OwnerId FROM Case WHERE Id = '500Az00000M8FmqIAF'];
c.OwnerId = UserInfo.getUserId();
update c;
System.debug('Done - owner now: ' + UserInfo.getUserName());
