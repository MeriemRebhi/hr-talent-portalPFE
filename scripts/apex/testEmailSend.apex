// Test email sending capability
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{ 'eyaboudidah00@gmail.com' });
mail.setSubject('Test Email - HR Talent Portal');
mail.setPlainTextBody('Ceci est un test email.');

List<Messaging.SendEmailResult> results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
for (Messaging.SendEmailResult r : results) {
    System.debug('SUCCESS: ' + r.isSuccess());
    if (!r.isSuccess()) {
        for (Messaging.SendEmailError e : r.getErrors()) {
            System.debug('ERROR: ' + e.getMessage() + ' | StatusCode: ' + e.getStatusCode());
        }
    }
}
System.debug('Email Invocations used: check limits');
