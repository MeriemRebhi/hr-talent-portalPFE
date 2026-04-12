// Test getJobPostings and getRecruteurData as if running as Ahmed
// (Note: this runs as admin but shows the logic)
User ahmed = [SELECT Id FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];

// Check what Ahmed owns
List<Opportunity> ahmedJobs = [
    SELECT Id, Name, RecordType.DeveloperName, OwnerId
    FROM Opportunity
    WHERE OwnerId = :ahmed.Id
    AND RecordType.DeveloperName = 'Job_Posting'
];
System.debug('Ahmed Job Postings: ' + ahmedJobs.size());
for (Opportunity j : ahmedJobs) {
    System.debug('  Job: ' + j.Name + ' | RT: ' + j.RecordType.DeveloperName);
}

List<Opportunity> ahmedApps = [
    SELECT Id, Name, RecordType.DeveloperName, OwnerId
    FROM Opportunity
    WHERE OwnerId = :ahmed.Id
    AND RecordType.DeveloperName = 'Application'
];
System.debug('Ahmed Applications: ' + ahmedApps.size());
for (Opportunity a : ahmedApps) {
    System.debug('  App: ' + a.Name);
}

// Check if Record Types are available
Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
for (String key : rtMap.keySet()) {
    System.debug('RT: ' + key + ' | Available: ' + rtMap.get(key).isAvailable());
}
