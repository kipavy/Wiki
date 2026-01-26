# Monolith vs. Microservices

**Monolith**

* **What is it?** All code (Frontend, API, Background Workers) lives in one repository and deploys together.
* **✅ Pros:** Easy to debug, easy to deploy, simple local development.
* **❌ Cons:** If one part breaks, everything breaks. Hard for 50+ developers to work on at once.
* **Verdicts:** Start here. 90% of apps should be monoliths.

**Microservices**

* **What is it?** Breaking the app into distinct services (e.g., a specific server just for PDF generation).
* **✅ Pros:** Scaling is precise (add more servers just for the busy part). Teams are independent.
* **❌ Cons:** "Distributed Monolith" hell. Extremely hard to debug. Requires DevOps experts.
* **Verdict:** Only use if you have 50+ developers or distinct scaling needs.

**Serverless**

* **What is it?** You don't manage servers. You upload functions (AWS Lambda, Vercel) that run only when triggered.
* **✅ Pros:** Infinite scaling, pay only for what you use ($0 if no users).
* **❌ Cons:** Cold starts (can be slow), vendor lock-in (hard to move off AWS).
* **Verdict:** Great for frontend-focused teams and side projects.

```mermaid
block-beta
  columns 3
  
  block:Mono
    columns 1
    Label1["MONOLITH"]
    Box1["[ UI + API + Jobs ]"]
    DB1[("Shared DB")]
    Box1 --> DB1
  end

  block:Micro
    columns 1
    Label2["MICROSERVICES"]
    block:Services
        S1["Auth"] S2["Billing"] S3["Products"]
    end
    block:DBs
        D1[("DB")] D2[("DB")] D3[("DB")]
    end
    S1 --> D1
    S2 --> D2
    S3 --> D3
  end

  block:Serverless
    columns 1
    Label3["SERVERLESS"]
    Func1(("Function A"))
    Func2(("Function B"))
    Func3(("Function C"))
    DB4[("Managed DB")]
    Func1 --> DB4
    Func2 --> DB4
  end

  style Mono fill:#f9f9f9,stroke:#333
  style Micro fill:#e6f7ff,stroke:#00f
  style Serverless fill:#fff4e6,stroke:#f60
```
