// List all pages in the Experience site including custom pages
String baseUrl = URL.getOrgDomainUrl().toExternalForm();
String sessionId = UserInfo.getSessionId();

// 1. Check via Connect API - get pages
HttpRequest req1 = new HttpRequest();
req1.setEndpoint(baseUrl + '/services/data/v62.0/connect/communities/0DBfj000001sohhGAA/pages');
req1.setMethod('GET');
req1.setHeader('Authorization', 'Bearer ' + sessionId);
HttpResponse res1 = new Http().send(req1);
System.debug('Pages: ' + res1.getStatusCode() + ' ' + res1.getBody().substring(0, Math.min(2000, res1.getBody().length())));

// 2. Check NavigationMenuItems
HttpRequest req2 = new HttpRequest();
req2.setEndpoint(baseUrl + '/services/data/v62.0/connect/communities/0DBfj000001sohhGAA/navigation-menu/navigation-menu-items');
req2.setMethod('GET');
req2.setHeader('Authorization', 'Bearer ' + sessionId);
HttpResponse res2 = new Http().send(req2);
System.debug('NavMenu: ' + res2.getStatusCode() + ' ' + res2.getBody().substring(0, Math.min(2000, res2.getBody().length())));

// 3. Check managed content
HttpRequest req3 = new HttpRequest();
req3.setEndpoint(baseUrl + '/services/data/v62.0/tooling/query?q=SELECT+Id,DeveloperName,MasterLabel,Type+FROM+FlexiPage+WHERE+DeveloperName+LIKE+\'%25ntretien%25\'+OR+DeveloperName+LIKE+\'%25echnique%25\'+OR+MasterLabel+LIKE+\'%25ntretien%25\'');
req3.setMethod('GET');
req3.setHeader('Authorization', 'Bearer ' + sessionId);
HttpResponse res3 = new Http().send(req3);
System.debug('FlexiPages (broader search): ' + res3.getBody());

// 4. Check ALL FlexiPages (not just CommAppPage type)
HttpRequest req4 = new HttpRequest();
req4.setEndpoint(baseUrl + '/services/data/v62.0/tooling/query?q=SELECT+Id,DeveloperName,MasterLabel,Type+FROM+FlexiPage+ORDER+BY+LastModifiedDate+DESC+LIMIT+20');
req4.setMethod('GET');
req4.setHeader('Authorization', 'Bearer ' + sessionId);
HttpResponse res4 = new Http().send(req4);
System.debug('Recent FlexiPages: ' + res4.getBody());
