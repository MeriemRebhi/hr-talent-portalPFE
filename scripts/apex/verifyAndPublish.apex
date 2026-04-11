// Republish the Experience site to pick up the latest access changes
Site mySite = [SELECT Id, Name, Status FROM Site WHERE Name = 'Talan_Talent_Intelligence_RH2' LIMIT 1];
System.debug('Publishing site: ' + mySite.Name + ' (Status: ' + mySite.Status + ')');

// Verify the guest profile has access to the classes
Id guestProfileId = '00efj000008OTBdAAO';
List<PermissionSet> guestPS = [SELECT Id FROM PermissionSet WHERE ProfileId = :guestProfileId LIMIT 1];

List<ApexClass> classes = [SELECT Id, Name FROM ApexClass WHERE Name IN ('TechnicalInterviewController', 'TechnicalQuestionService')];
for (ApexClass c : classes) {
    List<SetupEntityAccess> acc = [SELECT Id FROM SetupEntityAccess WHERE ParentId = :guestPS[0].Id AND SetupEntityId = :c.Id];
    System.debug(c.Name + ': access entries = ' + acc.size());
}

// Also try the Apex class access from the perspective of the Guest user
User guestUser = [SELECT Id, Name, ProfileId FROM User WHERE Id = '005fj00000DMi8fAAD'];
System.debug('Guest User: ' + guestUser.Name + ' (ProfileId: ' + guestUser.ProfileId + ')');
