// Check roihizeineb123@gmail.com conversion + portal user
List<Lead> leads = [SELECT Id, FirstName, LastName, Email, IsConverted, ConvertedContactId, ConvertedOpportunityId FROM Lead WHERE Email = 'roihizeineb123@gmail.com' LIMIT 1];
if(leads.isEmpty()) {
    System.debug('NO LEAD FOUND');
} else {
    Lead l = leads[0];
    System.debug('Lead: ' + l.FirstName + ' ' + l.LastName + ' | Converted: ' + l.IsConverted);
    System.debug('ContactId: ' + l.ConvertedContactId + ' | OppId: ' + l.ConvertedOpportunityId);
}

List<Contact> contacts = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Email = 'roihizeineb123@gmail.com' LIMIT 1];
if(!contacts.isEmpty()) {
    System.debug('Contact found: ' + contacts[0].Id + ' ' + contacts[0].FirstName + ' ' + contacts[0].LastName);
} else {
    System.debug('NO CONTACT FOUND');
}

List<User> users = [SELECT Id, Username, IsActive, Profile.Name, LastLoginDate, CreatedDate FROM User WHERE Email = 'roihizeineb123@gmail.com' LIMIT 5];
if(users.isEmpty()) {
    System.debug('NO PORTAL USER FOUND');
} else {
    for(User u : users) {
        System.debug('User: ' + u.Username + ' | Active: ' + u.IsActive + ' | Profile: ' + u.Profile.Name + ' | Created: ' + u.CreatedDate + ' | LastLogin: ' + u.LastLoginDate);
    }
}

// Check if any email was sent recently
List<EmailMessage> emails = [SELECT Id, Subject, ToAddress, CreatedDate FROM EmailMessage WHERE ToAddress = 'roihizeineb123@gmail.com' ORDER BY CreatedDate DESC LIMIT 5];
for(EmailMessage em : emails) {
    System.debug('Email: ' + em.Subject + ' | Date: ' + em.CreatedDate);
}
