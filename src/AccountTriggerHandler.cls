public class AccountTriggerHandler {
	public static void handleBeforeInsert(List<Account> accountList){
        for(Account acc:accountList){
            if(acc.Business_Type__c != null){
                acc.RecordTypeId = RecordTypeController.getRecordType(acc.Business_Type__c,'Account');
            }
        }
    }
    public static void handleafterinsert(Map<Id,Account> accountMap){
        
    }
    public static void handlebeforeupdate(Map<Id,Account> accountOldMap, Map<Id,Account> accountNewMap){
        
    }
    public static void handleafterupdate(Map<Id,Account> accountOldMap, Map<Id,Account> accountNewMap){
        
    }
}