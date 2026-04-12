// Full diagnostic for Ahmed
User ahmed = [SELECT Id, Username, ProfileId, Profile.Name, IsActive, 
              UserType, Profile.UserLicense.Name
              FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];

System.debug('═══ AHMED DIAGNOSTIC ═══');
System.debug('Id: ' + ahmed.Id);
System.debug('Username: ' + ahmed.Username);
System.debug('Profile: ' + ahmed.Profile.Name);
System.debug('License: ' + ahmed.Profile.UserLicense.Name);
System.debug('IsActive: ' + ahmed.IsActive);
System.debug('UserType: ' + ahmed.UserType);

// Check if HR talent app is assigned
List<SetupEntityAccess> appAccess = [
    SELECT SetupEntityId, SetupEntityType
    FROM SetupEntityAccess
    WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :ahmed.ProfileId)
    AND SetupEntityType = 'TabSet'
];
System.debug('App access count: ' + appAccess.size());

// Check Apex class access
Integer apexCount = [SELECT COUNT() FROM SetupEntityAccess 
    WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :ahmed.ProfileId)
    AND SetupEntityType = 'ApexClass'];
System.debug('Apex class access count: ' + apexCount);

// Check if he can query his own opp
List<Opportunity> hisJobs = [SELECT Id, Name FROM Opportunity 
    WHERE OwnerId = :ahmed.Id AND RecordType.DeveloperName = 'Job_Posting'];
System.debug('His Job Postings: ' + hisJobs.size());

List<Opportunity> hisApps = [SELECT Id, Name FROM Opportunity 
    WHERE OwnerId = :ahmed.Id AND RecordType.DeveloperName = 'Application'];
System.debug('His Applications: ' + hisApps.size());

// Simulate what getRecruteurData would return for Ahmed
System.debug('');
System.debug('═══ SIMULATING getRecruteurData for Ahmed ═══');
Id currentUserId = ahmed.Id; // simulate

List<Opportunity> myJobs = [
    SELECT Id FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting'
    AND OwnerId = :currentUserId
];
Set<Id> myJobIds = new Set<Id>();
for (Opportunity j : myJobs) myJobIds.add(j.Id);
System.debug('myJobIds: ' + myJobIds.size());

Set<Id> myOppIds = new Set<Id>();
if (!myJobIds.isEmpty()) {
    for (Lead l : [
        SELECT ConvertedOpportunityId, Description
        FROM Lead
        WHERE IsConverted = true AND ConvertedOpportunityId != null
        LIMIT 500
    ]) {
        if (l.Description == null) continue;
        for (Id jId : myJobIds) {
            if (l.Description.contains('JOB_ID:' + jId)) {
                myOppIds.add(l.ConvertedOpportunityId);
                break;
            }
        }
    }
}
for (Opportunity o : [
    SELECT Id FROM Opportunity
    WHERE RecordType.DeveloperName = 'Application'
    AND OwnerId = :currentUserId LIMIT 200
]) {
    myOppIds.add(o.Id);
}
System.debug('myOppIds (candidatures): ' + myOppIds.size());
