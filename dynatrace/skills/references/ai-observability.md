# AI Observability Reference

Reference for querying GenAI, LLM, and AI agent traces in Dynatrace using dtctl and DQL.

## Key Concepts

### Retrieval-Augmented Generation (RAG)
RAG enhances LLM performance by retrieving relevant documents from external sources (vector databases, knowledge bases) before generation. The retrieved data provides context to improve accuracy and relevance.

### Agents
Autonomous entities that perform tasks using language models. Agents can make decisions, use tools, and operate with varying independence levels.

### Agentic Systems
Systems where multiple intelligent agents work together to address complex queries. Agents assess relevance, prioritize information, and modify generation based on context.

### Guardrails
Runtime controls that detect and handle unsafe behavior (policy violations, PII exposure, abuse patterns). Guardrails explain why model interactions were blocked, modified, or allowed.

### Traceloop Span Kind
The `traceloop.span.kind` attribute organizes spans created by Traceloop (OpenLLMetry). In the AI Travel Advisor it is set on the `@workflow` spans (`llm_advice_workflow`, `rag_advice_workflow`, `agentic_advice_workflow`):
- **`workflow`**: High-level process or chain of operations
- **`task`**: Specific operation within a workflow
- **`agent`**: Autonomous component making decisions
- **`tool`**: Utility or function used within the application

### OpenInference Span Kind
LangChain and LangGraph spans in the AI Travel Advisor come from OpenInference, which sets `openinference.span.kind`:
- **`AGENT`**: The agent graph run (`travel_agent`)
- **`CHAIN`**: Graph nodes and routing steps (`call_model`, `plan_fallback`, `tools`, `respond`)
- **`TOOL`**: Tool calls (`validate_destination`, `search_destination_kb`, `get_current_season`)
- **`LLM`**: Model calls (span name `ChatOllama`)

The app emits OpenInference attributes only (`llm.model_name`, `llm.token_count.*`, `llm.input_messages.*`, `tool.name`, ...). The `openinference-ai-spans` OpenPipeline pipeline (routed with `isNotNull(openinference.span.kind)`) maps them to `gen_ai.*` at ingest, so query the `gen_ai.*` fields in Grail for spans ingested after the pipeline was applied.

## OpenTelemetry GenAI Semantic Conventions

### Common GenAI Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `gen_ai.operation.name` | Operation being performed | chat, embeddings, invoke_agent |
| `gen_ai.system` | GenAI system/provider | openai, anthropic, aws.bedrock, ollama |
| `gen_ai.request.model` | Model used for request | gpt-4, claude-3-5-sonnet, gemma3:1b-it-qat |
| `gen_ai.response.model` | Model that generated response | gpt-4-0613 |
| `gen_ai.usage.input_tokens` | Tokens in prompt | 100 |
| `gen_ai.usage.output_tokens` | Tokens in completion | 180 |
| `gen_ai.request.max_tokens` | Maximum tokens requested | 100 |
| `gen_ai.response.id` | Unique completion identifier | chatcmpl-123 |
| `gen_ai.response.finish_reasons` | Why model stopped | ["stop"], ["length"], ["content_filter"] |
| `gen_ai.conversation.id` | Conversation identifier | conv_5j66UpCpwteGg4YSxUnt7lPY |
| `gen_ai.request.temperature` | Temperature parameter | 0.7 |
| `gen_ai.request.top_p` | Top-p sampling setting | 1.0 |

### Agent Span Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `gen_ai.agent.id` | Unique agent identifier | assist_agent_5j66... |
| `gen_ai.agent.name` | Human-readable agent name | Supervisor, FAQ Agent |
| `gen_ai.agent.description` | Agent description | Orchestrates agents for flight details |
| `gen_ai.data_source.id` | Data source for RAG | H7STPQYOND |
| `gen_ai.output.type` | Content type requested | text, json, image |
| `gen_ai.system_instructions` | System message/instructions | JSON array of instructions |
| `gen_ai.tool.definitions` | Tools available to agent | JSON array of tools |
| `gen_ai.input.messages` | Chat history to model | JSON array of messages |
| `gen_ai.output.messages` | Messages from model | JSON array of responses |

### Provider-Specific Attributes

#### OpenAI
Set `gen_ai.system` to `openai`

| Attribute | Description | Example |
|-----------|-------------|---------|
| `openai.request.service_tier` | Service tier requested | auto, default |
| `openai.response.service_tier` | Service tier used | scale, default |
| `openai.response.system_fingerprint` | Environment fingerprint | fp_44709d6fcb |

#### AWS Bedrock
Set `gen_ai.system` to `aws.bedrock`

| Attribute | Description | Example |
|-----------|-------------|---------|
| `aws.bedrock.guardrail.id` | Bedrock guardrail identifier | sgi5gkybzqak |
| `aws.bedrock.knowledge_base.id` | Knowledge base for RAG | XFWUPB9PAW |

#### Azure AI Inference
Set `gen_ai.system` to `azure.ai.inference`

| Attribute | Description | Example |
|-----------|-------------|---------|
| `azure.resource_provider.namespace` | Azure resource provider | Microsoft.CognitiveServices |

### GenAI Metrics

| Metric | Description |
|--------|-------------|
| `gen_ai.client.token.usage` | Token usage by input/output type |
| `gen_ai.client.operation.duration` | Duration of GenAI operations |

## DQL Query Patterns for AI Observability

### Find spans by GenAI model
```dql
fetch spans, from:now()-1h
| filter isNotNull(gen_ai.request.model)
| filter gen_ai.request.model == "gpt-4" or gen_ai.request.model == "claude-3-5-sonnet"
| fields timestamp, span.name, service.name, gen_ai.request.model, gen_ai.system, duration
| sort timestamp desc
```

