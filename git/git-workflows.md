# Git Workflows

### Gitflow

```mermaid
gitGraph
   commit id: "Initial Commit"
   branch develop
   checkout develop
   commit id: "Init Develop"
   
   %% Feature Branch Workflow
   branch feature/login
   checkout feature/login
   commit id: "Start Login"
   commit id: "Finish Login"
   checkout develop
   merge feature/login id: "Merge Feature"
   
   %% Release Workflow
   branch release/v1.0
   checkout release/v1.0
   commit id: "Bump Version"
   commit id: "Fix Minor Bug"
   checkout main
   merge release/v1.0 tag: "v1.0"
   checkout develop
   merge release/v1.0
   
   %% Hotfix Workflow
   checkout main
   branch hotfix/v1.0.1
   commit id: "Critical Fix"
   checkout main
   merge hotfix/v1.0.1 tag: "v1.0.1"
   checkout develop
   merge hotfix/v1.0.1
```

### Github Flow

This is the most popular alternative to Gitflow. It is much simpler because it removes the develop branch. It is designed for web applications where you deploy to production many times a day.

```mermaid
gitGraph
   commit id: "Prod v1.0"
   
   %% Feature Start
   branch feature/login
   checkout feature/login
   commit id: "Draft Login"
   commit id: "Finalize Login"
   
   %% Pull Request & Merge
   checkout main
   merge feature/login id: "Deploy v1.1" tag: "v1.1"
   
   %% Quick Fix
   branch bugfix/header
   checkout bugfix/header
   commit id: "Fix CSS"
   checkout main
   merge bugfix/header id: "Deploy v1.2" tag: "v1.2"
```

### Trunk-based

This is the workflow used by high-performance teams (Google, Facebook, Netflix). The goal is to avoid "merge hell" by keeping branches incredibly short-lived (often less than a day).

```mermaid
gitGraph
   commit id: "Start"
   
   %% Developer 1
   branch feat-A
   checkout feat-A
   commit id: "Part of A"
   checkout main
   merge feat-A
   
   %% Developer 2
   branch feat-B
   checkout feat-B
   commit id: "Part of B"
   checkout main
   merge feat-B
   
   %% Developer 1 again
   branch feat-A-2
   checkout feat-A-2
   commit id: "Finish A"
   checkout main
   merge feat-A-2 tag: "Release"
```
