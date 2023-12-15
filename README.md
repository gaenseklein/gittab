# gittab

atom like git-tab for micro

early WIP, only shows Git-Status of files right now

## Installation

### Settings

Add this repo as a **pluginrepos** option in the **~/.config/micro/settings.json** file (it is necessary to restart the micro after this change):

```json
{
  "pluginrepos": [
      "https://raw.githubusercontent.com/gaenseklein/gittab/main/repo.json"
  ]
}
```

### Install

In your micro editor press **Ctrl-e** and run command:

```
> plugin install gittab
```

or run in your shell

```sh
micro -plugin install gittab
```
