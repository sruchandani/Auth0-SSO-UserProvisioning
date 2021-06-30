global class AuthRegistrationHandler implements Auth.RegistrationHandler {
    public class AuthUserInfo{
        public String primaryNamespace {get; set;}
        public String primaryRole {get; set;}
        public Profile profile {get; set;}
        public UserRole userRole {get; set;}
        public Account account {get; set;}
        public Contact contact {get; set;}
        public String accountNumber {get; set;}
        public String message {get; set;}
        public String employeeId {get; set;}
        public String managerId {get; set;}
        public String market {get; set;}
        public String userTypeDet {get; set;}
        public String contactRecordTypeId {get; set;}
    }

    /**
     * Let anyone register as long as the required fields are supplied
     * 
     * We require email, lastName, firstName
     * 
     * @data - the user's info from the Auth Provider
     **/ 
    global boolean canCreateUser(Auth.UserData data) {
        System.debug('canCreateUser was called for ' + (data != null ? data.email : 'null'));
        Boolean retVal = (data != null 
                && data.email != null
                && data.lastName != null
                && data.firstName != null);

        return retVal;
    }

    /**
     * Create the User - A required method to implement the Handler Interface
     * 
     * @param portalId  - Id of the Community
     * @param data - Auth Provider user data describing the User to create
     * 
     * @return User that has been initialized
    **/ 
    global User createUser(Id portalId, Auth.UserData data){
        User u = new User();
        try{
            System.debug('Auth UserData: ' + data);
            String profileName, 
                firstName = data.firstName,
                lastName = data.lastName, 
                email = data.email;
            AuthUserInfo uInfo = new AuthUserInfo();

            if (data.attributeMap.containsKey('https://auth0.demo.com/role')) {
                uInfo.primaryRole = data.attributeMap.get('https://auth0.demo.com/role');
                System.debug('role ===> ' + uInfo.primaryRole);

                if (uInfo.primaryRole == 'Sales'){
                    profileName = 'Custom: Sales Profile';
                } else if (uInfo.primaryRole == 'Ops'){
                    profileName = 'Custom: Support Profile';
                } else {
                    profileName = 'Read Only';
                }
            } else {
                System.debug('role not found in attributeMap');
            }

            // Customer portal
            Contact contact;
            if (data.attributeMap.containsKey('sfdc_networkid')) {
                profileName = 'Customer Community Profile';
                System.debug('User logging into community.');

                // Get account Id
                String companyName = data.attributeMap.get('https://auth0.demo.com/companyname');
                List<Account> accountList = [SELECT Id, Name FROM Account WHERE Name = :companyName];
                Id accountId;
                if (accountList.size() > 0){
                    accountId = accountList[0].Id;
                    System.debug('Customer Company Name: ' + accountList[0].Name);
                }

                // Create Contact
                email = data.attributeMap.get('email');
                firstName = email.split('@')[0];
                lastName = firstName;
                contact = createContact(accountId, firstName, lastName, email);
            }

            List<Profile> profileList = [SELECT Id, Name FROM Profile WHERE Name = :profileName];
            if (profileList.size() > 0){
                uInfo.profile = profileList[0];
            }

            // Using org Id to ensure unique username across all orgs
            String orgId = [SELECT Id, InstanceName FROM Organization LIMIT 1].Id;
            u.username = data.email + '.' + orgId.substring(0, 15);
            // Username max length is 80
            if (u.username.length() > 80){
                u.username = u.username.substring(0, 80);
            }
            System.debug('Creating user with username: ' + u.username);
            System.debug('data.lastName: ' + lastName);
            System.debug('data.firstName: ' + firstName);

            u.email = email;
            u.lastName = lastName;
            u.firstName = firstName;

            //Alias must be 8 characters or less
            String alias = firstName + lastName;
            if(alias.length() > 8) {
                alias = alias.substring(0, 8);
            }
            System.debug('alias: ' + alias);
            u.alias = alias;
            
            // CommunityNickname must be unique
            List<String> nickNameArr = email.split('@');
            String nickName = nickNameArr.size() > 0 ? nickNameArr[0] : email;
            
            if (nickName.length() > 40){
                nickName = nickName.substring(0, 40);
            }
            u.CommunityNickname = nickName;

            u.languagelocalekey = UserInfo.getLocale();
            u.localesidkey = UserInfo.getLocale();
            u.emailEncodingKey = 'UTF-8';
            u.timeZoneSidKey = 'America/Los_Angeles';
            
            System.debug('uInfo.profile     ' + uInfo.profile);
            if (uInfo.profile != null){
                u.profileId = uInfo.profile.Id;
            }

            // For customer users
            if (contact != null){
                u.contactId = contact.Id;
            }
            // System.debug('uInfo.userRole     ' + uInfo.userRole); 
            // if (uInfo.userRole != null) {
            //     u.UserRoleId = uInfo.userRole.Id;
            // }
        } catch (Exception ex){
            System.debug('Error occurred creating user. ' + ex.getMessage());
        }

        return u;
    }

    /**
     * Update the user
     * @param portalId  - Id of the Community
     * @param data - Auth Provider user data describing the User to create
     **/     
    global void updateUser(Id userId, Id portalId, Auth.UserData data){
        System.debug('Update User called for: ' + data.email);
        System.debug('data ===> ' + data);

    }

    /**
     * Create a Contact
     *
     * @param data - Auth0 provided context for the User
     **/
    private static Contact createContact(Id accountId, String firstName, String lastName, String email){
        Contact contact = new Contact();
        List<Contact> contactList;
        System.debug('data.emaildata.email--------------' + email);
        contactList = [SELECT Id, AccountId, LastName, FirstName, Email FROM Contact WHERE Email = : email];
        
        if(contactList.size() > 0){
            contact = contactList[0];
            System.debug('Contact found for the email ' + contact.Id);
        } else { 
            System.debug('Contact Null Scenario-New Contact');
            contact.LastName = lastName;
            contact.FirstName = firstName;
            contact.Email = email;
            contact.AccountId = accountId;
            insert contact;
        }
        return contact;
    }
}
