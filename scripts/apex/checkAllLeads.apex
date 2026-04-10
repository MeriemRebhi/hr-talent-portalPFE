// Check ALL leads with their emails
List<Lead> leads = [SELECT Id, FirstName, LastName, Email, IsConverted, ConvertedOpportunityId FROM Lead ORDER BY CreatedDate DESC LIMIT 20];
System.debug('=== ALL LEADS ===');
for (Lead l : leads) {
    System.debug('Lead: ' + l.FirstName + ' ' + l.LastName + ' | Email: ' + l.Email + ' | Converted: ' + l.IsConverted);
}
