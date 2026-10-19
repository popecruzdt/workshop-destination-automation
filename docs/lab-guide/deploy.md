# Deploy

Deployment uses Red Hat Ansible Automation Platform to configure platform objects and deliver both observability components and the AI application stack.

## Objectives

- Configure Ansible Controller and EDA objects for the workshop.
- Deploy Dynatrace apps and API settings.
- Deploy EdgeConnect and OneAgent.
- Build and deploy the easyTravel AI Travel Advisor stack using Podman workflows.

## Step 1: Create Ansible Automation Platform Service Account User

Before running deployment automation, create and validate the `aap-service-account` user on the RHEL host.

Reference guide:
[ansible/deploy/docs/aap-service-account-setup.md](https://github.com/dynatrace-wwse/workshop-destination-automation/blob/main/ansible/deploy/docs/aap-service-account-setup.md){target="_blank"}

## Step 2: Configure Ansible Automation Platform and EDA

Run the bootstrap playbooks from the ansible directory.

??? tip "Workshop Participant Count"
    By default, a single workshop participant user login is created.  You can change the number of participant user logins created by setting the environment variable `AAP_PARTICIPANT_COUNT`.
    For example, you can generate `5` participant user logins using:

    ```
    export AAP_PARTICIPANT_COUNT=5
    ```

    You'll find the credentials in the `/tmp/workshop-destination-automation-passwords/` directory (by default).

Deploy Automation Execution (Automation Controller) objects:

```bash
cd ~/workshop-destination-automation/ansible
ansible-playbook deploy/playbooks/configure_aap.yml
```

Deploy Automation Decisions (Event-Driven Ansible) objects:

```bash
ansible-playbook deploy/playbooks/configure_eda.yml
```

After playbook completion, review credentials and inventory objects in the Ansible web UI.  You'll need to manually update the following credentials in the UI.

**Apply Credentials via UI**

- aap-service-account

![aap-service-account](../assets/images/aap-credential-aap-service-account.png)

- destination-automation-dynatrace-monaco

![dynatrace monaco](../assets/images/aap-credential-dynatrace-monaco.png)

- destination-automation-dynatrace-oauth

![dynatrace oauth](../assets/images/aap-credential-dynatrace-oauth.png)

- destination-automation-dynatrace-oneagent

![dynatrace oneagent](../assets/images/aap-credential-dynatrace-oneagent.png)

- destination-automation-dynatrace-otlp

![dynatrace otlp](../assets/images/aap-credential-dynatrace-otlp.png)

**Create Job Template Domains (optional, recommended)**

Ansible Web UI -> Automation Execution (Automation Controller) -> Templates: Configure Domains (🔧 wrench icon)

- Name: Dynatrace
    - Labels: dynatrace
- Name: App
    - Labels: app

![Domains](../assets/images/aap-template-domains.png)

## Step 3: Deploy Dynatrace Components

Launch the relevant Ansible job templates for:

- Dynatrace AppEngine apps
    - `destination-automation-deploy-dynatrace-apps`
- Dynatrace API config objects
    - `destination-automation-deploy-dynatrace-api-config`
    - Contains objects that aren't currently supported by Monaco
- Dynatrace Monaco project
    - `destination-automation-deploy-dynatrace-monaco`
- Dynatrace EdgeConnect (when private network connectivity requires it)
    - `destination-automation-deploy-dynatrace-edgeconnect`
    - Verify you're using the correct value of `dynatrace_edgeconnect_oauth_endpoint` variable
- Dynatrace OneAgent on workshop host
    - `destination-automation-deploy-dynatrace-oneagent`

**Configure OpenPipeline Routing Tables (Manually):**

OpenPipeline routing tables are comprehensive for the environment.  If existing rules exist in the routing table, applying a new configuration with Monaco will delete/overwrite the existing rules.  To avoid this behavior, for now, routing table rules need to be created manually.

Logs:

- Name: 

```
destination-automation-logs
```

- Matching Condition: 

```
matchesValue(dt.host_group.id,"destination-automation")
```

- Pipeline: destination-automation-logs

Spans:

- Name: 

```
destination-automation-spans
```

- Matching Condition: 

```
matchesValue(dt.host_group.id,"destination-automation")
```

- Pipeline: destination-automation-spans

BizEvents:

- Name: 

```
destination-automation-bizevents
```

- Matching Condition: 

```
matchesValue(dt.host_group.id,"destination-automation")
```

- Pipeline: destination-automation-bizevents

OpenTelemetry-only mode (no OneAgent) adds routes on `service.namespace` instead of the host group: Logs `matchesValue(service.namespace,"destination-automation")` to `destination-automation-logs`; Spans `matchesValue(service.namespace,"destination-automation")` to `destination-automation-otlp-spans`; and BizEvents with the matching condition extended by `or matchesValue(service.namespace,"destination-automation")`.

Here is an example routing table for logs:
![OpenPipeline Routing Logs](../assets/images/dynatrace-openpipeline-logs-routing.png)

**Enable Workflows Authorization:**

Open the Workflows app.  In the top right corner, click on the gear icon, then Authorization Settings.  Enable all Primary Permissions.  Enable all Secondary Permissions.  Click Save.

![Workflow Authorization](../assets/images/dynatrace-workflow-authorization.png)

## Step 4: Deploy the AI Travel Advisor Application

Run the workshop app deployment workflow template from Ansible Automation Platform:

`destination-automation-workflow-deploy-app-clean`

This workflow template will perform the following:

![Workflow](../assets/images/aap-deploy-app-workflow-template-job.png)

- Remove the app if it already exists
- Remove the images if they already exist
- Build new app images
- Deploy the app as rootless podman containers
- Verify health endpoints and access

Access the app on port 80 (HTTP) of your public hostname (FQDN or IP).

![easyTravel AI Travel Advisor](../assets/images/easytrave-ai-travel-advisor-home.png)

## Validation

- [ ] Dynatrace components are installed and authenticated
- [ ] OneAgent reports data from the workshop host
- [ ] App stack is reachable and healthy
- [ ] Ansible workflows complete without failed tasks

Continue to [Observe and Automate](observe-and-automate.md).
