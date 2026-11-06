# Backend and library specification for 1.0

## Library resolution

Resolve each BCL or third-party use against the bound symbol and selected target framework. The mapping key includes assembly or package identity, version range, fully qualified type, generic arity, member name and parameter types. Prefer direct Goose operations, then a versioned DotGoose module, then opted-in source conversion. Keep native and compatibility dependencies explicit in generated imports. Stage the required library beside the output, or use a relative source import for the starter. Conversion reports record the original symbol, selected mapping and semantic restrictions.

| Area | Required behavior and acceptance |
| --- | --- |
| Text and numeric types | Preserve UTF-16 indexing, surrogate behavior, ordinal comparisons, culture-aware operations, checked/unchecked overflow, remainder and decimal precision. Use UTF-8 only at explicit encoding boundaries or with proof that it preserves the operation. |
| Arrays and collections | Preserve value/reference semantics, bounds, comparer behavior, ordering where promised and enumerator invalidation. Cover arrays, spans, `List<T>`, `Dictionary<TKey,TValue>`, `HashSet<T>` and queues. |
| LINQ | Lower common pipelines to loops or typed iterators. Preserve deferred evaluation, short-circuiting, enumeration order, repeated enumeration and disposal. |
| Objects and types | Use direct calls for concrete types, tagged variants for closed polymorphism and handles where identity or lifetimes require them. Cover constructors, initializers, records, properties, delegates, interfaces, generics, pattern matching, nullable types, equality and boxing where needed. |
| Exceptions and disposal | Lower exceptions to typed failure paths where call graphs permit. Preserve catch selection, filters, finally ordering, using/disposal and rethrow semantics. Diagnose unmodeled exception edges. |
| Async and concurrency | Introduce explicit state machines and a defined executor. Test await order, fault and cancellation propagation, async disposal and queue boundaries. Preserve shared mutable behavior only when the selected runtime defines it. |
| System services | Cover paths, files, streams, process/environment, time, JSON, HTTP clients and cryptography. Define platform and cancellation contracts for each adapter. Differential tests compare data, errors and resource cleanup. |
| Curated packages | Start with selected surfaces of Newtonsoft.Json, Serilog and Dapper. Match documented options and errors, preserve applicable licenses and publish per-version coverage. Validate fixtures against the original packages. |

## NuGet and project conversion

Load SDK-style projects with resolved source, options and package graphs. Restore only when explicitly enabled. Pin package IDs, versions, dependency hashes, target frameworks and sources. Check curated mappings first. For an unmapped dependency, acquire the exact package and its permitted C# source through source files shipped in the package or verifiable repository metadata or [Source Link](https://learn.microsoft.com/dotnet/standard/library-guidance/sourcelink). A binary assembly supplies binding metadata. Its presence alone cannot establish source availability.

Check package and source provenance before translating. Apply source allowlists, reject unsafe archive paths and enforce extraction limits. Never run downloaded build tasks, analyzers, generators or package scripts as part of source inspection. Compile eligible source through the same native frontend and lowering pipeline as the app. Emit actionable diagnostics for unavailable source, licensing restrictions, target-framework mismatches or unsupported code. Report the package/version and the failing symbol. Cache verified inputs by hash and provide a locked offline mode. Preserve notices and attribution in any redistributed generated code. A package fixture must cover a curated mapping, a successful source conversion and the binary-only failure path.

## ASP.NET Core acceptance application

Ship a runnable Linux server port with an original ASP.NET Core application and equivalent Goose program. Start with Kestrel-style hosting and minimal APIs, then add routing, middleware order, model binding and validation, DI lifetimes, configuration, JSON, structured logs, health checks, authentication/authorization and graceful shutdown. A maintained native transport may provide sockets and TLS. Define the transport ABI, request lifetime, body limits, backpressure and cancellation. Record the supported subset by API and platform.

The acceptance suite runs the same requests against both servers and compares status, headers and response body. At minimum, `GET /healthz` returns HTTP 200 and health JSON, `GET /api/items/42?includeDetails=true` returns item 42 with its details, and `POST /api/items` validates JSON and returns HTTP 201 for a valid item or HTTP 400 for invalid input. Test concurrent clients, per-request service disposal, oversized requests, missing credentials, handler exceptions and shutdown with active requests.
