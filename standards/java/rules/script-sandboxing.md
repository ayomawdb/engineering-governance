---
description: Sandbox adaptive authentication scripts and Script Mediator to prevent RCE
globs:
  - "**/*Script*"
  - "**/*Nashorn*"
  - "**/*GraalJS*"
  - "**/*ScriptEngine*"
  - "**/*Adaptive*"
  - "**/*Mediator*"
alwaysApply: false
---

# Script Execution Sandboxing

WSO2 products have had 3+ RCE flaws via script engines.

- **MUST** sandbox adaptive authentication scripts and Script Mediator execution — restrict access to `Runtime`, filesystem, and network APIs.
- **MUST** use restricted classloaders for any user-configurable script execution.

## Dangerous Classes to Block

`Runtime`, `ProcessBuilder`, `System`, `Thread`/`ThreadGroup`, `java.lang.reflect.*`, `java.io.File`/`java.nio.file.*`, `Socket`/`URL`/`HttpURLConnection`, `ScriptEngineManager`, `ClassLoader` and subclasses.

## Sandbox Configuration

- **GraalJS**: `Context.newBuilder("js").allowHostAccess(HostAccess.NONE).allowHostClassLookup(s -> false).allowIO(false).build()`
- **Nashorn** (legacy, removed JDK 15 — migrate to GraalJS): `new NashornScriptEngineFactory().getScriptEngine(new String[]{"--no-java"}, null, className -> false)`

## Resource Limits

- Enforce execution timeouts to prevent infinite loops / DoS.
- Limit memory allocation where the engine supports it.
- Log script execution failures — repeated failures may indicate probing.
