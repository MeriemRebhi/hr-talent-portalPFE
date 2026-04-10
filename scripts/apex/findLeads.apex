List<Lead> allLeads = [SELECT Id, Email, FirstName, LastName, Score_Matching__c, IsConverted, Status FROM Lead WHERE Email = 'm.rebhi24292@pi.tn' ORDER BY CreatedDate DESC];
System.debug('Total leads with this email: ' + allLeads.size());
for (Lead l : allLeads) {
    System.debug('Lead: ' + l.Id + ' | ' + l.FirstName + ' ' + l.LastName + ' | Score: ' + l.Score_Matching__c + ' | Status: ' + l.Status + ' | Converted: ' + l.IsConverted);
}
