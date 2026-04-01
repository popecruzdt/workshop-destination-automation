this directory 'workshop-destination-automation' is an automation and observability workshop for Dynatrace and Red Hat Ansible Automation Platform.

This is a git repository.  Do not commit any changes.  If a commit is required, prompt the user and they will commit and sync the changes.

Anything related to automating with Ansible will be in the ansible directory.
Anything related to the application, easyTravel AI Travel Advisor, will be in the app directory.
Anything related to observing with Dynatrace will be in the dynatrace directory.

Ansible:

Reminder to self: after making any change under ~/apps/workshop-destination-automation/ansible/*, immediately sync those updates to /opt/ansible/aap/controller/projects/destination-automation/ before reporting completion.

after making any changes under ~/apps/workshop-destination-automation/*, immediately sync those updates to /home/aap-service-account/destination-automation/ before reporting completion.

All ansible roles should reference host variable destination_automation_base_dir for pathing.  For this instance, the variable is set to /home/aap-service-account/workshop-destination-automation

Dynatrace:

Nothing for now

App:

The app/podman-compose.yml file can be updated/modified, however it should not be used to deploy, start, stop, or remove the app.  It only exists for manual app deployment and is not part of the workshop.

The application stack should only be deployed, removed, built, and restarted using ansible automation platform and the appropriate job template.  Use the AAP API to invoke a job.