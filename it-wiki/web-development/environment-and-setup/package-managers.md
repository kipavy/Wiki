# 📦 Package Managers

We choose **pnpm** (Performant NPM) over npm or Yarn for three critical reasons:

**1. Disk Space Efficiency (The "Magic")**

* **NPM/Yarn:** If you have 100 projects that use React, they download and save React **100 times** on your hard drive. This wastes gigabytes of space.
* **pnpm:** It saves React **exactly once** in a global store on your computer. All your projects just link to that one spot. It is instant and saves massive disk space.

**2. Speed**

Because pnpm links files instead of copying them, installing packages in a new project is nearly instantaneous if you have used those packages before.

**3. Safety (No Phantom Dependencies)**

* **NPM** creates a "flat" node\_modules folder. Sometimes, your code can import libraries you didn't actually install (dependencies of dependencies). This causes bugs that break in production.
* **pnpm** is strict. If you didn't add it to your package.json, you cannot import it.

{% embed url="https://pnpm.io/" %}

```shellscript
npm install -g pnpm
```
