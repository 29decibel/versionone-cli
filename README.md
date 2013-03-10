### VersionOne Cli
----
#### ENV
```bash
export VERSION1_PASSWORD=your_version_one_password
export VERSION1_USERNAME=your_version_one_username
export API_HOST=www.somehost.com
```

#### run
```bash
# get all tasks
$ PATH="node_modules/.bin:$PATH" ./bin/v1 tasks

# get specific task
$ PATH="node_modules/.bin:$PATH" ./bin/v1 task -n 4433
```

