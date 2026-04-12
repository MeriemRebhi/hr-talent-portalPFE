// Republish the Experience Cloud site
Site site = [SELECT Id, Name, Status FROM Site WHERE Name = 'Talan_Talent_Intelligence_RH2' LIMIT 1];
System.debug('Site: ' + site.Name + ' - Status: ' + site.Status);

// Check network membership for Ahmed
User ahmed = [SELECT Id, Profile.Name FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev'];
System.debug('Ahmed profile: ' + ahmed.Profile.Name);

// Check all active networks
for(Network n : [SELECT Id, Name, Status, UrlPathPrefix FROM Network WHERE Status = 'Live']) {
    System.debug('Network: ' + n.Name + ' | Prefix: ' + n.UrlPathPrefix + ' | Status: ' + n.Status);
}

// Check if Guest User profile was updated with new Apex accesses
Profile guestProf = [SELECT Id, Name FROM Profile WHERE Name LIKE '%Talan%RH2%' LIMIT 1];
System.debug('Guest Profile: ' + guestProf.Name + ' | Id: ' + guestProf.Id);

Integer guestApex = [SELECT COUNT() FROM SetupEntityAccess 
    WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :guestProf.Id)
    AND SetupEntityType = 'ApexClass'];
System.debug('Guest Apex class access: ' + guestApex);

// Get the specific Apex classes the guest user has access to
List<SetupEntityAccess> guestAccess = [
    SELECT SetupEntityId 
    FROM SetupEntityAccess 
    WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :guestProf.Id)
    AND SetupEntityType = 'ApexClass'
];
Set<Id> classIds = new Set<Id>();
for(SetupEntityAccess sea : guestAccess) classIds.add(sea.SetupEntityId);
for(ApexClass cls : [SELECT Name FROM ApexClass WHERE Id IN :classIds]) {
    System.debug('Guest has access to: ' + cls.Name);
}
