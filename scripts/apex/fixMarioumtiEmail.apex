// Fix Marioumti email: pi.com -> pi.tn
String wrongEmail = 'm.rebhi24292@pi.com';
String correctEmail = 'm.rebhi24292@pi.tn';

// Fix Lead
List<Lead> leads = [SELECT Id, Email FROM Lead WHERE Email = :wrongEmail];
for (Lead l : leads) {
    l.Email = correctEmail;
}
if (!leads.isEmpty()) {
    update leads;
    System.debug('Fixed ' + leads.size() + ' Lead(s)');
}

// Fix Contact
List<Contact> contacts = [SELECT Id, Email FROM Contact WHERE Email = :wrongEmail];
for (Contact c : contacts) {
    c.Email = correctEmail;
}
if (!contacts.isEmpty()) {
    update contacts;
    System.debug('Fixed ' + contacts.size() + ' Contact(s)');
}

System.debug('Done! Marioumti email corrected to: ' + correctEmail);
