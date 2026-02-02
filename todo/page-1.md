# Page 1

[quickstart.md](../web-development/environment-and-setup/quickstart.md "mention")

[Broken link](/broken/pages/jAkeRTUA7mGL8tabdh3D "mention")

[backend](../web-development/backend/ "mention")

[deployment-and-devops.md](../web-development/deployment-and-devops.md "mention")

[architecture-and-planning](../web-development/architecture-and-planning/ "mention")



Self host:

hugging face: new space -> Docker Blank

(serveurs off en inactivité)

Create Dockerfile with EXPOSE 7860 (make sure your app uses port 7860)\
[https://\<username>-\<space\_name>.hf.space/](https://albertoricoco-jackett.hf.space/UI/Dashboard)



self-host [https://github.com/antonreshetov/mysigmail](https://github.com/antonreshetov/mysigmail) (pas de limitations: changements de couleurs...):

```shellscript
docker run --rm -it -p 5173:5173 node:lts-alpine sh -c "apk add git bash curl && curl -fsSL https://bun.com/install | bash && export BUN_INSTALL=\$HOME/.bun && export PATH=\$BUN_INSTALL/bin:\$PATH && git clone https://github.com/antonreshetov/mysigmail && cd mysigmail && bun install && npx vite --host"
```



New group: Network (move Self host in Network)
