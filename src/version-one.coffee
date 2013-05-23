
xml2js = require('xml2js')
_ = require('underscore')
_s = require('underscore.string')
cheerio = require('cheerio')
https = require('https')
Util = require "util"
Fs       = require 'fs'
Yaml = require('js-yaml') # parse the yaml config and members
Url = require('url')
# make the output colorful
Colors = require('colors')
# for percentage process bar
multimeter = require('multimeter')
multi = multimeter(process)

members_yaml = process.env['HOME'] + "/.v1_members.yaml"

# load common config
config_yaml = process.env['HOME'] + "/.v1_config.yaml"
# default config
V1Config =
  where: ""
  username: ""
  password: ""
  api_host: ""
# make sure the config exist
unless Fs.existsSync(config_yaml)
  Fs.writeFileSync config_yaml, Yaml.dump(V1Config)
else
  # laod the config
  contents = Fs.readFileSync(config_yaml)
  V1Config = Yaml.load(contents.toString())


getAttr = (asset, attrName) =>
  name = _.select asset.Attribute, (att)->
    att['@']?.name == attrName
  name[0]?['#']

getRelation = (asset, relationName) =>
  name = _.select asset.Relation, (att)->
    att['@']?.name == relationName
  name[0].Asset


https_req_options = {
  hostname: Url.parse("https://" + V1Config.api_host).host
  port: 443
  auth: "#{V1Config.username}:#{V1Config.password}"
  path: '/'
  method: 'GET'
}


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
    https.get "https://#{V1Config.username}:#{V1Config.password}@#{V1Config.api_host}/VersionOne/rest-1.v1/Data/Story/#{story_id}", (res)->
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
    https.get "https://#{V1Config.username}:#{V1Config.password}@#{V1Config.api_host}/VersionOne/rest-1.v1/Data/Story?where=#{V1Config.where}", (res)->
      resultStr = ""
      # append data to result
      res.on "data", (data)->
        resultStr += data.toString()
      # yeah! got the result
      res.on "end", (data) ->
        parser = new xml2js.Parser()
        parser.parseString resultStr, (err, result)->
          tasks =  _.map result.Asset,(t)->
            console.log Util.inspect(t, false, 4)
            new Story(t)
          callback(tasks)

  toString:->
    unless @id
      return "Not Found..."
    str = "\n"
    str += "  ".white + "#{@number} #{@name}(#{@id})\n".cyan.underline
    # str += "#{blue}->#{reset} SPRT: #{@sprint}\n"
    str += "->".blue + " DESC: #{@description[0..100]}"  + "\n"
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
    @parent_id = _s.trim(getRelation(@asset, "Parent")['@']['idref']?.split(":")[1])
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
    @todo = parseInt(getAttr(@asset, "ToDo")) || 0
    @estimate = parseInt(getAttr(@asset, "DetailEstimate")) || 0
    @done = @estimate - @todo
    @description = getAttr(@asset, "Description")?.replace(/(<([^>]+)>)/ig,"").replace('&nbsp','') || ''

  @statusMap:
    "TaskStatus:123": "In Progress"
    "TaskStatus:125": "Complete"
    "TaskStatus:37514": "Ready for Test"
    "TaskStatus:37513": "Not Started"

  getStatus: (status_id) =>
    Task.statusMap[status_id]

  @statusId: (statusName)->
    map = {
      "In Progress"    : "TaskStatus:123"
      "Complete"       : "TaskStatus:125"
      "Ready for Test" : "TaskStatus:37514"
      "Not Started"    : "TaskStatus:37513"
    }
    map[statusName]


  # update attributes
  @updateAttribute: (taskid,attrName,attrValue,callback)->
    body = """
      <Asset>
        <Attribute name="#{attrName}" act="set">#{attrValue}</Attribute>
      </Asset>
    """
    @post(taskid,body,callback)

  # update relation
  @updateRelation: (taskid, relationName, value, callback)->
    body = """
      <Asset>
        <Relation name="#{relationName}" act="set">
          <Asset idref="#{value}" />
        </Relation>
      </Asset>
    """
    @post(taskid,body,callback)


  # make the post request
  @post: (taskid,body,callback)->
    url = "https://#{V1Config.api_host}/VersionOne/rest-1.v1/Data/Task/#{taskid}"
    ops = _.extend(https_req_options, { path:Url.parse(url).path, method: 'POST' })
    req = https.request ops, (response)->
      result = ""
      response.on 'data', (chunk)->
        result += chunk
      response.on 'end',()->
        # parse result
        Task.parseUpdateResult(result, callback)
    req.write(_s.trim(body))
    req.end()

  @parseUpdateResult: (result, callback)->
    parser = new xml2js.Parser()
    parser.parseString result, (err, result)->
      callback(result.Exception?.Message || "Updated success!")


  @find: (taskid, callback)->
    https.get "https://#{V1Config.username}:#{V1Config.password}@#{V1Config.api_host}/VersionOne/rest-1.v1/Data/Task/#{taskid}", (res)->
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
      https.get "https://#{V1Config.username}:#{V1Config.password}@#{V1Config.api_host}/VersionOne/rest-1.v1/Data/Member", (res)->
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

  @all: (whereClause, callback)->
    https.get "https://#{V1Config.username}:#{V1Config.password}@#{V1Config.api_host}/VersionOne/rest-1.v1/Data/Task?where=#{whereClause}", (res)->
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
    # multi.drop (bar)->
    #   bar.percent(@done*100/@estimate)
    unless @id
      return "Not Found..."
    str = "\n"
    str += "     #{@number} #{@name}(#{@id})\n".yellow
    str += "   -> ".blue + "#{@member}" + "\n"
    str += "   -> ".blue + "#{@status}" + "\n"
    str += "   -> ".blue + "ESTI: " + @estimate + "\n"
    str += "   -> ".blue + "TODO: #{@todo}\n"
    str += "   -> ".blue + "["
    if @done > 0
      str += Array(@done).join("+").green
    if @todo > 0
      str += Array(@todo).join("-").red
    str += "]\n"
    str += "   ->".blue + " DESC: #{@description}"  + "\n"
    str



module.exports =
  Story: Story
  Task: Task
