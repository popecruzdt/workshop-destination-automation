# To-Do List

## AI Travel Advisor
- [ ] /src directory only from container image

## OpenLLMetry & Observability
- [x] Observe OpenFeature flag changes: `PROVIDER_CONFIGURATION_CHANGED` handler emits an OTel log record; OpenPipeline extracts a Davis event (the per-evaluation `TracingHook` is not used)
- [ ] Link the flag change Davis event to the service entity (today it links to the process group instance via OneAgent metadata)
- [x] Add an Arize AX exporter (otlp/arize) to the OpenTelemetry Collector config for OpenInference traces
- [ ] Known issue: the app exports its own gen_ai.client.operation.duration and gen_ai.client.token.usage metrics through the Collector, and OpenPipeline extracts the same metric keys from spans; AI Observability can double count them

## Dynatrace
- [ ] Fix logs with openpipeline

## Red Hat
- [ ] Change ansible roles and playbooks to use all Red Hat downstream modules

