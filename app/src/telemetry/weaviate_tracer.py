"""Dedicated TracerProvider for Weaviate spans.

Weaviate spans are emitted with service.name="weaviate" so that Dynatrace
creates a separate service entity and shows the call relationship:
  ai-travel-advisor -> weaviate

A second TracerProvider is required because service.name is a Resource
attribute — it cannot be overridden per-span within a single provider.
The global provider (set up by Traceloop) carries service.name="ai-travel-advisor".
"""

from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

_weaviate_provider: TracerProvider | None = None


def init_weaviate_tracer_provider(otlp_endpoint: str, insecure: bool) -> TracerProvider:
    """Initialize the Weaviate TracerProvider and return it.

    Must be called after Traceloop/OTel is initialized so the exporter
    endpoint is already resolved.  Uses Resource directly (not .create())
    so OTEL_SERVICE_NAME from the container env does not override the value.
    """
    global _weaviate_provider
    resource = Resource({"service.name": "weaviate"})
    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=insecure)
    provider.add_span_processor(BatchSpanProcessor(exporter))
    _weaviate_provider = provider
    return provider


def get_weaviate_tracer():
    """Return a tracer from the Weaviate provider, or None if not initialized.

    Returns None when OPENLLMETRY_ENABLED=false or OTel init failed, so
    callers can fall back gracefully:
        tracer = get_weaviate_tracer() or trace.get_tracer("fallback")
    """
    if _weaviate_provider is None:
        return None
    return _weaviate_provider.get_tracer("weaviate")
