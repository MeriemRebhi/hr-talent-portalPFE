// Tous les Leads créés récemment (pas que cet email)
List<Lead> leads = [
    SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c, 
           IsConverted, CreatedDate
    FROM Lead 
    ORDER BY CreatedDate DESC LIMIT 10
];
System.debug('=== 10 derniers Leads ===');
for (Lead l : leads) {
    System.debug(l.CreatedDate + ' | ' + l.FirstName + ' ' + l.LastName 
        + ' | ' + l.Email 
        + ' | Status: ' + l.Status 
        + ' | Score: ' + l.Score_Matching__c 
        + ' | Conv: ' + l.IsConverted);
}
