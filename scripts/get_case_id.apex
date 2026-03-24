// Lấy danh sách case gần nhất để lấy Id test
List<Case> cases = [
    SELECT Id, CaseNumber, Subject, Status
    FROM Case
    ORDER BY CreatedDate DESC
    LIMIT 5
];
for (Case c : cases) {
    System.debug('Id: ' + c.Id + ' | #' + c.CaseNumber + ' | ' + c.Subject + ' | ' + c.Status);
}
