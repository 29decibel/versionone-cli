
xml2js = require('xml2js')
_ = require('underscore')
_s = require('underscore.string')
cheerio = require('cheerio')
https = require('https')
Util = require "util"
Fs       = require 'fs'
Yaml = require('js-yaml') # parse the yaml config and members

username = process.env.VERSION1_USERNAME
password = process.env.VERSION1_PASSWORD
api_host = process.env.API_HOST

red   = '\u001b[31m'
blue  = '\u001b[34m'
yellow = '\u001b[33m'
reset = '\u001b[0m'

getAttr = (asset, attrName) =>
  name = _.select asset.Attribute, (att)->
    att['@']?.name == attrName
  name[0]?['#']

getRelation = (asset, relationName) =>
  name = _.select asset.Relation, (att)->
    att['@']?.name == relationName
  name[0].Asset

v1_options = {
  hostname: "www14.v1host.com"
  port: 443
  auth: "#{username}:#{password}"
  path: '/'
  method: 'GET'
}

members_yaml = process.env['HOME'] + "/.v1_members.yaml"

class Story
  constructor:(asset)->
    @asset = asset
    @id = @asset['@']['id']
    @name = getAttr(@asset, 'Name')
    @number = getAttr(@asset, 'Number')
    @sprint = getAttr(@asset, "Timebox.Name") || ""
    @description = getAttr(@asset, "Description")?.replace(/(<([^>]+)>)/ig,"").replace('&nbsp','') || ''
    @todo = getAttr(@asset, "ToDo") || '-'
    @estimate = getAttr(@asset, "DetailEstimate") || '-'

  @find: (story_id, callback)->
    https.get "https://#{username}:#{password}@#{api_host}/VersionOne/rest-1.v1/Data/Story/#{story_id}", (res)->
      resultStr = ""
      # append data to result
      res.on "data", (data)->
        resultStr += data.toString()
      # yeah! got the result
      res.on "end", (data) ->
        parser = new xml2js.Parser()
        parser.parseString resultStr, (err, result)->
          callback(new Story(result))


  @all: (callback)->
    https.get "https://#{username}:#{password}@#{api_host}/VersionOne/rest-1.v1/Data/Story?where=Timebox.Name='MVP 1.0 Sprint 13'", (res)->
      resultStr = ""
      # append data to result
      res.on "data", (data)->
        resultStr += data.toString()
      # yeah! got the result
      res.on "end", (data) ->
        parser = new xml2js.Parser()
        parser.parseString resultStr, (err, result)->
          tasks =  _.map result.Asset,(t)->
            console.log "-----------------------------------"
            console.log Util.inspect(t, false, 4)
            new Story(t)
          callback(tasks)
  toString:->
    unless @id
      return "Not Found..."
    str = ""
    str += yellow + "  #{@number} #{@name}(#{@id})\n" + reset
    str += "#{blue}->#{reset} SPRT: #{@sprint}\n"
    str += "#{blue}->#{reset} DESC: #{@description[0..100]}"  + "\n" + reset
    str += "#{blue}->#{reset} TASK: #{@tasks}"  + "\n" + reset
    str

