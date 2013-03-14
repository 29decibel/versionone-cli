### VersionOne Cli
[![endorse](http://api.coderwall.com/29decibel/endorsecount.png)](http://coderwall.com/29decibel)
----

![versionone-cli screenshot](http://i.imgur.com/RyRKmg5.png?1)

#### Install
```bash
$ npm install -g coffee-script
$ npm install -g versionone-cli
```

#### Simple use
```bash
# set up
$ v1 setup

# load members
$ v1 members -r

# get stories
$ v1 stories

# get tasks
$ v1 tasks -o mike -s complete

# get one task
$ v1 task -n 3322

# get one story
$ v1 story -n 3333

# update task
$ v1 update task -n 4444

```

#### run in dev
```bash
# get all tasks
$ PATH="node_modules/.bin:$PATH" ./bin/v1 tasks

# get specific task
$ PATH="node_modules/.bin:$PATH" ./bin/v1 task -n 4433
```

