List<User> users = [
    SELECT Id, Username, Email, IsActive, FirstName, LastName, UserType 
    FROM User 
    WHERE UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner') 
    AND IsActive = true 
    ORDER BY CreatedDate DESC LIMIT 10
];
for (User u : users) {
    System.debug(u.FirstName + ' ' + u.LastName + ' | ' + u.Email + ' | ' + u.Username + ' | Type=' + u.UserType);
}
System.debug('Total active portal users: ' + users.size());
