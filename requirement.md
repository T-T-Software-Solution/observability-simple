### **Introduction: Observability Learning Platform Specification**

#### **1. Project Context and Objectives**

This document specifies the design of two web APIs—an `Upstream API` and a `Downstream API`—created for the express purpose of learning and demonstrating modern observability practices within the Microsoft Azure ecosystem.

The primary objective is to simulate a real-world microservice environment where performance issues can be intentionally introduced and then diagnosed. The goal is to use Azure Application Insights as a centralized platform for ingesting and correlating telemetry (logs, metrics, and traces), functioning as a "SIEM for performance" that provides a unified view across service boundaries.

#### **2. System Architecture**

The learning platform consists of three key components:

* **`Downstream API`:** Represents a backend service or a critical dependency (e.g., a data service, payment processor). It is intentionally designed to be the source of common performance problems, including latency, various error types, and resource exhaustion.
* **`Upstream API`:** Represents a public-facing gateway or a mid-tier business logic service that consumes the `Downstream API`. Its role is to handle incoming requests, delegate work to the downstream service, and correctly manage and report on the results, including any failures.
* **`Azure Application Insights`:** Serves as the central observability platform. It will be the single destination for all telemetry from both APIs, enabling the correlation of a single user request as it traverses the system.

#### **3. Learning Scenarios**

By implementing these specifications, a developer can create a hands-on lab environment to practice diagnosing the following critical scenarios:

* **Latency Analysis:** Pinpointing which service in a distributed call chain is responsible for slowness.
* **Root Cause Failure Analysis:** Tracing an error from the user-facing `Upstream API` back to the specific exception or failure in the `Downstream API`.
* **Resource Monitoring and Alerting:** Observing the impact of high CPU and memory usage in real-time and configuring proactive alerts based on performance metrics.

The following sections provide the detailed functional requirements for each API to enable these learning scenarios.

---

### **General Requirements**

1.  **Telemetry:** Both APIs MUST be instrumented with the Azure Application Insights SDK.
2.  **Correlation:** The instrumentation MUST be configured to ensure that distributed tracing context is automatically propagated from the `Upstream API` to the `Downstream API` on all HTTP calls.
3.  **Logging:** All logging MUST be structured, emitting key-value pairs for important contextual parameters (e.g., `failureMode`, `delayMs`) rather than plain text strings.

---

### **Downstream API Specification**

This service acts as a dependency and is the source of the simulated problems.

#### **Endpoint 1: Product Information Endpoint (Latency Simulation)**
* **Endpoint:** `GET /products/{id}`
* **Purpose:** To retrieve details for a specific product. This endpoint is designed to simulate variable response times, such as from a slow database.
* **Parameters:**
    * `id` (path, integer): The unique identifier for the product.
    * `delayMs` (query, integer, optional): The number of milliseconds to wait before sending a response. Defaults to 0.
* **Behavior:**
    1.  Upon receiving a request, the endpoint reads the `delayMs` parameter.
    2.  If `delayMs` is a positive integer, the service MUST pause execution for that duration.
    3.  After the potential delay, the service WILL return a success response.
* **Success Response:** `HTTP 200 OK` with a JSON object representing the product (e.g., `{ "productId": 123, "name": "..." }`).

#### **Endpoint 2: Order Creation Endpoint (Error Simulation)**
* **Endpoint:** `POST /orders`
* **Purpose:** To create a new order. This endpoint is designed to simulate different types of failures.
* **Parameters:**
    * `failureMode` (query, string, optional): Controls the failure behavior. Accepted values are `none`, `transient`, `persistent`. Defaults to `none`.
* **Behavior:**
    1.  The endpoint evaluates the `failureMode` parameter.
    2.  If `failureMode` is `none`, the endpoint WILL process the request successfully.
    3.  If `failureMode` is `transient`, the endpoint MUST fail on a probabilistic basis (e.g., 50% of the time). The failure should be a service-level error, not a critical application crash.
    4.  If `failureMode` is `persistent`, the endpoint MUST fail 100% of the time by generating an internal application exception.
* **Success Response:** `HTTP 201 Created` with a JSON object representing the order confirmation.
* **Failure Responses:**
    * For `transient` failures: `HTTP 503 Service Unavailable`.
    * For `persistent` failures: `HTTP 500 Internal Server Error`.

#### **Endpoint 3: CPU Pressure Endpoint**
* **Endpoint:** `GET /pressure/cpu`
* **Purpose:** To simulate a CPU-intensive operation.
* **Parameters:**
    * `iterations` (query, integer, optional): A number that controls the duration and intensity of the CPU load. Higher numbers result in more load.
* **Behavior:**
    1.  The endpoint MUST execute a computationally expensive, synchronous loop for a duration proportional to the `iterations` parameter.
    2.  After the computation is complete, it WILL return a success response.
* **Success Response:** `HTTP 200 OK` with a plain text or JSON message indicating completion.

#### **Endpoint 4: Memory Pressure Endpoint**
* **Endpoint:** `GET /pressure/memory`
* **Purpose:** To simulate a large memory allocation.
* **Parameters:**
    * `mbToAllocate` (query, integer, optional): The number of megabytes of memory to allocate.
* **Behavior:**
    1.  The endpoint MUST allocate and hold a data structure of the size specified by `mbToAllocate`.
    2.  The memory MUST be held for a fixed, short duration (e.g., 5-10 seconds) to allow monitoring systems to detect the increase.
    3.  After the hold duration, the memory MUST be dereferenced to allow for garbage collection.
* **Success Response:** `HTTP 200 OK` with a message indicating the amount of memory allocated and released.

---

### **Upstream API Specification**

This service acts as a public-facing gateway or a mid-tier service that consumes the `Downstream API`.

#### **Endpoint 1: Gateway Product Endpoint**
* **Endpoint:** `GET /gateway/products/{id}`
* **Purpose:** To expose product information by calling the `Downstream API`.
* **Parameters:**
    * `id` (path, integer): The product identifier.
    * `delayMs` (query, integer, optional): The delay to be passed to the downstream service.
* **Behavior:**
    1.  The endpoint MUST make an HTTP GET request to the `Downstream API`'s `/products/{id}` endpoint.
    2.  It MUST forward the `id` from its path and the `delayMs` parameter from its query string to the downstream call.
    3.  It MUST await the response from the `Downstream API` and forward the received payload and status code to its own caller.
* **Success Response:** Forwards the response from the `Downstream API` (e.g., `HTTP 200 OK`).
* **Failure Response:** If the downstream call fails (e.g., timeout, 5xx error), this endpoint MUST return an `HTTP 502 Bad Gateway` status.

#### **Endpoint 2: Gateway Order Endpoint**
* **Endpoint:** `POST /gateway/orders`
* **Purpose:** To expose order creation functionality by calling the `Downstream API`.
* **Parameters:**
    * `failureMode` (query, string, optional): The failure mode to be passed to the downstream service.
* **Behavior:**
    1.  The endpoint MUST make an HTTP POST request to the `Downstream API`'s `/orders` endpoint.
    2.  It MUST forward the `failureMode` parameter to the downstream call.
    3.  Crucially, it MUST implement robust error handling. If the call to the `Downstream API` fails (e.g., returns a non-2xx status code or throws a network exception), this event MUST be logged with structured context.
    4.  It will then return a gateway-specific error to its caller.
* **Success Response:** Forwards the response from the `Downstream API` (e.g., `HTTP 201 Created`).
* **Failure Response:** `HTTP 502 Bad Gateway`.