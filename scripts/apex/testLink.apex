Map<String,Object> result = TechnicalInterviewController.getInterviewInfo('006fj00000BRMfdAAH');
System.debug('candidateName: ' + result.get('candidateName'));
System.debug('scheduledDate: ' + result.get('scheduledDate'));
System.debug('duration: ' + result.get('duration'));
System.debug('meetLink: ' + result.get('meetLink'));
System.debug('isScheduled: ' + result.get('isScheduled'));
