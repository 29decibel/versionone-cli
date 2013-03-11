### VersionOne Cli
----
#### ENV
```bash
export VERSION1_PASSWORD=your_version_one_password
export VERSION1_USERNAME=your_version_one_username
export API_HOST=www.somehost.com
```

#### Install
```bash
$ npm install -g coffee-script
$ npm install -g versionone-cli
```

#### Simple use
```bash
# setup members(first time with -r)
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