class Task
  constructor:(asset)->
    unless asset['@']['id']
      return
    @asset = asset
    @name = getAttr(@asset, 'Name')
    @number = getAttr(@asset, 'Number')
    @sprint = getAttr(@asset, "Timebox.Name") || ""
    @id = @asset['@']['id']
    @parent_id = getRelation(@asset, "Parent")['@']['idref']?.split(":")[1]
    try
      @status_id = getRelation(@asset, 'Status')['@']['idref']
    catch error
      @status_id = "! not know"
    finally
      # do nothing
    @status = @getStatus(@status_id) || ""
    try
      owners = getRelation(@asset, 'Owners')
      if owners['length'] > 0
        ids = _.map owners,(owner)->
          Task.cached_members()[owner['@']['idref']]
        @member = ids.join(',')
      else
        @member = Task.cached_members()[owners['@']['idref']]
    catch error
      @member_id = null
    @member ||= ""
    @team = getAttr(@asset, "Team.Name")
    @sprint = getAttr(@asset, "Timebox.Name")
    @scope = getAttr(@asset, "Scope.Name")
    @todo = getAttr(@asset, "ToDo") || '-'
    @estimate = getAttr(@asset, "DetailEstimate") || '-'
    @description = getAttr(@asset, "Description")?.replace(/(<([^>]+)>)/ig,"").replace('&nbsp','') || ''

  getStatus: (status_id) =>
    map = {
      "TaskStatus:123": "In Progress"
      "TaskStatus:125": "Complete"
      "TaskStatus:37514": "Ready for Test"
      "TaskStatus:37513": "Not Started"
    }
    map[status_id]

  # update task hours
  @updateAttribute: (taskid,attrName,attrValue,callback)->
    body = """
      <Asset>
        <Attribute name="#{attrName}" act="set">#{attrValue}</Attribute>
      </Asset>
    """
    @post(taskid,body,callback)


  # make task complete
  @complete: (taskid,callback)->
    body = """
        <Asset>
          <Relation name="Status" act="set">
            <Asset href="/acxiom1/VersionOne/rest-1.v1/Data/TaskStatus/125" idref="TaskStatus:125"/>
          </Relation>
        </Asset>
    """
    @post(taskid,body,callback)

  # make the post request
  @post: (taskid,body,callback)->
    ops = _.extend(v1_options, { path:"/acxiom1/VersionOne/rest-1.v1/Data/Task/#{taskid}", method: 'POST' })
    req = https.request ops, (response)->
      result = ""
      response.on 'data', (chunk)->
        result += chunk
      response.on 'end',()->
        callback(result)
    req.write(_s.trim(body))
    req.end()


  @find: (taskid, callback)->
    https.get "https://#{username}:#{password}@#{api_host}/VersionOne/rest-1.v1/Data/Task/#{taskid}", (res)->
      resultStr = ""
      # append data to result
      res.on "data", (data)->
        resultStr += data.toString()
      # yeah! got the result
      res.on "end", (data) ->
        parser = new xml2js.Parser()
        parser.parseString resultStr, (err, result)->
          callback(new Task(result))

  @cached_members: ->
    contents = Fs.readFileSync(members_yaml)
    Yaml.load(contents.toString())

  @members: (reload = false, callback)->
    unless reload
      callback(@cached_members())
    else
      members = {}
      # cache memebers first
      https.get "https://#{username}:#{password}@#{api_host}/VersionOne/rest-1.v1/Data/Member", (res)->
        result = ""
        # append data to result
        res.on "data", (data)->
          result += data.toString()
        # yeah! got the result
        res.on "end", (data) ->
          parser = new xml2js.Parser()
          parser.parseString result, (err, result)->
            for mem in result.Asset
              members[mem['@'].id] = getAttr(mem,"Name")
            # dump members to yaml file
            Fs.writeFile members_yaml, Yaml.dump(members), (err)->
              console.log ("can not cache members: #{err}") if err
            callback(members)

  @all: (callback)->
    https.get "https://#{username}:#{password}@#{api_host}/VersionOne/rest-1.v1/Data/Task?where=Timebox.Name='MVP 1.0 Sprint 13'", (res)->
      resultStr = ""
      # append data to result
      res.on "data", (data)->
        resultStr += data.toString()
      # yeah! got the result
      res.on "end", (data) ->
        parser = new xml2js.Parser()
        parser.parseString resultStr, (err, result)->
          tasks =  _.map result.Asset,(t)->
            new Task(t)
          callback(tasks)

  toString: =>
    unless @id
      return "Not Found..."
    str = ""
    str += yellow + "  #{@number} #{@name}(#{@id})\n" + reset
    str += "#{blue}->#{reset} #{@member}" + "\n"
    str += "#{blue}->#{reset} #{@status}" + "\n"
    str += "#{blue}->#{reset} ESTI: " + @estimate + "\n"
    str += "#{blue}->#{reset} TODO: #{@todo}\n"
    str += "#{blue}->#{reset} SPRT: #{@sprint}\n"
    str += "#{blue}->#{reset} DESC: #{@description}"  + "\n" + reset
    str


module.exports =
  Story: Story
  Task: Task
