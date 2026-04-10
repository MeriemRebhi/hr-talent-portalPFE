// Diagnostic complet
System.debug('=== DIAGNOSTIC START ===');

// 1. Tous les Leads non convertis recents
List<Lead> unconverted = [SELECT Id, FirstName, LastName, Email, Score_Matching__c, Status, IsConverted, CreatedDate 
                          FROM Lead WHERE IsConverted = false ORDER BY CreatedDate DESC LIMIT 10];
System.debug('Leads non convertis: ' + unconverted.size());
for (Lead l : unconverted) {
    System.debug('  ' + l.Id + ' | ' + l.FirstName + ' ' + l.LastName + ' | ' + l.Email + ' | Score:' + l.Score_Matching__c + ' | ' + l.Status + ' | Created:' + l.CreatedDate);
}

// 2. Dernier Lead converti
List<Lead> converted = [SELECT Id, FirstName, LastName, Email, Score_Matching__c, Status, IsConverted, ConvertedContactId, ConvertedOpportunityId, ConvertedAccountId 
                        FROM Lead WHERE IsConverted = true ORDER BY CreatedDate DESC LIMIT 3];
System.debug('Derniers Leads convertis: ' + converted.size());
for (Lead l : converted) {
    System.debug('  ' + l.Id + ' | ' + l.FirstName + ' ' + l.LastName + ' | Contact:' + l.ConvertedContactId + ' | Opp:' + l.ConvertedOpportunityId);
}

// 3. Opportunities recentes
List<Opportunity> opps = [SELECT Id, Name, StageName, Score_Matching__c, CreatedDate FROM Opportunity ORDER BY CreatedDate DESC LIMIT 5];
System.debug('Opportunities recentes: ' + opps.size());
for (Opportunity o : opps) {
    System.debug('  ' + o.Id + ' | ' + o.Name + ' | Stage:' + o.StageName + ' | Score:' + o.Score_Matching__c);
}

// 4. Async jobs recents
List<AsyncApexJob> jobs = [SELECT Id, ApexClass.Name, Status, ExtendedStatus, CreatedDate FROM AsyncApexJob WHERE CreatedDate = TODAY ORDER BY CreatedDate DESC LIMIT 10];
System.debug('Async jobs today: ' + jobs.size());
for (AsyncApexJob j : jobs) {
    System.debug('  ' + j.ApexClass.Name + ' | ' + j.Status + ' | ' + j.ExtendedStatus + ' | ' + j.CreatedDate);
}

System.debug('=== DIAGNOSTIC END ===');
