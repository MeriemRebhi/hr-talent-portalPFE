// Diagnostic : voir tous les enregistrements qui passent dans getJobPostings
List<Opportunity> all = [
    SELECT Id, Name, Is_Candidature__c, RecordType.DeveloperName, StageName, IsClosed
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting'
    AND (Is_Candidature__c = false OR Is_Candidature__c = null)
    ORDER BY Name
    LIMIT 30
];
System.debug('Total returned: ' + all.size());
for (Opportunity o : all) {
    System.debug(o.Name + ' | Is_Candidature__c: ' + o.Is_Candidature__c + ' | Stage: ' + o.StageName + ' | Closed: ' + o.IsClosed);
}

// Corriger les faux positifs : ceux dont le nom contient "Candidature" ou un score (%)
List<Opportunity> toFix = [
    SELECT Id, Name
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting'
    AND (Is_Candidature__c = false OR Is_Candidature__c = null)
    AND (Name LIKE '%Candidature%' OR Name LIKE '% (%%)' OR Name LIKE '%E2E%' OR Name LIKE '%Fix%' OR Name LIKE '%Test%' OR Name LIKE '%test%')
];
System.debug('Records to fix: ' + toFix.size());
for (Opportunity o : toFix) System.debug('Fixing: ' + o.Name);

if (!toFix.isEmpty()) {
    for (Opportunity o : toFix) o.Is_Candidature__c = true;
    update toFix;
    System.debug('Fixed ' + toFix.size() + ' records.');
}
