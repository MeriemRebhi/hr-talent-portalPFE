// Diagnostic: pourquoi la conversion a échoué pour aziz bouhajja
// Lead ID: 00Qfj00000EAf8KEAT

// 1. Vérifier tous les Leads de cet email
List<Lead> leads = [SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c, IsConverted, CreatedDate 
                    FROM Lead WHERE Email = 'm.rebhi24292@pi.tn' ORDER BY CreatedDate DESC];
System.debug('📋 Nombre de Leads avec cet email: ' + leads.size());
for (Lead l : leads) {
    System.debug('   Lead ' + l.Id + ' | ' + l.FirstName + ' ' + l.LastName + ' | Status=' + l.Status + ' | Score=' + l.Score_Matching__c + ' | Converted=' + l.IsConverted + ' | Created=' + l.CreatedDate);
}

// 2. Vérifier si un Contact existe déjà avec cet email
List<Contact> contacts = [SELECT Id, FirstName, LastName, Email, AccountId FROM Contact WHERE Email = 'm.rebhi24292@pi.tn'];
System.debug('👤 Contacts avec cet email: ' + contacts.size());
for (Contact c : contacts) {
    System.debug('   Contact ' + c.Id + ' | ' + c.FirstName + ' ' + c.LastName + ' | Account=' + c.AccountId);
}

// 3. Vérifier si un User existe déjà avec cet email
List<User> users = [SELECT Id, Username, Email, IsActive, UserType, ContactId FROM User WHERE Email = 'm.rebhi24292@pi.tn'];
System.debug('🔑 Users avec cet email: ' + users.size());
for (User u : users) {
    System.debug('   User ' + u.Id + ' | Username=' + u.Username + ' | Active=' + u.IsActive + ' | Type=' + u.UserType + ' | Contact=' + u.ContactId);
}

// 4. Vérifier le statut converti disponible
List<LeadStatus> convertedStatuses = [SELECT MasterLabel, ApiName FROM LeadStatus WHERE IsConverted = true];
System.debug('✅ Statuts convertis: ');
for (LeadStatus ls : convertedStatuses) {
    System.debug('   ' + ls.MasterLabel + ' (API: ' + ls.ApiName + ')');
}

// 5. Vérifier les AsyncApexJob récents (erreurs de Queueable)
List<AsyncApexJob> jobs = [SELECT Id, Status, ApexClass.Name, ExtendedStatus, CreatedDate, CompletedDate 
                           FROM AsyncApexJob 
                           WHERE ApexClass.Name LIKE '%CVScoring%' 
                           ORDER BY CreatedDate DESC LIMIT 5];
System.debug('⚙️ Jobs CVScoring récents:');
for (AsyncApexJob j : jobs) {
    System.debug('   ' + j.Id + ' | ' + j.Status + ' | ' + j.ExtendedStatus + ' | Created=' + j.CreatedDate);
}

// 6. Essayer la conversion maintenant pour voir l'erreur
Lead targetLead = leads[0];
if (!targetLead.IsConverted) {
    try {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(targetLead.Id);
        
        if (!contacts.isEmpty()) {
            lc.setContactId(contacts[0].Id);
            lc.setAccountId(contacts[0].AccountId);
        } else {
            Account newAcc = new Account(Name = targetLead.Email);
            insert newAcc;
            lc.setAccountId(newAcc.Id);
        }
        
        LeadStatus cs = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        lc.setConvertedStatus(cs.MasterLabel);
        lc.setOpportunityName(targetLead.LastName + ' - Candidature (20%)');
        lc.setDoNotCreateOpportunity(false);
        
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        if (lcr.isSuccess()) {
            System.debug('✅ CONVERSION RÉUSSIE MAINTENANT ! Contact=' + lcr.getContactId() + ' Opp=' + lcr.getOpportunityId());
        } else {
            for (Database.Error err : lcr.getErrors()) {
                System.debug('❌ Erreur conversion: ' + err.getMessage() + ' | Fields: ' + err.getFields());
            }
        }
    } catch (Exception e) {
        System.debug('❌ Exception conversion: ' + e.getMessage() + '\n' + e.getStackTraceString());
    }
}
