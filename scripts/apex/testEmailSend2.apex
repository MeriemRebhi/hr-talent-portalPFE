// Check remaining email capacity
Messaging.SingleEmailMessage testMail = new Messaging.SingleEmailMessage();
testMail.setToAddresses(new List<String>{ 'm.rebhi24292@pi.tn' });
testMail.setSubject('Test Email Deliverability Check');
testMail.setPlainTextBody('Test - si vous recevez ceci, les emails fonctionnent.');
try {
    Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ testMail });
    for (Messaging.SendEmailResult r : results) {
        System.debug('Email sent: ' + r.isSuccess());
        if (!r.isSuccess()) {
            for (Messaging.SendEmailError err : r.getErrors()) {
                System.debug('ERROR: ' + err.getStatusCode() + ' - ' + err.getMessage());
            }
        }
    }
} catch (Exception e) {
    System.debug('EXCEPTION sending email: ' + e.getMessage());
    System.debug('Type: ' + e.getTypeName());
}

// Check limits after send
System.debug('Email invocations used: ' + Limits.getEmailInvocations() + '/' + Limits.getLimitEmailInvocations());
