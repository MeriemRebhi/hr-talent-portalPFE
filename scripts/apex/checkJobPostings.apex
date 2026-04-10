List<Opportunity> jobPostings = [
    SELECT Id, Name, RecordType.DeveloperName, IsClosed
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting'
    ORDER BY CreatedDate DESC
];
System.debug('=== JOB_POSTING restantes: ' + jobPostings.size() + ' ===');
for (Opportunity o : jobPostings) {
    System.debug(o.Name + ' | Closed: ' + o.IsClosed);
}
