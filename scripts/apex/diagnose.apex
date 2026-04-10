// Diagnostic complet des Leads récents
List<Lead> leads = [
    SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c, 
           IsConverted, CreatedDate, Description
    FROM Lead 
    WHERE Email = 'm.rebhi24292@pi.com'
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('Leads trouvés: ' + leads.size());
for (Lead l : leads) {
    System.debug('Lead: ' + l.Id + ' | ' + l.FirstName + ' ' + l.LastName 
        + ' | Status: ' + l.Status 
        + ' | Score: ' + l.Score_Matching__c 
        + ' | Converted: ' + l.IsConverted 
        + ' | Créé: ' + l.CreatedDate);
}

// Vérifier les Apex Jobs récents
List<AsyncApexJob> jobs = [
    SELECT Id, Status, ExtendedStatus, ApexClass.Name, CreatedDate, JobType
    FROM AsyncApexJob
    WHERE CreatedDate = TODAY
    ORDER BY CreatedDate DESC LIMIT 10
];
for (AsyncApexJob j : jobs) {
    System.debug('Job: ' + j.ApexClass.Name + ' | Type: ' + j.JobType 
        + ' | Status: ' + j.Status + ' | Err: ' + j.ExtendedStatus 
        + ' | ' + j.CreatedDate);
}
