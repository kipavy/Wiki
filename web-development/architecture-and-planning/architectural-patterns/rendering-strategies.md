# Rendering Strategies

### CSR (Client-Side)

The browser does the work (Standard React).

```mermaid
flowchart TD
    subgraph CSR ["Client-Side Rendering (CSR)"]
        Server1[Server] -- "1. Send Empty HTML + JS" --> Browser1[Browser]
        Browser1 -- "2. Browser executes JS" --> HTML1[3. User sees Content]
        style CSR fill:#fff4e6,stroke:#f60
    end
```

### SSR (Server-Side)

The server does the work per request (Next.js/Remix).

```mermaid
flowchart TD
    subgraph SSR ["Server-Side Rendering (SSR)"]
        Server2[Server] -- "1. Build HTML on fly" --> Browser2[Browser]
        Browser2 -- "2. Display HTML immediately" --> HTML2[3. Hydrate interactive JS]
        style SSR fill:#e6f7ff,stroke:#00f
    end
```

### SSG (Static Generation

The work is done once at build time (Gatsby/Astro).

```mermaid
flowchart TD
    subgraph SSG ["Static Site Generation (SSG)"]
        Build[Build Machine] -- "1. Generate HTML once" --> CDN[CDN/Storage]
        CDN -- "2. Serve pre-made HTML" --> Browser3[Browser]
        style SSG fill:#f0fff0,stroke:#0f0
    end
```
