// Find Marioumti and check/fix email
for (Opportunity o : [SELECT Id, Name, AccountId FROM Opportunity WHERE Name LIKE '%Marioumti%' LIMIT 5]) {
    System.debug('=== OPP: ' + o.Id + ' | ' + o.Name + ' | AccId: ' + o.AccountId);

    // Check Lead
    for (Lead l : [SELECT Id, Email, FirstName, LastName FROM Lead WHERE ConvertedOpportunityId = :o.Id]) {
        System.debug('  LEAD: ' + l.FirstName + ' ' + l.LastName + ' | Email: ' + l.Email);
    }
    // Check OCR -> Contact
    for (OpportunityContactRole ocr : [SELECT Contact.Id, Contact.Email, Contact.FirstName, Contact.LastName FROM OpportunityContactRole WHERE OpportunityId = :o.Id]) {
        System.debug('  OCR Contact: ' + ocr.Contact.FirstName + ' ' + ocr.Contact.LastName + ' | Email: ' + ocr.Contact.Email);
    }
    // Check Contact via Account
    if (o.AccountId != null) {
        for (Contact c : [SELECT Id, Email, FirstName, LastName FROM Contact WHERE AccountId = :o.AccountId]) {
            System.debug('  Account Contact: ' + c.FirstName + ' ' + c.LastName + ' | Email: ' + c.Email);
        }
    }
}
