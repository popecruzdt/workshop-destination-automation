# destination-automation Monaco project

This directory contains Dynatrace Monaco configuration for destination-automation.

## Project layout

Each Monaco configuration type keeps its own `config.yaml` in the same directory as its JSON templates.

Current structure:

```text
destination-automation/
	dashboards/
		config.yaml
		ai-inference-dashboard.json
```

## Required environment variables

Export the Dynatrace platform URL and platform token before deploy:

```sh
export DT_PLATFORM_URL=https://<your-environment-id>.apps.dynatrace.com
export DT_PLATFORM_TOKEN=dt0sXX.<your-platform-token>
```

## Run Monaco locally

From this directory:

```sh
./monaco deploy manifest.yaml --dry-run --verbose
./monaco deploy manifest.yaml --verbose
```

## Monaco version pin

This project currently uses Monaco 2.28.5. The automation role downloads the Monaco Linux binary into this directory as `monaco`.
