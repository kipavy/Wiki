# Nice Extensions

[Error Lens by Alexander](https://marketplace.visualstudio.com/items?itemName=usernamehw.errorlens)

[Todo Tree](https://marketplace.visualstudio.com/items?itemName=Gruntfuggly.todo-tree) I recommend this [really nice config](https://dev.to/koustav/how-a-vs-code-extension-todo-tree-can-make-your-coding-easier-todo-tree-configuration-and-use-cases-11kc), here's mine that I tweaked a little bit (settings.json):

{% code overflow="wrap" fullWidth="false" %}
```json
"todo-tree.highlights.defaultHighlight": {
    "icon": "alert",
    "foreground": "black",
    "background": "white",
    "opacity": 50,
    "iconColour": "white",
    "gutterIcon": true
  },
  "todo-tree.highlights.customHighlight": {
    "TODO": {
      "icon": "checkbox",
      "foreground": "black",
      "background": "yellow",
      "iconColour": "yellow"
    },
    "NOTE": {
      "icon": "note",
      "foreground": "white",
      "background": "cornflowerblue",
      "iconColour": "cornflowerblue"
    },
    "USEFUL": {
      "icon": "verified",
      "foreground": "black",
      "background": "mediumaquamarine",
      "iconColour": "mediumaquamarine"
    },
    "COMMENT": {
      "icon": "comment",
      "foreground": "white",
      "background": "gray",
      "iconColour": "gray"
    },
    "LEARN": {
      "icon": "bookmark",
      "foreground": "white",
      "background": "hotpink",
      "iconColour": "hotpink"
    },
    "FIXME": {
      "icon": "tools",
      "foreground": "crimson",
      "background": "burlywood",
      "iconColour": "burlywood"
    },
    "RECHECK": {
      "icon": "codescan",
      "foreground": "white",
      "background": "chocolate",
      "iconColour": "chocolate"
    },
    "INCOMPLETE": {
      "icon": "alert",
      "foreground": "white",
      "background": "mediumvioletred",
      "iconColour": "mediumvioletred"
    },
    "BUG": {
      "icon": "bug",
      "foreground": "white",
      "background": "crimson",
      "iconColour": "crimson"
    },
    "SEE NOTES": {
      "icon": "note",
      "foreground": "white",
      "background": "teal",
      "iconColour": "teal"
    },
    "POST": {
      "icon": "share",
      "foreground": "white",
      "background": "green",
      "iconColour": "green"
    },
    "[ ]": {
      "icon": "check",
      "foreground": "black",
      "background": "yellow",
      "iconColour": "yellow"
    },
    "[x]": {
      "icon": "check",
      "foreground": "white",
      "background": "green",
      "iconColour": "green"
    }
  },
  "todo-tree.general.tags": [
    "BUG",
    "SEE NOTES",
    "HACK",
    "FIXME",
    "RECHECK",
    "INCOMPLETE",
    "TODO",
    "NOTE",
    "POST",
    "USEFUL",
    "LEARN",
    "COMMENT",
    "[ ]",
    "[x]"
  ],
  "todo-tree.regex.regex": "(//|#|<!--|;|/\\*|^|^\\s*(-|\\d+.))\\s*($TAGS).*(\\n\\s*//\\s{2,}.*)*"
```
{% endcode %}
