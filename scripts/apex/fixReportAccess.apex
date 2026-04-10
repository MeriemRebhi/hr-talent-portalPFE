// Fix: Grant Community user profile access to GamingTestReport VF page + GamingTestReportController
// This is required for the ATS report PDF to be generated when the candidate submits the gaming test
// Run in: Dev Console > Execute Anonymous

// 1. Find the Community profile
List<Profile> profiles = [
    SELECT Id, Name FROM Profile
    WHERE Name LIKE '%Customer Community%' OR Name LIKE '%Community%' OR Name LIKE '%Portal%'
];
System.debug('=== Community Profiles found:');
for (Profile p : profiles) {
    System.debug('  ' + p.Name + ' (' + p.Id + ')');
}

// 2. Get the VF page
List<ApexPage> pages = [SELECT Id, Name FROM ApexPage WHERE Name = 'GamingTestReport' LIMIT 1];
if (pages.isEmpty()) {
    System.debug('ERROR: GamingTestReport VF page not found! Deploy it first.');
} else {
    System.debug('VF Page: ' + pages[0].Name + ' (' + pages[0].Id + ')');
}

// 3. Get the Apex classes
List<ApexClass> classes = [
    SELECT Id, Name FROM ApexClass
    WHERE Name IN ('GamingTestReportController', 'GamingTestController')
];
System.debug('=== Apex Classes:');
for (ApexClass c : classes) {
    System.debug('  ' + c.Name + ' (' + c.Id + ')');
}

// 4. Grant access for each Community profile
for (Profile p : profiles) {
    // Grant VF page access
    if (!pages.isEmpty()) {
        List<SetupEntityAccess> existing = [
            SELECT Id FROM SetupEntityAccess
            WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :p.Id)
            AND SetupEntityId = :pages[0].Id
        ];
        if (existing.isEmpty()) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE ProfileId = :p.Id AND IsOwnedByProfile = true LIMIT 1];
            insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = pages[0].Id, SetupEntityType = 'ApexPage');
            System.debug('GRANTED VF page access to: ' + p.Name);
        } else {
            System.debug('VF page access already exists for: ' + p.Name);
        }
    }

    // Grant Apex class access
    for (ApexClass c : classes) {
        List<SetupEntityAccess> existing = [
            SELECT Id FROM SetupEntityAccess
            WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :p.Id)
            AND SetupEntityId = :c.Id
        ];
        if (existing.isEmpty()) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE ProfileId = :p.Id AND IsOwnedByProfile = true LIMIT 1];
            insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = c.Id, SetupEntityType = 'ApexClass');
            System.debug('GRANTED ' + c.Name + ' access to: ' + p.Name);
        } else {
            System.debug(c.Name + ' access already exists for: ' + p.Name);
        }
    }
}

// 5. Check Email Deliverability
System.debug('=== IMPORTANT: Verify Setup > Email > Deliverability > Access level = "All Email"');

// 6. Check recent Apex Job failures (the @future errors)
List<AsyncApexJob> jobs = [
    SELECT Id, Status, ExtendedStatus, ApexClass.Name, CreatedDate
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'GamingTestReportController'
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== Recent @future jobs for GamingTestReportController:');
for (AsyncApexJob j : jobs) {
    System.debug('  ' + j.CreatedDate + ' | Status: ' + j.Status + ' | Error: ' + j.ExtendedStatus);
}
if (jobs.isEmpty()) {
    System.debug('  No @future jobs found — sendReportAsync may not be called at all');
}
