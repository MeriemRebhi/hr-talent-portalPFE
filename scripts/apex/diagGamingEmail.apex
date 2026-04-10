// Check all Gaming stage opps and their email availability
for (Opportunity o : [SELECT Id, Name, StageName, AccountId FROM Opportunity WHERE StageName = 'Gaming' ORDER BY CreatedDate DESC LIMIT 10]) {
    System.debug('=== OPP: ' + o.Name + ' | AccId: ' + o.AccountId);
    List<Lead> leads = [SELECT Email, FirstName, LastName FROM Lead WHERE ConvertedOpportunityId = :o.Id LIMIT 1];
    if (!leads.isEmpty()) {
        System.debug('  LEAD email: ' + leads[0].Email + ' (' + leads[0].FirstName + ' ' + leads[0].LastName + ')');
    } else {
        System.debug('  LEAD: NONE');
    }
    List<OpportunityContactRole> ocrs = [SELECT Contact.Email, Contact.FirstName, Contact.LastName FROM OpportunityContactRole WHERE OpportunityId = :o.Id AND Contact.Email != null LIMIT 1];
    if (!ocrs.isEmpty()) {
        System.debug('  OCR email: ' + ocrs[0].Contact.Email);
    } else {
        System.debug('  OCR: NONE');
    }
    if (o.AccountId != null) {
        List<Contact> cts = [SELECT Email, FirstName, LastName FROM Contact WHERE AccountId = :o.AccountId AND Email != null LIMIT 1];
        if (!cts.isEmpty()) {
            System.debug('  CONTACT email: ' + cts[0].Email);
        } else {
            System.debug('  CONTACT via Account: NONE');
        }
    } else {
        System.debug('  NO ACCOUNT on Opp');
    }
}

// Also check Email Deliverability
System.debug('=== Check: OrgWideEmailAddress ===');
for (OrgWideEmailAddress owa : [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress]) {
    System.debug('  OWA: ' + owa.DisplayName + ' <' + owa.Address + '>');
}
