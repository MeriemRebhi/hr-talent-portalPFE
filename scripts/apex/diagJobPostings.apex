// Diagnostic sans Is_Candidature__c — voir tous les opportunités avec Job_Posting RecordType
List<Opportunity> all = [
    SELECT Id, Name, RecordType.DeveloperName, StageName, IsClosed, CloseDate
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting'
    ORDER BY Name
    LIMIT 30
];
System.debug('Total Job_Posting records: ' + all.size());
for (Opportunity o : all) {
    System.debug(o.Name + ' | Stage: ' + o.StageName + ' | Closed: ' + o.IsClosed);
}
