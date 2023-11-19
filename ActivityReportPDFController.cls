/**
 * @author            : salihcendik
 * @last modified on  : 08-25-2023
 * @last modified by  : salihcendik
**/
public with sharing class ActivityReportPDFController {
    private Id accountId;
    private Date activityStartDate;
    private Date activityEndDate;
    public String monthNamesInActivity {get;set;}
    public List<Activity> activites {get;set;}
    public String pieChartParameter {get;set;}
    public Boolean activityDatesFullfilled {get;set;}

    public ActivityReportPDFController(ApexPages.StandardController stdController){
       List<String> fields = new List<String>{'Id','ActivityReportStartDate__c', 'ActivityReportEndDate__c'};
       if (!Test.isRunningTest()) stdController.addFields(fields);
       Account acc = (Account)stdController.getRecord();
       accountId = acc.Id;
       activityStartDate = acc.ActivityReportStartDate__c;
       activityEndDate = acc.ActivityReportEndDate__c;
       activityDatesFullfilled = false;
       if (activityStartDate != null &&  activityEndDate != null){
            activityDatesFullfilled = true;
            settingActivities();
       }
    }

    public void settingActivities(){
        activites = new List<Activity>();
        getTasks();
        getEvents();
    }

    public void getTasks(){
        List<Task> tasks = [SELECT Subject, Description, WorkingDuration__c, Start_Date__c, Owner.Name, WhatId, What.Type 
        FROM Task 
        WHERE Account__c = :accountId AND 
        Owner.Profile.Name = 'Support End User' AND
        ((What.Type = 'Project__c' AND What.RecordType.DeveloperName = 'Bakim') OR (What.Type = 'Case')) AND
        Start_Date__c >= :activityStartDate AND Start_Date__c <= :activityEndDate ORDER BY Start_Date__c ASC];
        if (!tasks.isEmpty()) {
           setActivities(tasks);
        }
    }

    public void getEvents(){
        List<Event> events = [SELECT Subject, Description, WorkingDuration__c, StartDateTime, Owner.Name, WhatId, What.Type 
        FROM Event 
        WHERE Account__c = :accountId AND 
        Owner.Profile.Name = 'Support End User' AND
        ((What.Type = 'Project__c' AND What.RecordType.DeveloperName = 'Bakim') OR (What.Type = 'Case')) AND
        StartDateTime >= :activityStartDate AND StartDateTime <= :activityEndDate ORDER BY StartDateTime ASC];
        if (!events.isEmpty()) {
            setActivities(events);
        }
    }

    public void setActivities(List<sObject> records){
        Boolean isTask = records.getSObjectType() == Schema.Task.getSObjectType();
        Boolean isEvent = records.getSObjectType() == Schema.Event.getSObjectType();
        Set<Integer> monthsInActivity = new Set<Integer>();
        for (sObject item : records) {
            Activity acty = new Activity();
            acty.OwnerName = (string) item.getSObject('Owner').get('Name');
            acty.Subject = (string) item.get('Subject');
            acty.Comments = (string) item.get('Description');
            acty.SLATime = (decimal) item.get('WorkingDuration__c');
            DateTime dateOpened = (dateTime) item.get(isTask ? 'Start_Date__c' : 'StartDateTime');
            acty.DateOpened = Date.valueOf(dateOpened);
            acty.RelatedObjId = (string) item.get('WhatId');
            acty.RelatedObjType = (string) item.getSObject('What').get('Type');
            activites.add(acty);
            monthsInActivity.add(acty.DateOpened?.month());
        }
        
        setMonthNamesInAcvivity(monthsInActivity);
        setCategoryforActivities();
    }

    public void setMonthNamesInAcvivity(Set<Integer> months){
        List<Integer> monthsList = new List<Integer>(months);
        monthsList.sort();
        List<String> monthNames = new List<String>();
        for (Integer month : monthsList) {
            monthNames.add(getMonthName(month));
        }
        monthNamesInActivity = String.join(monthNames, ',');
    }

    public void setCategoryforActivities() {
        if (activites.isEmpty()) {
            return;
        }

        Set<String> projectIds = new Set<String>();
        Set<String> caseIds = new Set<String>();
        for (Activity acty : activites) {
            if (acty.RelatedObjType == 'Project__c') {
                projectIds.add(acty.RelatedObjId);
            }else if (acty.RelatedObjType == 'Case'){
                caseIds.add(acty.RelatedObjId);
            }
        }    
        
        Map<Id, Project__c> projects = new Map<Id, Project__c>([SELECT Id, Product_Category_New__c FROM Project__c WHERE Id IN :projectIds]);
        Map<Id, Case> cases = new Map<Id, Case>([SELECT Id, Product_Category_New__c FROM Case WHERE Id IN :caseIds]);

        for (Activity acty : activites) {
            if (acty.RelatedObjType == 'Project__c') {
                acty.category = projects.get(acty.RelatedObjId).Product_Category_New__c;
            }else if (acty.RelatedObjType == 'Case'){
                acty.category = cases.get(acty.RelatedObjId).Product_Category_New__c;
            }
        }   
        
        generatePieChart();
    }

    public void generatePieChart(){
        Map<String, Decimal> pieDataMap = new Map<String, Decimal>();
        for (Activity acty : activites) {
            if (!pieDataMap.containsKey(acty.category)) {
                pieDataMap.put(acty.category, 0);
            }
            pieDataMap.put(acty.category, pieDataMap.get(acty.category) + acty.SLATime);
        }

        String chartLabel = pieDataMap.keySet().toString().replace('{','').replace('}','').replace(', ','|');
        String sliceData = String.join(pieDataMap.values(), ','); 
        String sliceLabel = String.join(pieDataMap.values(), '|');
        pieChartParameter = generatePieChartParameter(sliceLabel, sliceData, chartLabel);
    }

    public String generatePieChartParameter(String slicelabel, String sliceData, String chartLabel){
        String pieChartParameter = '';
        String chartType = 'p3';
        String chartData = 'a:' + sliceData; 
        String chartSize = '700x250';
        String chartTitle = 'Worked+Hours';
        pieChartParameter += 'cht=' + chartType;
        pieChartParameter += '&chd=' + chartData;
        pieChartParameter += '&chs=' + chartSize;
        pieChartParameter += '&chl=' + sliceLabel;
        pieChartParameter += '&chtt=' + chartTitle;
        pieChartParameter += '&chdl=' + chartLabel;
        return pieChartParameter;
    }

    public String getMonthName(Integer monthNumb){
        switch on monthNumb {
            when 1 {return 'OCAK';}
            when 2 {return 'ŞUBAT';}
            when 3 {return 'MART';}
            when 4 {return 'NİSAN';}
            when 5 {return 'MAYIS';}
            when 6 {return 'HAZİRAN';}
            when 7 {return 'TEMMUZ';}
            when 8 {return 'AĞUSTOS';}
            when 9 {return 'EYLÜL';}
            when 10 {return 'EKİM';}
            when 11 {return 'KASIM';}
            when 12 {return 'ARALIK';}
            when else {return 'Not Found Month';}
        }
    }

    public class Activity{
        public String OwnerName {get;set;}
        public String Subject {get;set;}
        public String Comments {get;set;}
        public Date DateOpened {get;set;}
        public Decimal SLATime {get;set;}
        public String relatedObjId {get;set;}
        public String relatedObjType {get;set;}
        public String category {get;set;}
    }

}