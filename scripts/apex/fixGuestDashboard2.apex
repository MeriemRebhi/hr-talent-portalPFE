// Just grant Guest access to InternalDashboardController
Profile guestProf = [SELECT Id FROM Profile WHERE Name = 'Talan Talent Intelligence RH2 Profile' LIMIT 1];
Id guestPSId = [SELECT Id FROM PermissionSet WHERE ProfileId = :guestProf.Id LIMIT 1].Id;

ApexClass idc = [SELECT Id FROM ApexClass WHERE Name = 'InternalDashboardController' LIMIT 1];

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

// Verify
Integer total = [SELECT COUNT() FROM SetupEntityAccess 
    WHERE ParentId = :guestPSId AND SetupEntityType = 'ApexClass'];
System.debug('Total Apex classes pour Guest: ' + total);
