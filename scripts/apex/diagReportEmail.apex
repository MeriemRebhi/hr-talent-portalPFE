// Diagnostic: pourquoi le rapport ATS n'est pas envoyé après le gaming test
// Exécuter dans: Dev Console > Execute Anonymous

// 1. Trouver les Opportunities avec Gaming complété
List<Opportunity> opps = [
    SELECT Id, Name, StageName, Gaming_Test_Score__c, Gaming_Test_Status__c, AccountId
    FROM Opportunity
    WHERE Gaming_Test_Status__c = 'Completed'
    ORDER BY LastModifiedDate DESC
    LIMIT 5
];
System.debug('=== Opps Gaming Completed: ' + opps.size());

for (Opportunity opp : opps) {
    System.debug('--- Opp: ' + opp.Name + ' | Score: ' + opp.Gaming_Test_Score__c + ' | Stage: ' + opp.StageName);

    // Check Lead email
    List<Lead> leads = [
        SELECT FirstName, LastName, Email FROM Lead
        WHERE ConvertedOpportunityId = :opp.Id AND IsConverted = true LIMIT 1
    ];
    String leadEmail = (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) ? leads[0].Email : 'NONE';
    System.debug('  Lead Email: ' + leadEmail);

    // Check OCR email
    List<OpportunityContactRole> ocrs = [
        SELECT Contact.Email FROM OpportunityContactRole
        WHERE OpportunityId = :opp.Id AND Contact.Email != null LIMIT 1
    ];
    String ocrEmail = !ocrs.isEmpty() ? ocrs[0].Contact.Email : 'NONE';
    System.debug('  OCR Email: ' + ocrEmail);

    // Check Contact email via Account
    String contactEmail = 'NONE';
    if (opp.AccountId != null) {
        List<Contact> contacts = [
            SELECT Email FROM Contact WHERE AccountId = :opp.AccountId AND Email != null LIMIT 1
        ];
        contactEmail = !contacts.isEmpty() ? contacts[0].Email : 'NONE';
    }
    System.debug('  Contact Email: ' + contactEmail);

    if (leadEmail == 'NONE' && ocrEmail == 'NONE' && contactEmail == 'NONE') {
        System.debug('  *** PROBLEME: Aucun email trouvé ! Le rapport ne sera jamais envoyé.');
    }
}

// 2. Check Email Deliverability
Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
System.debug('=== Is Sandbox: ' + org.IsSandbox);
System.debug('=== Vérifiez Setup > Email > Deliverability > Access level = "All Email"');
