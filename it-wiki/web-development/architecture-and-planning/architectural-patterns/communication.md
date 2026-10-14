# Communication

### Async Event-Driven Architecture (Pub/Sub)

**The "Async" Pattern.**\
Useful when explaining background tasks (e.g., "User signs up, wait 5 minutes, then send welcome email"). This explains why we use tools like RabbitMQ, Kafka, or Redis.

* **The Concept:** Fire and Forget. The "Order Service" doesn't wait for the "Email Service" to finish. It just drops a message in a box (Queue).

| **✅ Performance:** User gets an instant "Success" response; heavy work happens in the background.              | **❌ Complexity:** Requires setting up and monitoring Message Queues (RabbitMQ/Redis).                 |
| -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **✅ Resilience:** If the Email Service is down, the message stays in the Queue until it comes back online.     | **❌ Hard to Debug:** Tracing a bug is harder because the logic jumps between different servers/times. |
| **✅ Traffic Smoothing:** Spikes in traffic just fill up the queue; your servers process them at a steady pace. | **❌ "Eventual Consistency":** The user might refresh the page and not see the result immediately.     |

```mermaid
flowchart LR
    User((User))
    ServiceA[🛒 Order Service]
    Queue{📬 Message Queue}
    ServiceB[📧 Email Service]
    ServiceC[📦 Inventory Service]
    
    User -- "Place Order" --> ServiceA
    ServiceA -- "Publish: 'OrderCreated'" --> Queue
    
    Queue -.->|"Subscribe"| ServiceB
    Queue -.->|"Subscribe"| ServiceC
    
    ServiceB -- "Send Email" --> User
    ServiceC -- "Update Stock" --> DB[(Stock DB)]
```

### Sync (HTTP/REST)

| **✅ Simplicity:** Easy to write and reason about (Step 1 -> Step 2 -> Step 3).                       | **❌ Latency:** The user has to wait for everything to finish (slow page loads).              |
| ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **✅ Immediate Feedback:** You know instantly if the operation failed (e.g., "Credit Card Declined"). | **❌ Coupling:** If one service (e.g., Email) goes down, the whole checkout process crashes.  |
| **✅ No Infrastructure:** You don't need to manage Redis, RabbitMQ, or Kafka.                         | **❌ Cascading Failures:** A traffic spike in Service A creates a traffic spike in Service B. |

```mermaid
flowchart LR
    User((User))
    ServiceA[🛒 Order Service]
    ServiceB[📧 Email Service]
    ServiceC[📦 Inventory Service]
    DB[(Stock DB)]
    
    %% 1. The User initiates
    User -- "1. Place Order (Wait...)" --> ServiceA
    
    %% 2. Service A is now "The Boss" (and the bottleneck)
    ServiceA -- "2. POST /update-stock (Wait...)" --> ServiceC
    ServiceC -- "3. Update Stock" --> DB
    
    %% 3. Service A cannot continue until step 3 finishes
    ServiceA -- "4. POST /send-email (Wait...)" --> ServiceB
    ServiceB -- "5. Send Email" --> User
    
    %% 4. Finally return to user
    ServiceA -.-> |"6. 200 OK (Finally)"| User
```