### Analyze token usage by service
```dql
fetch spans, from:now()-24h
| filter isNotNull(gen_ai.usage.input_tokens)
| summarize 
    total_input_tokens = sum(gen_ai.usage.input_tokens),
    total_output_tokens = sum(gen_ai.usage.output_tokens),
    avg_input = avg(gen_ai.usage.input_tokens),
    avg_output = avg(gen_ai.usage.output_tokens),
    by:{service.name, gen_ai.request.model}
| sort total_input_tokens desc
```

### Find expensive GenAI operations
```dql
fetch spans, from:now()-6h
| filter isNotNull(gen_ai.usage.output_tokens)
| fieldsAdd total_tokens = gen_ai.usage.input_tokens + gen_ai.usage.output_tokens
| filter total_tokens > 10000
| fields timestamp, span.name, service.name, gen_ai.request.model, total_tokens, duration
| sort total_tokens desc
```

### Analyze GenAI operation performance
```dql
fetch spans, from:now()-24h
| filter isNotNull(gen_ai.operation.name)
| summarize 
    count = count(),
    avg_duration = avg(duration),
    p95_duration = percentile(duration, 95),
    p99_duration = percentile(duration, 99),
    by:{gen_ai.operation.name, gen_ai.system}
| sort count desc
```

### Find RAG operations by data source
```dql
fetch spans, from:now()-12h
| filter isNotNull(gen_ai.data_source.id)
| fields timestamp, span.name, service.name, gen_ai.agent.name, gen_ai.data_source.id, duration
| sort timestamp desc
```

### Analyze agent workflows
```dql
fetch spans, from:now()-6h
| filter traceloop.span.kind == "workflow" or gen_ai.operation.name == "invoke_agent" or gen_ai.operation.name == "execute_tool"
| fields timestamp, span.name, service.name, traceloop.span.kind, openinference.span.kind, gen_ai.agent.name, gen_ai.tool.name, duration
| sort timestamp desc
```

### Filter by trace ID with GenAI spans
```dql
fetch spans
| filter trace.id == toUid("da8b40502d44451c2e1b9c42cf3b746a")
| fields span.name, service.name, gen_ai.request.model, gen_ai.system, gen_ai.usage.input_tokens, gen_ai.usage.output_tokens, duration
```

### Find models by provider/system
```dql
fetch spans, from:now()-24h
| filter gen_ai.system == "openai" or gen_ai.system == "anthropic" or gen_ai.system == "aws.bedrock"
| summarize count = count(), by:{gen_ai.system, gen_ai.request.model}
| sort count desc
```

### Analyze finish reasons
```dql
fetch spans, from:now()-12h
| filter isNotNull(gen_ai.response.finish_reasons)
| summarize count = count(), by:{gen_ai.response.finish_reasons, gen_ai.request.model}
| sort count desc
```

### Find guardrail-triggered requests (AWS Bedrock)
```dql
fetch spans, from:now()-24h
| filter isNotNull(aws.bedrock.guardrail.id)
| fields timestamp, span.name, service.name, aws.bedrock.guardrail.id, gen_ai.request.model, duration
| sort timestamp desc
```

### Token usage time series
```dql
fetch spans, from:now()-24h
| filter isNotNull(gen_ai.usage.input_tokens)
| makeTimeseries 
    total_input = sum(gen_ai.usage.input_tokens),
    total_output = sum(gen_ai.usage.output_tokens),
    interval:1h,
    by:{service.name}
```

### Find slow GenAI operations
```dql
fetch spans, from:now()-6h
| filter isNotNull(gen_ai.operation.name)
| filter duration > 5000000000
| fields timestamp, span.name, service.name, gen_ai.operation.name, gen_ai.request.model, duration
| sort duration desc
```

### Analyze temperature settings
```dql
fetch spans, from:now()-24h
| filter isNotNull(gen_ai.request.temperature)
| summarize 
    count = count(),
    avg_temp = avg(gen_ai.request.temperature),
    by:{gen_ai.request.model, service.name}
| sort count desc
```

### Vector database operations (Weaviate, Pinecone, etc.)
```dql
fetch spans, from:now()-6h
| filter contains(span.name, "weaviate") or contains(span.name, "pinecone") or contains(span.name, "chroma")
| fields timestamp, span.name, service.name, span.kind, duration
| sort timestamp desc
```

## Common Use Cases

### Debugging RAG Performance
1. Find the root span (API endpoint)
2. Use `trace.id` with `toUid()` to get all spans in the trace
3. Filter for vector DB operations (weaviate, pinecone, chroma)
4. Filter for GenAI operations (gen_ai.operation.name)
5. Compare durations to identify bottlenecks

### Cost Analysis
1. Query for spans with token usage
2. Aggregate by service, model, and time period
3. Calculate total tokens (input + output)
4. Apply provider pricing to estimate costs

### Quality Monitoring
1. Track finish_reasons to identify truncated responses
2. Monitor guardrail triggers
3. Analyze temperature and top_p settings
4. Correlate with user feedback or error rates

### Agent Workflow Analysis
1. Filter by `traceloop.span.kind` for workflows and by `gen_ai.operation.name` (`invoke_agent`, `execute_tool`) or `openinference.span.kind` for agents and tools
2. Examine tool usage patterns (`gen_ai.tool.name`)
3. Track agent handoffs and decision points
4. Measure end-to-end workflow duration

## Important Notes

- **Always use double quotes** for string literals in DQL (not single quotes)
- **Use `toUid()` function** when filtering by trace.id or span.id
- **Use `isNotNull()`** to filter for spans with GenAI attributes
- **Token fields are integers**, not floats (no decimals)
- **Duration is in nanoseconds** (divide by 1e9 for seconds)
- GenAI attributes follow [OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)