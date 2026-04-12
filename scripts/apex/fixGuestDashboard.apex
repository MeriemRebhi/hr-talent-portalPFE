// Grant InternalDashboardController access to Guest User profile
Profile guestProf = [SELECT Id FROM Profile WHERE Name = 'Talan Talent Intelligence RH2 Profile' LIMIT 1];
Id guestPSId = [SELECT Id FROM PermissionSet WHERE ProfileId = :guestProf.Id LIMIT 1].Id;

ApexClass idc = [SELECT Id FROM ApexClass WHERE Name = 'InternalDashboardController' LIMIT 1];

// Check if already exists
List<SetupEntityAccess> existing = [
    SELECT Id FROM SetupEntityAccess 
    WHERE ParentId = :guestPSId AND SetupEntityId = :idc.Id
];

if (existing.isEmpty()) {
    insert new SetupEntityAccess(
        ParentId = guestPSId,
        SetupEntityId = idc.Id
    );
    System.debug('✅ InternalDashboardController ajouté au profil Guest');
} else {
    System.debug('⚠️ Déjà présent');
}

// Republish via Site.publish
SiteDetail sd = [SELECT DurableId FROM SiteDetail WHERE DurableId != null LIMIT 1];
System.debug('Site published - refresh manually via Setup > Sites');
