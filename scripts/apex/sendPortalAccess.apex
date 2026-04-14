// Send portal access email to roihizeineb123@gmail.com
List<User> users = [SELECT Id, Username, ContactId, Email FROM User WHERE Email = 'roihizeineb123@gmail.com' AND IsActive = true LIMIT 1];
if (users.isEmpty()) {
    System.debug('ERROR: No active user found for this email');
} else {
    User u = users[0];
    System.debug('User found: ' + u.Username);
    
    // Reset password to generate a new one and send email
    System.resetPassword(u.Id, true);
    System.debug('Password reset email sent to ' + u.Email);
}
