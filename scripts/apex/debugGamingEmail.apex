// Find recent Application opps
List<Opportunity> opps = [SELECT Id, Name, StageName, AccountId, Account.Name FROM Opportunity WHERE RecordType.DeveloperName = 'Application' ORDER BY CreatedDate DESC LIMIT 5];
for (Opportunity o : opps) {
    System.debug('OPP: ' + o.Id + ' | ' + o.Name + ' | Stage: ' + o.StageName + ' | AccId: ' + o.AccountId + ' | AccName: ' + o.Account.Name);

    // 1. Try Lead by ConvertedOpportunityId
    List<Lead> leads = [SELECT Id, FirstName, LastName, Email, IsConverted, ConvertedOpportunityId, ConvertedContactId, ConvertedAccountId FROM Lead WHERE ConvertedOpportunityId = :o.Id];
    System.debug('  Lead by ConvertedOppId: ' + leads.size());
    for (Lead l : leads) {
        System.debug('    -> ' + l.FirstName + ' ' + l.LastName + ' | Email: ' + l.Email);
    }

    // 2. Try Contact by AccountId
    if (o.AccountId != null) {
        List<Contact> contacts = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE AccountId = :o.AccountId LIMIT 3];
        System.debug('  Contacts on Account: ' + contacts.size());
        for (Contact c : contacts) {
            System.debug('    -> ' + c.FirstName + ' ' + c.LastName + ' | Email: ' + c.Email);
        }
    }

    // 3. Try OpportunityContactRole
    List<OpportunityContactRole> ocrs = [SELECT ContactId, Contact.FirstName, Contact.LastName, Contact.Email FROM OpportunityContactRole WHERE OpportunityId = :o.Id];
    System.debug('  ContactRoles: ' + ocrs.size());
    for (OpportunityContactRole ocr : ocrs) {
        System.debug('    -> ' + ocr.Contact.FirstName + ' ' + ocr.Contact.LastName + ' | Email: ' + ocr.Contact.Email);
    }
}
