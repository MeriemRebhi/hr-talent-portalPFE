// Diagnostic : vérifier les RecordTypes des Opportunités affichées dans l'onglet Offres
List<Opportunity> offres = [
    SELECT Id, Name, StageName, RecordType.DeveloperName, RecordType.Name, IsClosed, CreatedDate
    FROM Opportunity
    WHERE Name LIKE '%kemil%' OR Name LIKE '%fatma%' OR Name LIKE '%Candidature%'
    ORDER BY CreatedDate DESC
    LIMIT 20
];
System.debug('=== OPPORTUNITÉS CANDIDATURE ===');
for (Opportunity o : offres) {
    System.debug('Name: ' + o.Name 
        + ' | RT Dev: ' + o.RecordType.DeveloperName 
        + ' | RT Name: ' + o.RecordType.Name
        + ' | Stage: ' + o.StageName
        + ' | IsClosed: ' + o.IsClosed);
}

// Aussi vérifier toutes les offres Job_Posting
List<Opportunity> jobPostings = [
    SELECT Id, Name, StageName, RecordType.DeveloperName, RecordType.Name, IsClosed
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting'
    ORDER BY CreatedDate DESC
    LIMIT 20
];
System.debug('=== TOUTES LES JOB_POSTING ===');
for (Opportunity o : jobPostings) {
    System.debug('Name: ' + o.Name 
        + ' | RT Dev: ' + o.RecordType.DeveloperName
        + ' | Stage: ' + o.StageName
        + ' | IsClosed: ' + o.IsClosed);
}
