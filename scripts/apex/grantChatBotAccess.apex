// Grant Apex class access — bulkified (no SOQL in loops)

List<String> classNames = new List<String>{
    'CandidateChatController',
    'AgentGetCandidatureStatus',
    'AgentGetAnalyseIA',
    'AgentGetOffresDisponibles'
};

// 1 — Get Apex classes
List<ApexClass> classes = [SELECT Id, Name FROM ApexClass WHERE Name IN :classNames];
System.debug('Classes found: ' + classes.size());

// 2 — Get all relevant profiles (community + guest + named)
List<Profile> profiles = [
    SELECT Id, Name FROM Profile
    WHERE UserType IN ('PowerPartner', 'PowerCustomerSuccess', 'CspLitePortal', 'Guest')
       OR Name LIKE '%Talan%' OR Name LIKE '%Talent%'
       OR Name LIKE '%Community%' OR Name LIKE '%Experience%'
];
System.debug('Profiles found: ' + profiles.size());

Set<Id> profileIds = new Set<Id>();
for (Profile p : profiles) profileIds.add(p.Id);

// 3 — Get PermissionSets for those profiles (1 SOQL)
List<PermissionSet> psSets = [
    SELECT Id, ProfileId FROM PermissionSet
    WHERE ProfileId IN :profileIds AND IsOwnedByProfile = true
];
Set<Id> psIds = new Set<Id>();
for (PermissionSet ps : psSets) psIds.add(ps.Id);
System.debug('PermissionSets found: ' + psSets.size());

// 4 — Get class IDs
Set<Id> classIds = new Set<Id>();
for (ApexClass c : classes) classIds.add(c.Id);

// 5 — Get already-existing grants (1 SOQL)
Set<String> existing = new Set<String>();
for (SetupEntityAccess sea : [
    SELECT SetupEntityId, ParentId FROM SetupEntityAccess
    WHERE SetupEntityId IN :classIds AND ParentId IN :psIds
]) {
    existing.add(sea.ParentId + '_' + sea.SetupEntityId);
}

// 6 — Build list to insert
List<SetupEntityAccess> toInsert = new List<SetupEntityAccess>();
for (PermissionSet ps : psSets) {
    for (ApexClass cls : classes) {
        String key = ps.Id + '_' + cls.Id;
        if (!existing.contains(key)) {
            SetupEntityAccess sea = new SetupEntityAccess();
            sea.ParentId = ps.Id;
            sea.SetupEntityId = cls.Id;
            toInsert.add(sea);
        }
    }
}

System.debug('Inserting ' + toInsert.size() + ' grants...');
if (!toInsert.isEmpty()) {
    Database.SaveResult[] results = Database.insert(toInsert, false);
    for (Database.SaveResult sr : results) {
        if (!sr.isSuccess()) System.debug('Error: ' + sr.getErrors()[0].getMessage());
    }
}
System.debug('Done.');
