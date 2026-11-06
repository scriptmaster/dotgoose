# Windows platform specification for 2.0

The Windows profile builds on the C# frontend and compatibility library from 1.0. Start with Windows SDK bindings and Win32 desktop samples, then add COM/WinRT and framework-specific desktop adapters. Publish a coverage matrix by SDK version, architecture and supported APIs.

| Area | Required behavior and acceptance |
| --- | --- |
| SDK projection and P/Invoke | Consume Windows SDK metadata for allowlisted APIs. Verify ABI sizes, alignment, packing, calling conventions, UTF-16 strings, buffer sizing, callbacks and error codes on Windows x64 and ARM64. |
| Win32 | Wrap handles with explicit ownership. Preserve close order, message-loop and thread affinity. Verify a window creation and teardown sample, file dialogs, registry and Windows service lifecycle. |
| COM and WinRT | Model interface IDs, HRESULTs, reference counts, apartment rules, events and async boundaries. Validate activation and disposal from both supported apartment models. |
| Desktop frameworks | Evaluate WinForms, WPF and WinUI against a window, layout, event, binding and resource sample each. Record the supported framework and API subset. Surface unsupported XAML, designer or reflection requirements with source locations. |
| Packaging and integration | Verify native dependencies, manifests, DPI awareness and installers or MSIX where applicable. Run acceptance tests on Windows with the documented SDK and architecture. |
