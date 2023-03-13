global class BatchToUpdateOppSource implements Database.Batchable<sObject> 
{
    //added comment bhy sudhendra
    global Database.QueryLocator start( Database.BatchableContext BC ) 
    {
        return Database.getQueryLocator( [SELECT Id,
                                          StageName,
                                          Reason_Lost__c,
                                          Opportunity_Source__c,
                                          CreatedBy.User_Team__c,
                                          ContactId,
                                          LeadSource,
                                          CreatedDate,
                                          isClosed,
                                          RecordTypeId
                                          FROM Opportunity
                                          WHERE CreatedDate >= LAST_YEAR 
                                          ORDER By createddate desc]);
        // opp created >= 2022
    }
    global void execute( Database.BatchableContext BC, List< Opportunity > listOpportunities ) 
    {
        Map<String,String> newLostReasonMapping = new Map<String,String>
        {
            'Competitor'=>'Lost to Competitor',
                'Internal/Invalid Data'=>'Invalid Contact Info',
                'Timing'=>'Timing/ No Need',
                'Gone Dark'=>'Unresponsive'
                };
        boolean toUpdate = false;
        Map<Id,Contact> mapOfPrimaryContacts = new Map<Id,Contact>();
        Set<Id> primaryContactIds = new Set<Id>();
        List<Opportunity> oppToUpdateList = new List<Opportunity>();
        List<Id> opportunityIds = new List<Id>();
        Map<Id,Id> opportunityToPrimaryContact = new Map<Id,Id>();
        for(Opportunity objOpp : listOpportunities)
        {
            opportunityIds.add(objOpp.Id);
            if(objOpp.ContactId != null)
            {
                primaryContactIds.add(objOpp.ContactId); 
                opportunityToPrimaryContact.put(objOpp.Id,objOpp.ContactId);
            }
        }
        for(OpportunityContactRole oppConRole : [SELECT Id,ContactId,Role, OpportunityId 
                                                 FROM OpportunityContactRole 
                                                 WHERE OpportunityId IN: opportunityIds 
                                                 AND Role = 'Influencer'])
        {
            primaryContactIds.add(oppConRole.ContactId); 
            if(!opportunityToPrimaryContact.containsKey(oppConRole.OpportunityId))
            {
                opportunityToPrimaryContact.put(oppConRole.OpportunityId,oppConRole.ContactId);
            }
            
        }
        
        if(!primaryContactIds.isEmpty())
        {
            for(Contact objContact : [SELECT Id,CreatedDate,known_Date__c,MQL_Date__c,LeadSource,Lead_Source_Detail__c FROM Contact WHERE Id IN: primaryContactIds])
            {
                mapOfPrimaryContacts.put(objContact.Id, objContact);
            }
        }        
        for(Opportunity objOpp : listOpportunities)
        {
            toUpdate = false; 
            Opportunity oppToUpdate = new Opportunity();
            oppToUpdate.Id = objOpp.Id;
            if(objOpp.StageName == 'Closed Lost' 
               && objOpp.IsClosed == True
               && String.isNotBlank(objOpp.Reason_Lost__c) 
               && newLostReasonMapping.containsKey(objOpp.Reason_Lost__c))
            {
                oppToUpdate.Reason_Lost__c = newLostReasonMapping.get(objOpp.Reason_Lost__c);
                toUpdate = true;
            }   
            if(isValidRecordType(objOpp)
               && !mapOfPrimaryContacts.isEmpty()
               && mapOfPrimaryContacts.containsKey(opportunityToPrimaryContact.get(objOpp.Id))
               && opportunityToPrimaryContact.containsKey(objOpp.Id))
            {
                if(objOpp.CreatedDate > mapOfPrimaryContacts.get(opportunityToPrimaryContact.get(objOpp.Id)).MQL_Date__c
                    && mapOfPrimaryContacts.get(opportunityToPrimaryContact.get(objOpp.Id)).MQL_Date__c > objOpp.CreatedDate.addMonths(-6))                  
                {
                    oppToUpdate.Opportunity_Source__c = 'Marketing';
                    toUpdate = true;
                }
                else if(mapOfPrimaryContacts.get(opportunityToPrimaryContact.get(objOpp.Id)).LeadSource == 'Broker' 
                   && mapOfPrimaryContacts.get(opportunityToPrimaryContact.get(objOpp.Id)).known_Date__c > objOpp.CreatedDate.addMonths(-3))
                {
                    oppToUpdate.Opportunity_Source__c = 'Broker';
                    toUpdate = true;
                }                  
                else if(canUpdateOpportunitySource(mapOfPrimaryContacts.get(opportunityToPrimaryContact.get(objOpp.Id)))
                        && mapOfPrimaryContacts.get(opportunityToPrimaryContact.get(objOpp.Id)).known_Date__c > objOpp.CreatedDate.addMonths(-6))
                {         
                    oppToUpdate.Opportunity_Source__c = 'Marketing';
                    toUpdate = true;
                }
                else
                {                
                    String userTeam = objOpp.CreatedBy?.User_Team__c;
                    if(userTeam != null && OpportunityTriggerHandler.userTeamMap.keySet().contains(userTeam))
                    {
                        oppToUpdate.Opportunity_Source__c = OpportunityTriggerHandler.userTeamMap.get(userTeam);
                        toUpdate = true;
                    }   
                }

            }
            if(toUpdate)
            {
                oppToUpdateList.add(oppToUpdate);
            }
        }
        if(!oppToUpdateList.isEmpty())
        {
            Database.Update(oppToUpdateList,false);
        }
    }   
    
    global void finish( Database.BatchableContext BC ) 
    {
    }
   public static Boolean canUpdateOpportunitySource(Contact contactRec)
    {
        Set<String> leadSources = new Set<String>
        {
             'Content Syndication'
             ,'Website'
             ,'Organic Social'
             ,'Paid Search'
             ,'Web Chat'
             ,'Paid Social'
             ,'Webinar'
             ,'Display'
             ,'Fourth Hosted Event'
             ,'Marketing Legacy'
        };
        Set<String> leadSourcesWithLeadSourceDetail = new Set<String>
        {
             'Database'
             ,'Broker'
             ,'Tradeshow'
             ,'Customer Conference'
             ,'Purchased List'
        };
            
        if(leadSources.contains(contactRec.LeadSource) ||
           (String.isNotBlank(contactRec.Lead_Source_Detail__c) && 
            contactRec.Lead_Source_Detail__c.contains('Marketing') && 
            (leadSourcesWithLeadSourceDetail.contains(contactRec.LeadSource))))
        {
            return true;
        }
        return false;
    } 
    public static boolean isValidRecordType(Opportunity objOpp)
    { 
        return (objOpp.RecordTypeId == OpportunityTriggerHandler.recordType_US_SaaS
                || objOpp.RecordTypeId == OpportunityTriggerHandler.recordType_Global_SaaS
                || objOpp.RecordTypeId == OpportunityTriggerHandler.recordType_PEO); 
    }
}