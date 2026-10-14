# MVC

> **Verdict:** The default way to organize backend code. If you're not sure how to structure a server, start here.

**MVC (Model–View–Controller)** splits your code into three jobs so no single file does everything:

* **Model** — the data and the rules around it (e.g. the `User` table and how to query it).
* **View** — the output the client receives (JSON for an API, or an HTML page).
* **Controller** — the "brain" that takes a request, asks the Model for data, and hands it to the View.

The point is **separation of concerns**: your data logic doesn't get tangled up with your formatting logic, so each part stays easy to change and test. Most backend frameworks (Django, Laravel, Rails, NestJS) are built around some flavor of this.

```mermaid
flowchart LR
    subgraph Client
        Browser
    end

    subgraph Server ["Backend (MVC Pattern)"]
        direction TB
        Controller["<b>Controller</b><br/>(The Brain)"]
        Model["<b>Model</b><br/>(The Data)"]
        View["<b>View</b><br/>(The Output)"]

        Controller -- "1. Ask for data" --> Model
        Model -- "2. Return data" --> Controller
        Controller -- "3. Send to formatter" --> View
    end

    Browser -- "Request" --> Controller
    View -- "JSON/HTML" --> Browser

    style Server fill:#f9f9f9,stroke:#333
    style Controller fill:#e1f5fe,stroke:#01579b
    style Model fill:#fff3e0,stroke:#e65100
    style View fill:#e8f5e9,stroke:#1b5e20
```
