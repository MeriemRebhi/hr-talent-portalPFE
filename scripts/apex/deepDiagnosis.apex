// Diagnostic complet de l'erreur UNKNOWN_EXCEPTION pendant ConvertLead

// 1. Vérifier que les duplicate rules sont bien inactives
List<DuplicateRule> activeRules = [SELECT MasterLabel, SObjectType FROM DuplicateRule WHERE IsActive = true];
System.debug('🔍 Duplicate rules actives: ' + activeRules.size());
for (DuplicateRule r : activeRules) {
    System.debug('   ⚠️ ' + r.SObjectType + ': ' + r.MasterLabel);
}

// 2. Le Lead problématique
Lead lead = [SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c, IsConverted 
             FROM Lead WHERE Id = '00Qfj00000EBQyQEAX' LIMIT 1];
System.debug('🎯 Lead: ' + lead.FirstName + ' ' + lead.LastName + ' | Email=' + lead.Email + ' | Converted=' + lead.IsConverted);

// 3. Compter les entités en doublon
Integer leadCount = [SELECT COUNT() FROM Lead WHERE Email = :lead.Email AND IsConverted = false];
Integer contactCount = [SELECT COUNT() FROM Contact WHERE Email = :lead.Email];
Integer accountCount = [SELECT COUNT() FROM Account WHERE Name = :lead.Email];
System.debug('📊 Leads non-convertis: ' + leadCount + ' | Contacts: ' + contactCount + ' | Accounts: ' + accountCount);

// 4. Lister les Contacts
List<Contact> contacts = [SELECT Id, AccountId, Account.Name, FirstName, LastName FROM Contact WHERE Email = :lead.Email];
for (Contact c : contacts) {
    System.debug('   Contact: ' + c.Id + ' | ' + c.FirstName + ' ' + c.LastName + ' | Account=' + c.AccountId + ' (' + c.Account.Name + ')');
}

// 5. Lister les Users
List<User> users = [SELECT Id, Username, UserType, IsActive, ContactId FROM User WHERE Email = :lead.Email];
for (User u : users) {
    System.debug('   User: ' + u.Id + ' | ' + u.Username + ' | Type=' + u.UserType + ' | Active=' + u.IsActive + ' | Contact=' + u.ContactId);
}

// 6. Essayer la conversion avec différentes approches
if (!lead.IsConverted) {
    // Approche A : avec Contact existant + sans créer d'Opportunity
    try {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(lead.Id);
        
        if (!contacts.isEmpty()) {
            lc.setContactId(contacts[0].Id);
            lc.setAccountId(contacts[0].AccountId);
        }
        
        LeadStatus cs = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        lc.setConvertedStatus(cs.MasterLabel);
        lc.setDoNotCreateOpportunity(true);
        
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        if (lcr.isSuccess()) {
            System.debug('✅ APPROCHE A RÉUSSIE ! Contact=' + lcr.getContactId());
        } else {
            for (Database.Error err : lcr.getErrors()) {
                System.debug('❌ APPROCHE A: ' + err.getStatusCode() + ' | ' + err.getMessage() + ' | Fields: ' + err.getFields());
            }
        }
    } catch (Exception e) {
        System.debug('❌ APPROCHE A Exception: ' + e.getMessage());
        System.debug('   Stack: ' + e.getStackTraceString());
        System.debug('   Type: ' + e.getTypeName());
    }
}
